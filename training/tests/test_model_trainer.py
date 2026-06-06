"""모델 학습기 단위 테스트

EarlyStoppingChecker 로직과 ModelTrainer의 기본 동작을 검증한다.
"""

import pytest

from training.model_trainer import (
    EarlyStoppingChecker,
    ModelTrainer,
    PerformanceCriteria,
)


class TestEarlyStoppingChecker:
    """EarlyStoppingChecker 단위 테스트"""

    def test_should_not_stop_when_losses_shorter_than_patience(self) -> None:
        """손실 시퀀스가 patience 이하일 때 종료하지 않아야 한다"""
        val_losses = [1.0, 0.9, 0.8]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=5) is False

    def test_should_not_stop_when_losses_equal_to_patience(self) -> None:
        """손실 시퀀스 길이가 patience와 같을 때 종료하지 않아야 한다"""
        val_losses = [1.0, 0.9, 0.8, 0.7, 0.6]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=5) is False

    def test_should_stop_when_no_improvement_for_patience_epochs(self) -> None:
        """patience 에포크 연속 개선 없을 때 종료해야 한다"""
        # 초기 개선 후 5 에포크 연속 미개선
        val_losses = [1.0, 0.8, 0.6, 0.7, 0.7, 0.7, 0.7, 0.7]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=5) is True

    def test_should_not_stop_when_improvement_within_patience(self) -> None:
        """patience 이내에 개선이 있으면 계속 학습해야 한다"""
        # 마지막 5 에포크 중 하나가 이전 최소보다 낮음
        val_losses = [1.0, 0.8, 0.6, 0.7, 0.7, 0.7, 0.5, 0.7]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=5) is False

    def test_should_stop_with_increasing_losses(self) -> None:
        """손실이 계속 증가할 때 종료해야 한다"""
        val_losses = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=5) is True

    def test_should_not_stop_with_empty_losses(self) -> None:
        """빈 시퀀스에서는 종료하지 않아야 한다"""
        assert EarlyStoppingChecker.should_stop([], patience=5) is False

    def test_should_not_stop_with_single_loss(self) -> None:
        """단일 손실 값에서는 종료하지 않아야 한다"""
        assert EarlyStoppingChecker.should_stop([0.5], patience=5) is False

    def test_should_stop_with_patience_1(self) -> None:
        """patience=1일 때 1 에포크 미개선 시 종료해야 한다"""
        val_losses = [0.5, 0.6]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=1) is True

    def test_should_not_stop_when_last_epoch_improves_with_patience_1(self) -> None:
        """patience=1일 때 마지막 에포크에 개선이 있으면 계속해야 한다"""
        val_losses = [0.5, 0.4]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=1) is False

    def test_should_stop_when_all_recent_equal_to_best(self) -> None:
        """최근 patience 에포크의 손실이 이전 최소와 같으면 종료해야 한다 (개선 없음)"""
        val_losses = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=5) is True

    def test_should_stop_fluctuating_but_no_improvement(self) -> None:
        """변동이 있지만 최소값 이하로 내려가지 않으면 종료해야 한다"""
        val_losses = [0.3, 0.5, 0.4, 0.6, 0.5, 0.4]
        assert EarlyStoppingChecker.should_stop(val_losses, patience=5) is True


class TestPerformanceCriteria:
    """성능 기준 검증 테스트"""

    def test_check_performance_criteria_all_pass(self) -> None:
        """모든 기준을 충족하는 경우"""
        trainer = ModelTrainer(dataset_path="dummy", seed=42)
        report = {
            "accuracy": 0.85,
            "macro_f1": 0.80,
            "per_class_precision": {
                "Angry": 0.80,
                "Happy": 0.90,
                "Sad": 0.85,
                "Other": 0.75,
            },
            "per_class_recall": {
                "Angry": 0.75,
                "Happy": 0.85,
                "Sad": 0.80,
                "Other": 0.70,
            },
            "per_class_f1": {
                "Angry": 0.77,
                "Happy": 0.87,
                "Sad": 0.82,
                "Other": 0.72,
            },
            "confusion_matrix": [[8, 1, 1, 0], [0, 9, 1, 0], [1, 0, 8, 1], [0, 1, 1, 4]],
            "class_support": {"Angry": 10, "Happy": 10, "Sad": 10, "Other": 6},
            "seed": 42,
            "model_version": "1.0.0",
        }

        result = trainer.check_performance_criteria(report)
        assert result["passed"] is True
        assert len(result["failures"]) == 0

    def test_check_performance_criteria_accuracy_fail(self) -> None:
        """전체 정확도 미달 시"""
        trainer = ModelTrainer(dataset_path="dummy", seed=42)
        report = {
            "accuracy": 0.60,
            "macro_f1": 0.70,
            "per_class_recall": {
                "Angry": 0.70,
                "Happy": 0.80,
                "Sad": 0.70,
                "Other": 0.65,
            },
        }

        result = trainer.check_performance_criteria(report)
        assert result["passed"] is False
        assert result["details"]["accuracy_passed"] is False

    def test_check_performance_criteria_macro_f1_fail(self) -> None:
        """Macro F1 미달 시"""
        trainer = ModelTrainer(dataset_path="dummy", seed=42)
        report = {
            "accuracy": 0.75,
            "macro_f1": 0.50,
            "per_class_recall": {
                "Angry": 0.70,
                "Happy": 0.80,
                "Sad": 0.70,
                "Other": 0.65,
            },
        }

        result = trainer.check_performance_criteria(report)
        assert result["passed"] is False
        assert result["details"]["macro_f1_passed"] is False

    def test_check_performance_criteria_class_accuracy_fail(self) -> None:
        """카테고리별 정확도 미달 시"""
        trainer = ModelTrainer(dataset_path="dummy", seed=42)
        report = {
            "accuracy": 0.75,
            "macro_f1": 0.70,
            "per_class_recall": {
                "Angry": 0.50,  # 미달
                "Happy": 0.80,
                "Sad": 0.70,
                "Other": 0.65,
            },
        }

        result = trainer.check_performance_criteria(report)
        assert result["passed"] is False
        assert result["details"]["per_class_passed"]["Angry"] is False
        assert result["details"]["per_class_passed"]["Happy"] is True

    def test_check_performance_criteria_custom_criteria(self) -> None:
        """커스텀 성능 기준 적용"""
        trainer = ModelTrainer(dataset_path="dummy", seed=42)
        criteria = PerformanceCriteria(
            min_accuracy=0.90,
            min_macro_f1=0.85,
            min_class_accuracy=0.80,
        )
        report = {
            "accuracy": 0.85,
            "macro_f1": 0.80,
            "per_class_recall": {
                "Angry": 0.75,
                "Happy": 0.85,
                "Sad": 0.80,
                "Other": 0.70,
            },
        }

        result = trainer.check_performance_criteria(report, criteria)
        assert result["passed"] is False
