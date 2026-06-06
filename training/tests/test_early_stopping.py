"""Property 13: 조기 종료 조건 감지 속성 테스트

임의의 검증 손실(validation loss) 시퀀스에서 5 에포크 연속으로 손실이
감소하지 않으면 조기 종료 판정이 활성화되어야 한다.
반대로 5 에포크 이내에 손실이 감소하면 학습이 계속되어야 한다.

Feature: animal-emotion-recognition, Property 13: 조기 종료 조건 감지

**Validates: Requirements 6.7**
"""

import pytest
from hypothesis import given, settings, assume
from hypothesis import strategies as st

from training.model_trainer import EarlyStoppingChecker


class TestEarlyStoppingProperty:
    """속성 테스트: 조기 종료 조건 감지 (Property 13)

    Feature: animal-emotion-recognition, Property 13: 조기 종료 조건 감지
    """

    @given(
        # patience 이전 구간: 최소 1개 이상의 손실값
        prefix=st.lists(
            st.floats(min_value=0.01, max_value=10.0, allow_nan=False, allow_infinity=False),
            min_size=1,
            max_size=20,
        ),
        # patience 구간: 5개의 미개선 손실값 (최소값 이상)
        tail_offsets=st.lists(
            st.floats(min_value=0.0, max_value=5.0, allow_nan=False, allow_infinity=False),
            min_size=5,
            max_size=5,
        ),
    )
    @settings(max_examples=200)
    def test_no_improvement_in_tail_triggers_stop(
        self, prefix: list[float], tail_offsets: list[float]
    ):
        """(a) 마지막 patience 에포크 동안 개선이 없으면 → should_stop이 True를 반환해야 한다.

        전략: prefix 구간의 최소값(best)을 구한 뒤, tail을 best + offset (>= 0)으로 구성하여
        tail의 모든 값이 best 이상이 되도록 한다.

        Feature: animal-emotion-recognition, Property 13: 조기 종료 조건 감지
        **Validates: Requirements 6.7**
        """
        patience = 5

        # prefix 구간의 최소값 (이전 최적 손실)
        best_before = min(prefix)

        # tail의 모든 값을 best_before 이상으로 구성 (미개선)
        tail = [best_before + offset for offset in tail_offsets]

        # 전체 시퀀스 = prefix + tail
        val_losses = prefix + tail

        # 시퀀스 길이가 patience보다 긴지 확인 (len(prefix) >= 1이므로 항상 > patience)
        assert len(val_losses) > patience

        # 속성 검증: 미개선 tail → 종료 활성화
        result = EarlyStoppingChecker.should_stop(val_losses, patience=patience)
        assert result is True, (
            f"미개선 tail에서 조기 종료가 활성화되지 않음: "
            f"best_before={best_before}, tail={tail}, val_losses={val_losses}"
        )

    @given(
        # patience 이전 구간
        prefix=st.lists(
            st.floats(min_value=0.1, max_value=10.0, allow_nan=False, allow_infinity=False),
            min_size=1,
            max_size=20,
        ),
        # tail 내 개선이 발생하는 위치 (0~4 인덱스 중 하나)
        improvement_index=st.integers(min_value=0, max_value=4),
        # 개선 폭 (best보다 얼마나 작은지)
        improvement_amount=st.floats(
            min_value=0.001, max_value=1.0, allow_nan=False, allow_infinity=False
        ),
        # tail의 나머지 위치에서의 offset (best 이상)
        other_offsets=st.lists(
            st.floats(min_value=0.0, max_value=5.0, allow_nan=False, allow_infinity=False),
            min_size=4,
            max_size=4,
        ),
    )
    @settings(max_examples=200)
    def test_improvement_in_tail_prevents_stop(
        self,
        prefix: list[float],
        improvement_index: int,
        improvement_amount: float,
        other_offsets: list[float],
    ):
        """(b) 마지막 patience 에포크 내에 개선이 있으면 → should_stop이 False를 반환해야 한다.

        전략: tail 5개 중 하나를 best_before보다 작은 값으로 설정하여
        개선이 발생했음을 보장한다.

        Feature: animal-emotion-recognition, Property 13: 조기 종료 조건 감지
        **Validates: Requirements 6.7**
        """
        patience = 5

        # prefix 구간의 최소값
        best_before = min(prefix)

        # 개선 값: best보다 작은 값 (엄격한 개선)
        improved_value = best_before - improvement_amount

        # tail 구성: 대부분은 best 이상, 한 위치만 개선
        tail: list[float] = []
        offset_idx = 0
        for i in range(patience):
            if i == improvement_index:
                tail.append(improved_value)
            else:
                tail.append(best_before + other_offsets[offset_idx])
                offset_idx += 1

        # 전체 시퀀스 = prefix + tail
        val_losses = prefix + tail

        # 속성 검증: 개선이 있는 tail → 학습 계속
        result = EarlyStoppingChecker.should_stop(val_losses, patience=patience)
        assert result is False, (
            f"개선이 있는 tail에서 조기 종료가 잘못 활성화됨: "
            f"best_before={best_before}, improved_value={improved_value}, "
            f"tail={tail}, val_losses={val_losses}"
        )

    @given(
        # 짧은 시퀀스 (길이 1~5)
        short_sequence=st.lists(
            st.floats(min_value=0.01, max_value=10.0, allow_nan=False, allow_infinity=False),
            min_size=1,
            max_size=5,
        ),
    )
    @settings(max_examples=200)
    def test_short_sequence_never_triggers_stop(
        self, short_sequence: list[float]
    ):
        """(c) 시퀀스 길이가 patience 이하이면 → should_stop이 항상 False를 반환해야 한다.

        데이터가 충분하지 않으면 조기 종료를 판단할 수 없으므로 학습을 계속해야 한다.

        Feature: animal-emotion-recognition, Property 13: 조기 종료 조건 감지
        **Validates: Requirements 6.7**
        """
        patience = 5

        # 시퀀스 길이가 patience 이하인지 확인
        assert len(short_sequence) <= patience

        # 속성 검증: 짧은 시퀀스 → 항상 학습 계속
        result = EarlyStoppingChecker.should_stop(short_sequence, patience=patience)
        assert result is False, (
            f"짧은 시퀀스에서 조기 종료가 잘못 활성화됨: "
            f"sequence={short_sequence}, length={len(short_sequence)}"
        )
