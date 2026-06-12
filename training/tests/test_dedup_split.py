"""dedup_split 모듈 단위 테스트"""

import random

import numpy as np
import pytest
from PIL import Image

from training.dedup_split import (
    cluster_near_duplicates,
    compute_dhash,
    hamming_distance,
    stratified_group_split,
)


@pytest.fixture
def make_image(tmp_path):
    """주어진 시드의 랜덤 노이즈 이미지를 생성하고 경로를 반환한다"""

    def _make(name: str, seed: int, jitter: int = 0) -> str:
        rng = np.random.default_rng(seed)
        pixels = rng.integers(0, 256, size=(64, 64, 3), dtype=np.uint8)
        if jitter:
            # 미세한 밝기 변형 (근접 중복 시뮬레이션)
            pixels = np.clip(pixels.astype(np.int16) + jitter, 0, 255).astype(
                np.uint8
            )
        path = tmp_path / f"{name}.png"
        Image.fromarray(pixels).save(path)
        return str(path)

    return _make


class TestComputeDhash:
    def test_identical_images_have_same_hash(self, make_image):
        path_a = make_image("a", seed=1)
        path_b = make_image("b", seed=1)
        assert compute_dhash(path_a) == compute_dhash(path_b)

    def test_different_images_have_distant_hashes(self, make_image):
        path_a = make_image("a", seed=1)
        path_b = make_image("b", seed=2)
        distance = hamming_distance(compute_dhash(path_a), compute_dhash(path_b))
        assert distance > 6

    def test_slight_brightness_change_keeps_hash_close(self, make_image):
        path_a = make_image("a", seed=1)
        path_b = make_image("b", seed=1, jitter=5)
        distance = hamming_distance(compute_dhash(path_a), compute_dhash(path_b))
        assert distance <= 6


class TestClusterNearDuplicates:
    def test_duplicates_grouped_into_one_cluster(self, make_image):
        paths = [
            make_image("dup1", seed=1),
            make_image("dup2", seed=1, jitter=3),
            make_image("unique", seed=99),
        ]
        clusters = cluster_near_duplicates(paths)

        sizes = sorted(len(c) for c in clusters)
        assert sizes == [1, 2]

    def test_all_unique_images_form_singleton_clusters(self, make_image):
        paths = [make_image(f"img{i}", seed=i * 7 + 1) for i in range(5)]
        clusters = cluster_near_duplicates(paths)
        assert len(clusters) == 5
        assert all(len(c) == 1 for c in clusters)


class TestStratifiedGroupSplit:
    def test_cluster_never_spans_both_splits(self, make_image):
        # 중복 쌍 3개 + 고유 이미지 14장
        paths = []
        for i in range(3):
            paths.append(make_image(f"dup{i}_a", seed=i + 1))
            paths.append(make_image(f"dup{i}_b", seed=i + 1, jitter=4))
        for i in range(14):
            paths.append(make_image(f"uniq{i}", seed=100 + i * 13))

        train, valid = stratified_group_split(
            {"Angry": paths}, validation_ratio=0.3, seed=42
        )

        train_set = set(train["Angry"])
        valid_set = set(valid["Angry"])

        # 분할은 전체를 보존하고 겹치지 않아야 한다
        assert train_set | valid_set == set(paths)
        assert train_set & valid_set == set()

        # 중복 클러스터가 양쪽에 걸치지 않아야 한다
        clusters = cluster_near_duplicates(paths)
        for cluster in clusters:
            in_train = sum(1 for p in cluster if p in train_set)
            in_valid = sum(1 for p in cluster if p in valid_set)
            assert in_train == 0 or in_valid == 0

    def test_validation_ratio_is_approximated(self, make_image):
        paths = [make_image(f"img{i}", seed=200 + i * 11) for i in range(20)]

        train, valid = stratified_group_split(
            {"Happy": paths}, validation_ratio=0.25, seed=7
        )

        # 클러스터 단위 배정이므로 정확히 25%는 아니지만 근사해야 한다
        assert 3 <= len(valid["Happy"]) <= 8
        assert len(train["Happy"]) + len(valid["Happy"]) == 20

    def test_split_is_reproducible_for_same_seed(self, make_image):
        paths = [make_image(f"img{i}", seed=300 + i * 17) for i in range(10)]

        first = stratified_group_split({"Sad": paths}, 0.2, seed=42)
        second = stratified_group_split({"Sad": paths}, 0.2, seed=42)

        assert first == second
