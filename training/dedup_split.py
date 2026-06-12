"""근접 중복(near-duplicate) 인지 데이터 분할 모듈

소규모 수집 데이터셋에는 같은 동물을 연속 촬영한 거의 동일한 사진이 다수
포함된다(이 데이터셋 train 1,000장 중 약 19%). 이미지 단위로 학습/검증을
나누면 중복 쌍이 양쪽에 걸쳐 검증 점수가 부풀려지고, 조기 종료와 최적
가중치 복원이 '암기 점수'를 기준으로 동작하게 된다.

이를 막기 위해 지각 해시(dHash)로 근접 중복을 클러스터링하고,
클러스터 단위로 분할하여 같은 클러스터가 반드시 한쪽에만 속하게 한다.
"""

from __future__ import annotations

import itertools
import random

from PIL import Image

# dHash 그리드 크기 (8 → 64비트 해시)
DHASH_SIZE: int = 8

# 근접 중복 판정 해밍 거리 임계값 (64비트 중 6비트 이하 차이)
DEFAULT_MAX_HAMMING_DISTANCE: int = 6


def compute_dhash(image_path: str, size: int = DHASH_SIZE) -> int:
    """이미지의 차이 해시(dHash)를 계산한다

    그레이스케일 축소 후 인접 픽셀의 밝기 증감 패턴을 비트로 인코딩한다.
    리사이즈·압축·소폭 보정에 강건하여 근접 중복 탐지에 적합하다.

    Args:
        image_path: 이미지 파일 경로
        size: 해시 그리드 크기 (기본 8 → 64비트)

    Returns:
        64비트 정수 해시
    """
    img = Image.open(image_path).convert("L").resize(
        (size + 1, size), Image.BILINEAR
    )
    pixels = img.tobytes()
    bits = 0
    for row in range(size):
        offset = row * (size + 1)
        for col in range(size):
            left = pixels[offset + col]
            right = pixels[offset + col + 1]
            bits = (bits << 1) | (1 if left > right else 0)
    return bits


def hamming_distance(hash_a: int, hash_b: int) -> int:
    """두 해시의 해밍 거리(서로 다른 비트 수)를 반환한다"""
    return bin(hash_a ^ hash_b).count("1")


def cluster_near_duplicates(
    paths: list[str],
    max_distance: int = DEFAULT_MAX_HAMMING_DISTANCE,
) -> list[list[str]]:
    """근접 중복 이미지를 클러스터로 묶는다 (union-find)

    Args:
        paths: 이미지 파일 경로 리스트
        max_distance: 중복 판정 최대 해밍 거리

    Returns:
        클러스터 리스트. 각 클러스터는 경로 리스트이며,
        중복이 없는 이미지는 단독 클러스터가 된다.
    """
    hashes = [compute_dhash(path) for path in paths]

    parent = list(range(len(paths)))

    def find(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(i: int, j: int) -> None:
        root_i, root_j = find(i), find(j)
        if root_i != root_j:
            parent[root_j] = root_i

    for i, j in itertools.combinations(range(len(paths)), 2):
        if hamming_distance(hashes[i], hashes[j]) <= max_distance:
            union(i, j)

    clusters: dict[int, list[str]] = {}
    for idx, path in enumerate(paths):
        clusters.setdefault(find(idx), []).append(path)

    return list(clusters.values())


def stratified_group_split(
    paths_by_category: dict[str, list[str]],
    validation_ratio: float,
    seed: int,
    max_distance: int = DEFAULT_MAX_HAMMING_DISTANCE,
) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """근접 중복 클러스터 단위로 학습/검증을 층화 분할한다

    카테고리별로 클러스터를 섞은 뒤, 검증 비율을 채울 때까지 클러스터를
    통째로 검증에 배정한다. 같은 클러스터가 양쪽에 걸치는 일이 없으므로
    검증 점수가 중복 암기로 부풀려지지 않는다.

    Args:
        paths_by_category: {카테고리: 이미지 경로 리스트}
        validation_ratio: 검증 비율 (이미지 수 기준 근사)
        seed: 셔플 시드
        max_distance: 중복 판정 최대 해밍 거리

    Returns:
        (학습 경로 딕셔너리, 검증 경로 딕셔너리) 튜플
    """
    rng = random.Random(seed)
    train_split: dict[str, list[str]] = {}
    valid_split: dict[str, list[str]] = {}

    for category, paths in paths_by_category.items():
        clusters = cluster_near_duplicates(sorted(paths), max_distance)
        rng.shuffle(clusters)

        target_valid = max(1, int(len(paths) * validation_ratio))
        valid_paths: list[str] = []
        train_paths: list[str] = []

        for cluster in clusters:
            if len(valid_paths) < target_valid:
                valid_paths.extend(cluster)
            else:
                train_paths.extend(cluster)

        train_split[category] = train_paths
        valid_split[category] = valid_paths

    return train_split, valid_split
