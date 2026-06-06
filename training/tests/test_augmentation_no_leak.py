"""Property 10: 검증/테스트 데이터 증강 미적용 속성 테스트

증강 파이프라인 실행 후에도 검증(valid) 데이터와 테스트(test) 데이터가
원본과 동일하게 유지되는지 검증한다.

Feature: animal-emotion-recognition, Property 10: 검증/테스트 데이터 증강 미적용
Validates: Requirements 5.3
"""

from __future__ import annotations

import os
from pathlib import Path

import numpy as np
import pytest
from hypothesis import given, settings
from hypothesis import strategies as st
from PIL import Image

from training.data_augmentor import (
    CATEGORIES,
    CATEGORY_FOLDER_NAMES,
    DataAugmentor,
)


# --- 전략(Strategy) 정의 ---

# 카테고리별 이미지 수 전략: 각 카테고리에 1~10장의 이미지 생성
images_per_category_strategy = st.integers(min_value=1, max_value=10)


def _create_dataset_structure(
    base_path: Path,
    train_counts: dict[str, int],
    valid_counts: dict[str, int],
    test_counts: dict[str, int],
) -> None:
    """테스트용 데이터셋 디렉토리 구조를 생성한다

    Args:
        base_path: 데이터셋 루트 경로
        train_counts: 카테고리별 학습 이미지 수
        valid_counts: 카테고리별 검증 이미지 수
        test_counts: 카테고리별 테스트 이미지 수
    """
    for split_name, counts in [
        ("train", train_counts),
        ("valid", valid_counts),
        ("test", test_counts),
    ]:
        for category in CATEGORIES:
            folder_name = CATEGORY_FOLDER_NAMES[category]
            category_dir = base_path / split_name / folder_name
            category_dir.mkdir(parents=True, exist_ok=True)

            count = counts.get(category, 0)
            for i in range(count):
                # 작은 더미 이미지 생성 (성능을 위해 16x16)
                img = Image.fromarray(
                    np.random.randint(0, 255, (16, 16, 3), dtype=np.uint8)
                )
                img.save(category_dir / f"{i:03d}.jpg")

            # train 분할에만 aug- 접두사 파일 추가 (원본의 절반)
            if split_name == "train":
                aug_count = max(1, count // 2)
                for i in range(aug_count):
                    img = Image.fromarray(
                        np.random.randint(0, 255, (16, 16, 3), dtype=np.uint8)
                    )
                    img.save(category_dir / f"aug-{i:03d}.jpg")


class TestAugmentationNoLeak:
    """Property 10: 증강 파이프라인 실행 후 검증/테스트 데이터 원본 동일 검증

    Feature: animal-emotion-recognition, Property 10: 검증/테스트 데이터 증강 미적용
    Validates: Requirements 5.3
    """

    @given(
        angry_count=images_per_category_strategy,
        happy_count=images_per_category_strategy,
        sad_count=images_per_category_strategy,
        other_count=images_per_category_strategy,
    )
    @settings(max_examples=30, deadline=None)
    def test_validation_data_unchanged_after_augmentation(
        self,
        angry_count: int,
        happy_count: int,
        sad_count: int,
        other_count: int,
        tmp_path_factory: pytest.TempPathFactory,
    ) -> None:
        """**Validates: Requirements 5.3**

        임의의 데이터셋 구성에서 증강 파이프라인 실행 후,
        검증 데이터는 원본 이미지 경로와 동일해야 한다.
        """
        # 임시 데이터셋 구조 생성
        base_path = tmp_path_factory.mktemp("dataset")

        train_counts = {
            "Angry": angry_count,
            "Happy": happy_count,
            "Sad": sad_count,
            "Other": other_count,
        }
        # 검증/테스트는 카테고리별 동일한 수 사용
        valid_counts = {cat: max(1, c // 2) for cat, c in train_counts.items()}
        test_counts = {cat: max(1, c // 2) for cat, c in train_counts.items()}

        _create_dataset_structure(base_path, train_counts, valid_counts, test_counts)

        # DataAugmentor 생성 및 데이터 로딩
        augmentor = DataAugmentor(str(base_path))
        split = augmentor.load_split()

        # 증강 전 검증 데이터 스냅샷
        valid_before = {
            cat: list(paths) for cat, paths in split.valid_images.items()
        }

        # 증강 파이프라인 실행
        augmentor.run_augmentation_pipeline(min_expansion_ratio=4)

        # 증강 후 검증 데이터 조회
        valid_after = augmentor.get_validation_data()

        # 검증: 증강 후에도 검증 데이터가 원본과 동일해야 함
        for category in CATEGORIES:
            assert sorted(valid_after.get(category, [])) == sorted(
                valid_before.get(category, [])
            ), (
                f"검증 데이터가 변경됨 - 카테고리: {category}, "
                f"전: {valid_before.get(category, [])}, "
                f"후: {valid_after.get(category, [])}"
            )

    @given(
        angry_count=images_per_category_strategy,
        happy_count=images_per_category_strategy,
        sad_count=images_per_category_strategy,
        other_count=images_per_category_strategy,
    )
    @settings(max_examples=30, deadline=None)
    def test_test_data_unchanged_after_augmentation(
        self,
        angry_count: int,
        happy_count: int,
        sad_count: int,
        other_count: int,
        tmp_path_factory: pytest.TempPathFactory,
    ) -> None:
        """**Validates: Requirements 5.3**

        임의의 데이터셋 구성에서 증강 파이프라인 실행 후,
        테스트 데이터는 원본 이미지 경로와 동일해야 한다.
        """
        # 임시 데이터셋 구조 생성
        base_path = tmp_path_factory.mktemp("dataset")

        train_counts = {
            "Angry": angry_count,
            "Happy": happy_count,
            "Sad": sad_count,
            "Other": other_count,
        }
        valid_counts = {cat: max(1, c // 2) for cat, c in train_counts.items()}
        test_counts = {cat: max(1, c // 2) for cat, c in train_counts.items()}

        _create_dataset_structure(base_path, train_counts, valid_counts, test_counts)

        # DataAugmentor 생성 및 데이터 로딩
        augmentor = DataAugmentor(str(base_path))
        split = augmentor.load_split()

        # 증강 전 테스트 데이터 스냅샷
        test_before = {
            cat: list(paths) for cat, paths in split.test_images.items()
        }

        # 증강 파이프라인 실행
        augmentor.run_augmentation_pipeline(min_expansion_ratio=4)

        # 증강 후 테스트 데이터 조회
        test_after = augmentor.get_test_data()

        # 검증: 증강 후에도 테스트 데이터가 원본과 동일해야 함
        for category in CATEGORIES:
            assert sorted(test_after.get(category, [])) == sorted(
                test_before.get(category, [])
            ), (
                f"테스트 데이터가 변경됨 - 카테고리: {category}, "
                f"전: {test_before.get(category, [])}, "
                f"후: {test_after.get(category, [])}"
            )

    @given(
        angry_count=images_per_category_strategy,
        happy_count=images_per_category_strategy,
        sad_count=images_per_category_strategy,
        other_count=images_per_category_strategy,
    )
    @settings(max_examples=30, deadline=None)
    def test_valid_test_file_count_preserved_after_augmentation(
        self,
        angry_count: int,
        happy_count: int,
        sad_count: int,
        other_count: int,
        tmp_path_factory: pytest.TempPathFactory,
    ) -> None:
        """**Validates: Requirements 5.3**

        임의의 데이터셋 구성에서 증강 파이프라인 실행 후,
        검증/테스트 데이터의 파일 수가 증강 전과 동일해야 한다.
        """
        # 임시 데이터셋 구조 생성
        base_path = tmp_path_factory.mktemp("dataset")

        train_counts = {
            "Angry": angry_count,
            "Happy": happy_count,
            "Sad": sad_count,
            "Other": other_count,
        }
        valid_counts = {cat: max(1, c // 2) for cat, c in train_counts.items()}
        test_counts = {cat: max(1, c // 2) for cat, c in train_counts.items()}

        _create_dataset_structure(base_path, train_counts, valid_counts, test_counts)

        # DataAugmentor 생성 및 데이터 로딩
        augmentor = DataAugmentor(str(base_path))
        split = augmentor.load_split()

        # 증강 전 카운트 스냅샷
        valid_count_before = split.valid_count
        test_count_before = split.test_count

        # 증강 파이프라인 실행
        augmentor.run_augmentation_pipeline(min_expansion_ratio=4)

        # 증강 후 카운트 확인
        valid_after = augmentor.get_validation_data()
        test_after = augmentor.get_test_data()

        valid_count_after = sum(len(paths) for paths in valid_after.values())
        test_count_after = sum(len(paths) for paths in test_after.values())

        # 검증: 파일 수 동일
        assert valid_count_after == valid_count_before, (
            f"검증 데이터 수 변경됨: {valid_count_before} → {valid_count_after}"
        )
        assert test_count_after == test_count_before, (
            f"테스트 데이터 수 변경됨: {test_count_before} → {test_count_after}"
        )
