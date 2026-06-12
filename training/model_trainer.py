"""모델 학습기 모듈

MobileNetV2 전이 학습 기반의 동물 감정 분류 모델 학습 및 평가를 수행한다.

Requirements: 6.1, 6.2, 6.7, 6.8, 6.9
"""

from __future__ import annotations

import json
import os
import random
from dataclasses import dataclass
from typing import Any, Optional

import numpy as np
import tensorflow as tf
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)
from sklearn.utils.class_weight import compute_class_weight
from tensorflow import keras

from training.data_augmentor import CATEGORIES


# 모델 입력 크기
INPUT_SHAPE: tuple[int, int, int] = (224, 224, 3)

# 카테고리 수
NUM_CLASSES: int = 4

# 기본 성능 기준
DEFAULT_MIN_ACCURACY: float = 0.70
DEFAULT_MIN_MACRO_F1: float = 0.60
DEFAULT_MIN_CLASS_ACCURACY: float = 0.60


@dataclass
class PerformanceCriteria:
    """성능 기준 설정"""

    min_accuracy: float = DEFAULT_MIN_ACCURACY
    min_macro_f1: float = DEFAULT_MIN_MACRO_F1
    min_class_accuracy: float = DEFAULT_MIN_CLASS_ACCURACY


class EarlyStoppingChecker:
    """조기 종료 판정 유틸리티 (Property 13 테스트용 순수 함수)

    검증 손실 시퀀스를 분석하여 학습 조기 종료 여부를 판단한다.
    """

    @staticmethod
    def should_stop(val_losses: list[float], patience: int = 5) -> bool:
        """검증 손실 시퀀스를 기반으로 조기 종료 여부를 판단한다

        마지막 patience 에포크 동안 val_loss가 최소값보다 개선되지 않았으면
        조기 종료해야 한다.

        Args:
            val_losses: 에포크별 검증 손실 값 리스트
            patience: 연속 미개선 허용 에포크 수 (기본값 5)

        Returns:
            True: 조기 종료해야 함, False: 학습 계속
        """
        if len(val_losses) <= patience:
            return False

        # patience 에포크 이전까지의 최소 손실값
        best_before_patience = min(val_losses[: len(val_losses) - patience])

        # 마지막 patience 에포크의 모든 값이 best_before_patience 이상이면 종료
        recent_losses = val_losses[len(val_losses) - patience :]
        return all(loss >= best_before_patience for loss in recent_losses)


class ModelTrainer:
    """MobileNetV2 전이 학습 기반 동물 감정 분류 모델 학습기

    ImageNet 사전학습 가중치를 활용하여 4개 감정 카테고리(Angry, Happy, Sad, Other)
    분류 모델을 학습하고 평가한다.
    """

    def __init__(
        self,
        dataset_path: str,
        seed: int = 42,
        model_version: str = "1.0.0",
    ) -> None:
        """
        Args:
            dataset_path: Master Folder 경로
            seed: 재현성을 위한 랜덤 시드
            model_version: 모델 버전 문자열
        """
        self._dataset_path = dataset_path
        self._seed = seed
        self._model_version = model_version
        self._model: Optional[keras.Model] = None
        self._base_model: Optional[keras.Model] = None
        self._history: Optional[keras.callbacks.History] = None

        # 재현성 설정 (tf, numpy, 표준 random 모두 시드 고정)
        tf.random.set_seed(seed)
        np.random.seed(seed)
        random.seed(seed)

    @property
    def model(self) -> Optional[keras.Model]:
        """학습된 모델 반환"""
        return self._model

    @property
    def seed(self) -> int:
        """랜덤 시드"""
        return self._seed

    @property
    def model_version(self) -> str:
        """모델 버전"""
        return self._model_version

    def build_model(self) -> keras.Model:
        """EfficientNetV2B0 기반 분류 모델을 생성한다 (Req 6.1)

        구조:
        - Input: [0.0, 1.0] 정규화 이미지 (Flutter 전처리 출력과 동일한 스케일)
        - Rescaling: [0,1] → [-1,1] (EfficientNetV2 가중치가 기대하는 입력 범위)
        - Base: EfficientNetV2B0 (ImageNet 사전학습, 내장 전처리 비활성)
        - Head: GAP → Dropout(0.3) → Dense(4, logits)

        백본은 동급 크기에서 MobileNetV2보다 미세한 시각 차이(표정)를 더 잘
        구분하는 EfficientNetV2B0를 사용한다. 헤드는 병목(Dense 64) 없이
        GAP 특징을 곧바로 분류층에 연결한다 — 소규모 데이터에서 과한 병목과
        이중 dropout(0.5)은 학습 부족(underfit)을 유발했다.

        전처리(Rescaling)를 모델 내부에 포함하여, 앱이 [0,1] 입력을 그대로
        전달해도 base가 올바른 [-1,1] 입력을 받도록 보장한다. 이로써 사전학습
        특징이 정상적으로 동작하며 온디바이스 추론과의 전처리 일관성도 유지된다.

        출력층은 softmax가 아니라 **logits**(활성화 없음)를 내보낸다. softmax는
        학습 손실(from_logits=True)과 온디바이스 추론(앱의 분류 서비스)에서 각각
        한 번씩만 적용된다. 모델에 softmax를 두면 앱에서 이중 적용되어 신뢰도가
        비정상적으로 눌리므로, 계약상 모델은 logits만 출력한다.

        Returns:
            컴파일되지 않은 Keras 모델
        """
        # EfficientNetV2B0 기본 모델 (ImageNet 사전학습 가중치, 분류 헤드 제외)
        # include_preprocessing=False: 입력 스케일링은 모델 앞단 Rescaling이 담당
        base_model = keras.applications.EfficientNetV2B0(
            weights="imagenet",
            include_top=False,
            include_preprocessing=False,
            input_shape=INPUT_SHAPE,
        )

        # 기본 모델의 가중치를 동결 (1단계 전이 학습) - 파인튜닝 단계에서 일부 해제
        base_model.trainable = False
        self._base_model = base_model

        # 함수형 API로 전처리(Rescaling)를 모델 내부에 포함
        inputs = keras.Input(shape=INPUT_SHAPE)
        x = keras.layers.Rescaling(scale=2.0, offset=-1.0)(inputs)
        # base는 BatchNorm 통계를 추론 모드로 고정 (소규모 데이터 전이학습 권장 방식)
        x = base_model(x, training=False)
        x = keras.layers.GlobalAveragePooling2D()(x)
        x = keras.layers.Dropout(0.3)(x)
        # 출력은 logits (활성화 없음). softmax는 학습 손실/온디바이스 추론에서 적용한다.
        outputs = keras.layers.Dense(NUM_CLASSES, activation=None)(x)

        model = keras.Model(inputs, outputs, name="animal_emotion_classifier")

        self._model = model
        return model

    def _compute_class_weight(
        self, labels_onehot: np.ndarray
    ) -> dict[int, float]:
        """원핫 레이블로부터 균형 클래스 가중치를 계산한다

        소수/난이도 높은 클래스(예: Other)의 학습 신호를 보강하기 위해
        'balanced' 전략으로 클래스별 가중치를 산출한다.

        Args:
            labels_onehot: 원핫 인코딩 레이블 배열 [N, NUM_CLASSES]

        Returns:
            {클래스 인덱스: 가중치} 딕셔너리 (모든 클래스 포함)
        """
        y = np.argmax(labels_onehot, axis=1)
        present = np.unique(y)
        weights = compute_class_weight(
            class_weight="balanced", classes=present, y=y
        )
        class_weight: dict[int, float] = {idx: 1.0 for idx in range(NUM_CLASSES)}
        for cls, weight in zip(present, weights):
            class_weight[int(cls)] = float(weight)
        return class_weight

    def train(
        self,
        train_data: tuple[np.ndarray, np.ndarray],
        valid_data: tuple[np.ndarray, np.ndarray],
        epochs: int = 30,
        batch_size: int = 32,
        fine_tune_epochs: int = 40,
        fine_tune_at: Optional[int] = None,
        class_weight: Optional[dict[int, float]] = None,
    ) -> keras.callbacks.History:
        """모델을 2단계 전이 학습으로 학습한다 (Req 6.1, 6.7)

        1단계 (헤드 학습): base 동결, Adam(1e-3)으로 분류 헤드만 학습.
        2단계 (파인튜닝): base 상위 레이어 해제, Adam(5e-5)으로 미세 조정.
            (BatchNorm 레이어는 추론 모드로 고정하여 소규모 데이터 과적합 방지)

        두 단계 모두 label smoothing, 클래스 가중치, 조기 종료(val_loss),
        ReduceLROnPlateau를 적용한다.

        Args:
            train_data: (학습 이미지 배열, 원핫 인코딩 레이블) 튜플
            valid_data: (검증 이미지 배열, 원핫 인코딩 레이블) 튜플
            epochs: 1단계(헤드) 최대 에포크 수 (기본값 30)
            batch_size: 배치 크기 (기본값 32)
            fine_tune_epochs: 2단계(파인튜닝) 최대 에포크 수 (기본값 40)
            fine_tune_at: 이 인덱스 이전 base 레이어는 동결 유지
                (None이면 base 하위 1/3 동결)
            class_weight: 클래스 가중치 (None이면 'balanced'로 자동 계산)

        Returns:
            파인튜닝 단계의 학습 히스토리 객체
        """
        if self._model is None:
            self.build_model()
        if self._model is None or self._base_model is None:
            raise RuntimeError("모델 빌드에 실패했습니다.")

        train_images, train_labels = train_data
        valid_images, valid_labels = valid_data

        # 클래스 가중치 자동 계산 (Other 등 난이도 높은 클래스 보강)
        if class_weight is None:
            class_weight = self._compute_class_weight(train_labels)

        # 모델이 logits를 출력하므로 from_logits=True로 손실 내부에서 softmax를 적용한다.
        loss_fn = keras.losses.CategoricalCrossentropy(
            from_logits=True, label_smoothing=0.1
        )

        def _callbacks(
            min_lr: float, patience: int
        ) -> list[keras.callbacks.Callback]:
            return [
                keras.callbacks.EarlyStopping(
                    monitor="val_loss",
                    patience=patience,
                    restore_best_weights=True,
                ),
                keras.callbacks.ReduceLROnPlateau(
                    monitor="val_loss", factor=0.5, patience=3, min_lr=min_lr
                ),
            ]

        # On-the-fly 증강 파이프라인: 매 에포크마다 서로 다른 변형을 생성하여
        # 소규모 고유 이미지에 대한 과적합을 완화한다. 추론 시에는 비활성(항등)이며
        # 모델 외부(tf.data)에서만 적용하므로 내보내는 모델 그래프는 깨끗하게 유지된다.
        augmentation = keras.Sequential(
            [
                keras.layers.RandomFlip("horizontal", seed=self._seed),
                keras.layers.RandomRotation(
                    0.12, fill_mode="constant", seed=self._seed
                ),
                keras.layers.RandomZoom(
                    0.15, fill_mode="constant", seed=self._seed
                ),
                keras.layers.RandomTranslation(
                    0.1, 0.1, fill_mode="constant", seed=self._seed
                ),
                keras.layers.RandomContrast(0.15, seed=self._seed),
                keras.layers.RandomBrightness(
                    0.15, value_range=(0.0, 1.0), seed=self._seed
                ),
            ],
            name="train_augmentation",
        )

        autotune = tf.data.AUTOTUNE
        train_ds = (
            tf.data.Dataset.from_tensor_slices((train_images, train_labels))
            .shuffle(
                buffer_size=len(train_images),
                seed=self._seed,
                reshuffle_each_iteration=True,
            )
            .batch(batch_size)
            .map(
                lambda x, y: (augmentation(x, training=True), y),
                num_parallel_calls=autotune,
            )
            .prefetch(autotune)
        )
        valid_ds = (
            tf.data.Dataset.from_tensor_slices((valid_images, valid_labels))
            .batch(batch_size)
            .prefetch(autotune)
        )

        # ---- 1단계: 분류 헤드 학습 (base 동결) ----
        self._base_model.trainable = False
        self._model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=1e-3),
            loss=loss_fn,
            metrics=["accuracy"],
        )
        print("[정보] 1단계 학습 시작 (헤드 학습, base 동결, on-the-fly 증강)")
        self._model.fit(
            train_ds,
            epochs=epochs,
            validation_data=valid_ds,
            callbacks=_callbacks(min_lr=1e-6, patience=6),
            class_weight=class_weight,
            verbose=1,
        )

        # ---- 2단계: 파인튜닝 (base 상위 레이어 해제) ----
        # fine_tune_at 미지정 시 base 하위 1/3은 동결 유지 (저수준 특징 보존)
        if fine_tune_at is None:
            fine_tune_at = len(self._base_model.layers) // 3

        self._base_model.trainable = True
        for layer in self._base_model.layers[:fine_tune_at]:
            layer.trainable = False
        # BatchNorm은 추론 모드 유지를 위해 동결 (소규모 데이터 전이학습 권장)
        for layer in self._base_model.layers:
            if isinstance(layer, keras.layers.BatchNormalization):
                layer.trainable = False

        self._model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=5e-5),
            loss=loss_fn,
            metrics=["accuracy"],
        )
        print(
            f"[정보] 2단계 파인튜닝 시작 "
            f"(base 레이어 {fine_tune_at}번 이후 학습, BatchNorm 동결)"
        )
        self._history = self._model.fit(
            train_ds,
            epochs=fine_tune_epochs,
            validation_data=valid_ds,
            callbacks=_callbacks(min_lr=1e-7, patience=8),
            class_weight=class_weight,
            verbose=1,
        )

        return self._history

    def evaluate(
        self, test_data: tuple[np.ndarray, np.ndarray]
    ) -> dict[str, float]:
        """테스트 데이터에 대해 모델을 평가한다

        Args:
            test_data: (테스트 이미지 배열, 원핫 인코딩 레이블) 튜플

        Returns:
            {"loss": float, "accuracy": float} 딕셔너리
        """
        if self._model is None:
            raise RuntimeError("모델이 빌드되지 않았습니다. build_model()을 먼저 호출하세요.")

        test_images, test_labels = test_data
        results = self._model.evaluate(test_images, test_labels, verbose=0)

        return {
            "loss": float(results[0]),
            "accuracy": float(results[1]),
        }

    def generate_report(
        self, test_data: tuple[np.ndarray, np.ndarray]
    ) -> dict[str, Any]:
        """평가 보고서를 생성한다 (Req 6.8)

        보고서 포함 항목:
        - accuracy: 전체 정확도
        - macro_f1: macro F1 스코어
        - per_class_precision: 클래스별 정밀도
        - per_class_recall: 클래스별 재현율
        - per_class_f1: 클래스별 F1 스코어
        - confusion_matrix: 혼동 행렬
        - class_support: 클래스별 표본 수
        - seed: 학습 시드
        - model_version: 모델 버전

        Args:
            test_data: (테스트 이미지 배열, 원핫 인코딩 레이블) 튜플

        Returns:
            평가 보고서 딕셔너리
        """
        if self._model is None:
            raise RuntimeError("모델이 빌드되지 않았습니다. build_model()을 먼저 호출하세요.")

        test_images, test_labels = test_data

        # 예측 수행
        predictions = self._model.predict(test_images, verbose=0)
        y_pred = np.argmax(predictions, axis=1)
        y_true = np.argmax(test_labels, axis=1)

        # 전체 정확도
        accuracy = float(accuracy_score(y_true, y_pred))

        # Macro F1
        macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0))

        # 클래스별 상세 보고서
        report = classification_report(
            y_true,
            y_pred,
            target_names=CATEGORIES,
            output_dict=True,
            zero_division=0,
        )

        # 클래스별 metrics 추출
        per_class_precision: dict[str, float] = {}
        per_class_recall: dict[str, float] = {}
        per_class_f1: dict[str, float] = {}
        class_support: dict[str, int] = {}

        for category in CATEGORIES:
            if category in report:
                per_class_precision[category] = float(report[category]["precision"])
                per_class_recall[category] = float(report[category]["recall"])
                per_class_f1[category] = float(report[category]["f1-score"])
                class_support[category] = int(report[category]["support"])
            else:
                per_class_precision[category] = 0.0
                per_class_recall[category] = 0.0
                per_class_f1[category] = 0.0
                class_support[category] = 0

        # 혼동 행렬
        cm = confusion_matrix(y_true, y_pred, labels=list(range(NUM_CLASSES)))

        return {
            "accuracy": accuracy,
            "macro_f1": macro_f1,
            "per_class_precision": per_class_precision,
            "per_class_recall": per_class_recall,
            "per_class_f1": per_class_f1,
            "confusion_matrix": cm.tolist(),
            "class_support": class_support,
            "seed": self._seed,
            "model_version": self._model_version,
        }

    def check_performance_criteria(
        self,
        report: dict[str, Any],
        criteria: Optional[PerformanceCriteria] = None,
    ) -> dict[str, Any]:
        """성능 기준 충족 여부를 검증한다 (Req 6.2, 6.9)

        기준:
        - 전체 정확도 >= 70%
        - Macro F1 >= 0.60
        - 카테고리별 정확도 >= 60%

        Args:
            report: generate_report()로 생성된 평가 보고서
            criteria: 성능 기준 (None이면 기본값 사용)

        Returns:
            {
                "passed": bool,
                "details": {
                    "accuracy_passed": bool,
                    "macro_f1_passed": bool,
                    "per_class_passed": dict[str, bool],
                },
                "failures": list[str],
            }
        """
        if criteria is None:
            criteria = PerformanceCriteria()

        failures: list[str] = []

        # 전체 정확도 검증
        accuracy_passed = report["accuracy"] >= criteria.min_accuracy
        if not accuracy_passed:
            failures.append(
                f"전체 정확도 미달: {report['accuracy']:.4f} < {criteria.min_accuracy}"
            )

        # Macro F1 검증
        macro_f1_passed = report["macro_f1"] >= criteria.min_macro_f1
        if not macro_f1_passed:
            failures.append(
                f"Macro F1 미달: {report['macro_f1']:.4f} < {criteria.min_macro_f1}"
            )

        # 카테고리별 정확도 검증 (recall을 카테고리별 정확도로 사용)
        per_class_passed: dict[str, bool] = {}
        for category in CATEGORIES:
            class_recall = report["per_class_recall"].get(category, 0.0)
            passed = class_recall >= criteria.min_class_accuracy
            per_class_passed[category] = passed
            if not passed:
                failures.append(
                    f"카테고리별 정확도 미달 [{category}]: "
                    f"{class_recall:.4f} < {criteria.min_class_accuracy}"
                )

        overall_passed = accuracy_passed and macro_f1_passed and all(
            per_class_passed.values()
        )

        return {
            "passed": overall_passed,
            "details": {
                "accuracy_passed": accuracy_passed,
                "macro_f1_passed": macro_f1_passed,
                "per_class_passed": per_class_passed,
            },
            "failures": failures,
        }

    def save_model(self, output_path: str) -> str:
        """학습된 모델을 저장한다

        Args:
            output_path: 모델 저장 경로 (.keras 확장자)

        Returns:
            저장된 모델 파일 경로
        """
        if self._model is None:
            raise RuntimeError("모델이 빌드되지 않았습니다.")

        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        self._model.save(output_path)
        print(f"[정보] 모델 저장 완료: {output_path}")
        return output_path

    def save_report(self, report: dict[str, Any], output_path: str) -> str:
        """평가 보고서를 JSON 파일로 저장한다

        Args:
            report: 평가 보고서 딕셔너리
            output_path: JSON 파일 저장 경로

        Returns:
            저장된 보고서 파일 경로
        """
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)

        print(f"[정보] 평가 보고서 저장 완료: {output_path}")
        return output_path

    def prepare_data(
        self,
        images_dict: dict[str, list[np.ndarray]],
        target_size: tuple[int, int] = (224, 224),
    ) -> tuple[np.ndarray, np.ndarray]:
        """이미지 딕셔너리를 모델 학습용 numpy 배열로 변환한다

        Args:
            images_dict: {카테고리: [이미지 numpy 배열]} 딕셔너리
            target_size: 리사이즈 목표 크기 (기본값 224x224)

        Returns:
            (이미지 배열 [N, 224, 224, 3], 원핫 레이블 배열 [N, 4]) 튜플
        """
        all_images: list[np.ndarray] = []
        all_labels: list[int] = []

        for category_idx, category in enumerate(CATEGORIES):
            category_images = images_dict.get(category, [])
            for img in category_images:
                # 리사이즈 (PIL Image 사용)
                from PIL import Image as PILImage

                if img.shape[:2] != target_size:
                    pil_img = PILImage.fromarray(img.astype(np.uint8))
                    pil_img = pil_img.resize(target_size, PILImage.BILINEAR)
                    img = np.array(pil_img)

                # 0.0~1.0 정규화
                normalized = img.astype(np.float32) / 255.0
                all_images.append(normalized)
                all_labels.append(category_idx)

        # numpy 배열 변환
        images_array = np.array(all_images)
        # 원핫 인코딩
        labels_array = keras.utils.to_categorical(all_labels, num_classes=NUM_CLASSES)

        return images_array, labels_array

    def prepare_data_from_paths(
        self,
        paths_dict: dict[str, list[str]],
        target_size: tuple[int, int] = (224, 224),
    ) -> tuple[np.ndarray, np.ndarray]:
        """파일 경로 딕셔너리로부터 모델 학습용 numpy 배열을 생성한다

        Args:
            paths_dict: {카테고리: [이미지 파일 경로]} 딕셔너리
            target_size: 리사이즈 목표 크기 (기본값 224x224)

        Returns:
            (이미지 배열 [N, 224, 224, 3], 원핫 레이블 배열 [N, 4]) 튜플
        """
        from PIL import Image as PILImage

        all_images: list[np.ndarray] = []
        all_labels: list[int] = []

        for category_idx, category in enumerate(CATEGORIES):
            file_paths = paths_dict.get(category, [])
            for path in file_paths:
                try:
                    img = PILImage.open(path).convert("RGB")
                    img = img.resize(target_size, PILImage.BILINEAR)
                    img_array = np.array(img).astype(np.float32) / 255.0
                    all_images.append(img_array)
                    all_labels.append(category_idx)
                except (OSError, IOError) as e:
                    print(f"[경고] 이미지 로딩 실패: {path} - {e}")
                    continue

        images_array = np.array(all_images)
        labels_array = keras.utils.to_categorical(all_labels, num_classes=NUM_CLASSES)

        return images_array, labels_array
