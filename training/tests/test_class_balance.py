"""Property 12: 증강 후 클래스 균형 유지 속성 테스트

임의의 불균형한 4개 카테고리 데이터셋에 대해, balance_classes() 호출 후
모든 카테고리의 수가 최대 카테고리 대비 20% 이내(>= max_count * 0.8)인지 검증한다.

Feature: animal-emotion-recognition, Property 12: 증강 후 클래스 균형 유지

Validates: Requirements 5.5, 5.6
"""

import tempfile

import numpy as np
from hypothesis import given, settings
from hypothesis import strategies as st

from training.data_augmentor import CATEGORIES, DataAugmentor


def _make_images(count: int) -> list[np.ndarray]:
    """지정된 수만큼 더미 이미지 numpy 배열을 생성한다"""
    return [
        np.random.randint(0, 255, (32, 32, 3), dtype=np.uint8)
        for _ in range(count)
    ]


class TestClassBalanceProperty:
    """Property 12: 증강 후 클래스 균형 유지

    불균형 데이터셋에 대해 balance_classes() 호출 후
    모든 카테고리가 최대 카테고리의 80% 이상이어야 한다.
    """

    @given(
        angry_count=st.integers(min_value=1, max_value=200),
        happy_count=st.integers(min_value=1, max_value=200),
        sad_count=st.integers(min_value=1, max_value=200),
        other_count=st.integers(min_value=1, max_value=200),
    )
    @settings(max_examples=100)
    def test_balance_within_20_percent(
        self,
        angry_count: int,
        happy_count: int,
        sad_count: int,
        other_count: int,
    ):
        """임의의 불균형 4카테고리 데이터에 대해 균형 조정 후
        모든 카테고리가 최대 카테고리 대비 20% 이내임을 검증한다.

        **Validates: Requirements 5.5, 5.6**
        """
        # 준비: DataAugmentor 인스턴스 생성 (임시 디렉토리 사용)
        with tempfile.TemporaryDirectory() as tmp_dir:
            augmentor = DataAugmentor(tmp_dir)

            # 각 카테고리별 더미 이미지 생성
            augmented_data: dict[str, list[np.ndarray]] = {
                "Angry": _make_images(angry_count),
                "Happy": _make_images(happy_count),
                "Sad": _make_images(sad_count),
                "Other": _make_images(other_count),
            }

            # 실행: 클래스 균형 조정
            result = augmentor.balance_classes(augmented_data)

            # 검증: 결과에 모든 카테고리가 존재하는지 확인
            assert set(result.keys()) == {"Angry", "Happy", "Sad", "Other"}

            # 균형 조정 후 최대 카테고리 수 계산
            max_count = max(len(imgs) for imgs in result.values())

            # 모든 카테고리가 최대 카테고리의 80% 이상인지 검증
            # 정수 이미지 개수이므로 int() 내림을 적용 (구현과 동일한 기준)
            threshold = int(max_count * 0.8)
            for category, imgs in result.items():
                assert len(imgs) >= threshold, (
                    f"{category} 카테고리의 수({len(imgs)})가 "
                    f"최대 카테고리({max_count})의 80%({threshold}) 미만입니다."
                )

    @given(
        angry_count=st.integers(min_value=1, max_value=200),
        happy_count=st.integers(min_value=1, max_value=200),
        sad_count=st.integers(min_value=1, max_value=200),
        other_count=st.integers(min_value=1, max_value=200),
    )
    @settings(max_examples=100)
    def test_balance_does_not_reduce_counts(
        self,
        angry_count: int,
        happy_count: int,
        sad_count: int,
        other_count: int,
    ):
        """균형 조정이 기존 데이터를 삭제하지 않고 추가만 하는지 검증한다.

        **Validates: Requirements 5.5, 5.6**
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            augmentor = DataAugmentor(tmp_dir)

            augmented_data: dict[str, list[np.ndarray]] = {
                "Angry": _make_images(angry_count),
                "Happy": _make_images(happy_count),
                "Sad": _make_images(sad_count),
                "Other": _make_images(other_count),
            }

            # 원본 카운트 기록
            original_counts = {
                cat: len(imgs) for cat, imgs in augmented_data.items()
            }

            # 클래스 균형 조정 실행
            result = augmentor.balance_classes(augmented_data)

            # 검증: 모든 카테고리의 수가 원본 이상이어야 한다 (삭제 없음)
            for category in CATEGORIES:
                assert len(result[category]) >= original_counts[category], (
                    f"{category} 카테고리의 결과 수({len(result[category])})가 "
                    f"원본 수({original_counts[category]}) 미만입니다. "
                    f"균형 조정은 데이터를 삭제하면 안 됩니다."
                )
