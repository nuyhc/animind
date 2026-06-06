"""Property 9: 데이터 증강 확장 비율 속성 테스트

임의의 학습 이미지 구성(원본 수, 기존 aug- 수)에 대해
데이터 증강 적용 후 최종 학습 세트(원본 + 기존 aug- + 신규 증강)의 수는
원본 데이터 수의 최소 4배 이상이어야 한다.

Feature: animal-emotion-recognition, Property 9: 데이터 증강 확장 비율

**Validates: Requirements 5.2**
"""

import numpy as np
import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from training.data_augmentor import (
    DEFAULT_MIN_EXPANSION_RATIO,
    DataAugmentor,
)


class TestAugmentationExpansionRatioProperty:
    """속성 테스트: 데이터 증강 확장 비율 (Property 9)

    Feature: animal-emotion-recognition, Property 9: 데이터 증강 확장 비율
    """

    @given(
        original_count=st.integers(min_value=1, max_value=100),
        existing_aug_count=st.integers(min_value=0, max_value=500),
    )
    @settings(max_examples=200)
    def test_expansion_ratio_calculation_satisfies_minimum(
        self, original_count: int, existing_aug_count: int
    ):
        """임의의 원본/기존 aug- 조합에서 계산된 신규 증강 수를 적용하면
        최종 학습 세트 >= 원본 × 4를 만족해야 한다.

        Feature: animal-emotion-recognition, Property 9: 데이터 증강 확장 비율
        **Validates: Requirements 5.2**
        """
        # 임시 경로 (실제 파일 로딩은 하지 않는 계산 테스트)
        augmentor = DataAugmentor("/tmp/dummy")

        # 신규 증강 수 계산
        new_count = augmentor.required_new_augmentation_count(
            original_count=original_count,
            existing_aug_count=existing_aug_count,
            min_expansion_ratio=DEFAULT_MIN_EXPANSION_RATIO,
        )

        # 최종 학습 세트 수 = 원본 + 기존 aug- + 신규 증강
        final_train_count = original_count + existing_aug_count + new_count

        # 속성 검증: 최종 학습 세트 >= 원본 × 4
        assert final_train_count >= original_count * DEFAULT_MIN_EXPANSION_RATIO, (
            f"확장 비율 미달: final={final_train_count}, "
            f"required={original_count * DEFAULT_MIN_EXPANSION_RATIO}, "
            f"original={original_count}, aug={existing_aug_count}, new={new_count}"
        )

    @given(
        original_count=st.integers(min_value=1, max_value=100),
        existing_aug_count=st.integers(min_value=0, max_value=500),
        min_expansion_ratio=st.integers(min_value=2, max_value=10),
    )
    @settings(max_examples=200)
    def test_expansion_ratio_with_variable_ratio(
        self, original_count: int, existing_aug_count: int, min_expansion_ratio: int
    ):
        """임의의 확장 배율에서도 최종 학습 세트 >= 원본 × 배율을 만족해야 한다.

        Feature: animal-emotion-recognition, Property 9: 데이터 증강 확장 비율
        **Validates: Requirements 5.2**
        """
        augmentor = DataAugmentor("/tmp/dummy")

        # 신규 증강 수 계산 (가변 배율)
        new_count = augmentor.required_new_augmentation_count(
            original_count=original_count,
            existing_aug_count=existing_aug_count,
            min_expansion_ratio=min_expansion_ratio,
        )

        # 최종 학습 세트 수
        final_train_count = original_count + existing_aug_count + new_count

        # 속성 검증
        assert final_train_count >= original_count * min_expansion_ratio, (
            f"확장 비율 미달: final={final_train_count}, "
            f"required={original_count * min_expansion_ratio}, "
            f"ratio={min_expansion_ratio}"
        )

    @given(
        original_count=st.integers(min_value=1, max_value=20),
    )
    @settings(max_examples=100)
    def test_actual_augmentation_produces_enough_images(
        self, original_count: int
    ):
        """실제 이미지 증강을 수행해도 최종 학습 세트 >= 원본 × 4를 만족해야 한다.

        랜덤 이미지를 생성하고 augment()를 호출하여
        실제 증강된 이미지 수가 요구사항을 충족하는지 검증한다.

        Feature: animal-emotion-recognition, Property 9: 데이터 증강 확장 비율
        **Validates: Requirements 5.2**
        """
        augmentor = DataAugmentor("/tmp/dummy")

        # 기존 aug- 이미지 수는 0으로 설정 (최악 시나리오)
        existing_aug_count = 0

        # 필요한 신규 증강 수 계산
        needed = augmentor.required_new_augmentation_count(
            original_count=original_count,
            existing_aug_count=existing_aug_count,
            min_expansion_ratio=DEFAULT_MIN_EXPANSION_RATIO,
        )

        # 랜덤 원본 이미지 생성
        images = [
            np.random.randint(0, 255, (32, 32, 3), dtype=np.uint8)
            for _ in range(original_count)
        ]

        # 실제 증강 수행
        augmented = augmentor.augment(images, "Angry", needed)

        # 최종 학습 세트 = 원본 + 신규 증강
        final_train_count = original_count + existing_aug_count + len(augmented)

        # 속성 검증: 최종 학습 세트 >= 원본 × 4
        assert final_train_count >= original_count * DEFAULT_MIN_EXPANSION_RATIO, (
            f"실제 증강 후 확장 비율 미달: final={final_train_count}, "
            f"required={original_count * DEFAULT_MIN_EXPANSION_RATIO}"
        )

    @given(
        original_count=st.integers(min_value=1, max_value=30),
        existing_aug_count=st.integers(min_value=0, max_value=200),
    )
    @settings(max_examples=100)
    def test_new_augmentation_count_is_non_negative(
        self, original_count: int, existing_aug_count: int
    ):
        """신규 증강 수는 항상 0 이상이어야 한다.

        Feature: animal-emotion-recognition, Property 9: 데이터 증강 확장 비율
        **Validates: Requirements 5.2**
        """
        augmentor = DataAugmentor("/tmp/dummy")

        new_count = augmentor.required_new_augmentation_count(
            original_count=original_count,
            existing_aug_count=existing_aug_count,
            min_expansion_ratio=DEFAULT_MIN_EXPANSION_RATIO,
        )

        # 신규 증강 수는 절대 음수가 될 수 없음
        assert new_count >= 0, f"신규 증강 수가 음수: {new_count}"
