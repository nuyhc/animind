"""모델 변환기 모듈

Keras 모델을 TensorFlow Lite 형식으로 변환하고,
변환 전후 정확도 차이 및 파일 크기를 검증한다.

Requirements: 6.3, 6.4, 6.5, 6.6
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path
from typing import Optional

import numpy as np
import tensorflow as tf
from tensorflow import keras


# 기본 설정값
DEFAULT_OUTPUT_DIR: str = "assets/models"
DEFAULT_TFLITE_FILENAME: str = "emotion_model.tflite"
MAX_ACCURACY_DIFF: float = 0.05  # 변환 전후 최대 정확도 차이 (5%)
MAX_FILE_SIZE_MB: int = 50  # 최대 모델 파일 크기 (MB)

# 양자화 수준 정의
QUANTIZATION_LEVELS: list[str] = ["none", "dynamic", "float16"]


class ModelConversionError(Exception):
    """모델 변환 실패 시 발생하는 예외"""

    pass


class ModelConverter:
    """Keras 모델을 TFLite 형식으로 변환하는 서비스

    변환 과정에서 정확도 차이와 파일 크기를 검증하며,
    기준 미달 시 양자화 수준을 조정하여 재시도한다.
    """

    def __init__(self, model_path: str, output_dir: str = DEFAULT_OUTPUT_DIR) -> None:
        """
        Args:
            model_path: Keras 모델 파일 경로 (.keras 또는 .h5)
            output_dir: TFLite 출력 디렉토리 (기본값: assets/models)
        """
        self._model_path = model_path
        self._output_dir = output_dir

    @property
    def model_path(self) -> str:
        """Keras 모델 파일 경로"""
        return self._model_path

    @property
    def output_dir(self) -> str:
        """TFLite 출력 디렉토리"""
        return self._output_dir

    def convert(self, quantization: str = "none") -> str:
        """Keras 모델을 TFLite 형식으로 변환한다 (Req 6.3)

        Args:
            quantization: 양자화 옵션 ("none", "dynamic", "float16")

        Returns:
            변환된 .tflite 파일 경로

        Raises:
            ModelConversionError: 변환 실패 시
            ValueError: 지원하지 않는 양자화 옵션
        """
        if quantization not in QUANTIZATION_LEVELS:
            raise ValueError(
                f"지원하지 않는 양자화 옵션: {quantization}. "
                f"사용 가능: {QUANTIZATION_LEVELS}"
            )

        # Keras 모델 로딩
        try:
            model = keras.models.load_model(self._model_path)
        except Exception as e:
            raise ModelConversionError(f"모델 로딩 실패: {self._model_path} - {e}")

        # TFLite 변환기 설정
        converter = tf.lite.TFLiteConverter.from_keras_model(model)

        # 양자화 옵션 적용
        if quantization == "dynamic":
            # 동적 범위 양자화: 가중치를 int8로 양자화
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
        elif quantization == "float16":
            # Float16 양자화: 가중치를 float16으로 양자화
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            converter.target_spec.supported_types = [tf.float16]

        # 변환 실행
        try:
            tflite_model = converter.convert()
        except Exception as e:
            raise ModelConversionError(f"TFLite 변환 실패 (양자화: {quantization}): {e}")

        # 출력 디렉토리 생성
        os.makedirs(self._output_dir, exist_ok=True)

        # 파일 저장
        output_path = os.path.join(self._output_dir, DEFAULT_TFLITE_FILENAME)
        with open(output_path, "wb") as f:
            f.write(tflite_model)

        print(f"[정보] TFLite 변환 완료 (양자화: {quantization}): {output_path}")
        return output_path

    def validate_accuracy(
        self,
        keras_model: keras.Model,
        tflite_path: str,
        test_data: tuple[np.ndarray, np.ndarray],
        max_diff: float = MAX_ACCURACY_DIFF,
    ) -> bool:
        """변환 전후 정확도 차이를 검증한다 (Req 6.4)

        Keras 모델과 TFLite 모델에 동일한 테스트 데이터로 추론을 수행하고
        정확도 차이가 허용 범위 이내인지 확인한다.

        Args:
            keras_model: 원본 Keras 모델
            tflite_path: 변환된 TFLite 파일 경로
            test_data: (테스트 이미지 배열, 원핫 레이블 배열) 튜플
            max_diff: 최대 허용 정확도 차이 (기본값 0.05 = 5%)

        Returns:
            True: 정확도 차이가 허용 범위 이내, False: 초과
        """
        test_images, test_labels = test_data
        y_true = np.argmax(test_labels, axis=1)

        # Keras 모델 정확도 계산
        keras_predictions = keras_model.predict(test_images, verbose=0)
        keras_y_pred = np.argmax(keras_predictions, axis=1)
        keras_accuracy = float(np.mean(keras_y_pred == y_true))

        # TFLite 모델 정확도 계산
        tflite_accuracy = self._evaluate_tflite(tflite_path, test_images, y_true)

        # 정확도 차이 계산
        accuracy_diff = abs(keras_accuracy - tflite_accuracy)

        print(
            f"[정보] 정확도 비교 - Keras: {keras_accuracy:.4f}, "
            f"TFLite: {tflite_accuracy:.4f}, 차이: {accuracy_diff:.4f}"
        )

        return accuracy_diff <= max_diff

    def validate_file_size(
        self, tflite_path: str, max_size_mb: int = MAX_FILE_SIZE_MB
    ) -> bool:
        """변환된 모델 파일 크기를 검증한다 (Req 6.6)

        Args:
            tflite_path: TFLite 파일 경로
            max_size_mb: 최대 허용 파일 크기 (MB, 기본값 50)

        Returns:
            True: 파일 크기가 허용 범위 이내, False: 초과
        """
        if not os.path.exists(tflite_path):
            return False

        file_size_bytes = os.path.getsize(tflite_path)
        file_size_mb = file_size_bytes / (1024 * 1024)

        print(f"[정보] 모델 파일 크기: {file_size_mb:.2f}MB (제한: {max_size_mb}MB)")

        return file_size_mb <= max_size_mb

    def convert_with_fallback(
        self, test_data: tuple[np.ndarray, np.ndarray]
    ) -> str:
        """양자화 수준을 단계적으로 조정하며 변환을 시도한다 (Req 6.5)

        변환 순서:
        1. "none" (양자화 없음)
        2. "dynamic" (동적 범위 양자화)
        3. "float16" (Float16 양자화)

        각 단계에서 정확도 차이 ≤5%와 파일 크기 ≤50MB를 모두 만족하면
        해당 변환 결과를 반환한다.

        Args:
            test_data: (테스트 이미지 배열, 원핫 레이블 배열) 튜플

        Returns:
            성공한 TFLite 파일 경로

        Raises:
            ModelConversionError: 모든 양자화 수준에서 실패 시
        """
        # 원본 Keras 모델 로딩
        try:
            keras_model = keras.models.load_model(self._model_path)
        except Exception as e:
            raise ModelConversionError(f"모델 로딩 실패: {self._model_path} - {e}")

        # 양자화 수준별 순차 시도
        for quantization in QUANTIZATION_LEVELS:
            print(f"\n[정보] 양자화 수준 '{quantization}'으로 변환 시도 중...")

            try:
                tflite_path = self.convert(quantization=quantization)
            except ModelConversionError as e:
                print(f"[경고] 변환 실패 ({quantization}): {e}")
                continue

            # 파일 크기 검증
            size_valid = self.validate_file_size(tflite_path)
            if not size_valid:
                print(f"[경고] 파일 크기 초과 ({quantization})")
                continue

            # 정확도 검증
            accuracy_valid = self.validate_accuracy(
                keras_model, tflite_path, test_data
            )
            if not accuracy_valid:
                print(f"[경고] 정확도 차이 초과 ({quantization})")
                continue

            # 모든 검증 통과
            print(f"[성공] 양자화 수준 '{quantization}'으로 변환 성공: {tflite_path}")
            return tflite_path

        # 모든 시도 실패
        raise ModelConversionError(
            "모든 양자화 수준에서 변환 기준을 만족하지 못했습니다. "
            f"시도한 양자화 수준: {QUANTIZATION_LEVELS}"
        )

    def copy_to_flutter_assets(self, tflite_path: str) -> str:
        """변환된 TFLite 파일을 Flutter assets 경로로 복사한다

        Args:
            tflite_path: 원본 TFLite 파일 경로

        Returns:
            복사된 대상 파일 경로

        Raises:
            FileNotFoundError: 원본 파일이 존재하지 않을 때
        """
        if not os.path.exists(tflite_path):
            raise FileNotFoundError(f"TFLite 파일을 찾을 수 없습니다: {tflite_path}")

        # Flutter assets/models/ 디렉토리 경로 결정
        # 프로젝트 루트 기준으로 assets/models/ 사용
        dest_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "assets",
            "models",
        )
        os.makedirs(dest_dir, exist_ok=True)

        dest_path = os.path.join(dest_dir, DEFAULT_TFLITE_FILENAME)
        shutil.copy2(tflite_path, dest_path)

        print(f"[정보] Flutter assets로 복사 완료: {dest_path}")
        return dest_path

    def _evaluate_tflite(
        self,
        tflite_path: str,
        test_images: np.ndarray,
        y_true: np.ndarray,
    ) -> float:
        """TFLite 모델의 정확도를 계산한다

        Args:
            tflite_path: TFLite 파일 경로
            test_images: 테스트 이미지 배열 [N, 224, 224, 3]
            y_true: 정답 레이블 배열 [N]

        Returns:
            정확도 (0.0 ~ 1.0)
        """
        # TFLite 인터프리터 초기화
        interpreter = tf.lite.Interpreter(model_path=tflite_path)
        interpreter.allocate_tensors()

        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        # 입력 텐서 정보
        input_shape = input_details[0]["shape"]
        input_dtype = input_details[0]["dtype"]

        correct = 0
        total = len(test_images)

        for i in range(total):
            # 단일 이미지 준비
            input_data = np.expand_dims(test_images[i], axis=0).astype(input_dtype)

            # 추론 실행
            interpreter.set_tensor(input_details[0]["index"], input_data)
            interpreter.invoke()

            # 출력 추출
            output_data = interpreter.get_tensor(output_details[0]["index"])
            predicted_class = np.argmax(output_data[0])

            if predicted_class == y_true[i]:
                correct += 1

        accuracy = correct / total if total > 0 else 0.0
        return accuracy
