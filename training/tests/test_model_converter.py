"""모델 변환기 단위 테스트

파일 크기 검증, 양자화 수준 로직 등 실제 모델 변환 없이
검증 가능한 로직을 테스트한다.

Requirements: 6.3, 6.4, 6.5, 6.6
"""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

import pytest

from training.model_converter import (
    DEFAULT_TFLITE_FILENAME,
    MAX_ACCURACY_DIFF,
    MAX_FILE_SIZE_MB,
    QUANTIZATION_LEVELS,
    ModelConversionError,
    ModelConverter,
)


class TestValidateFileSize:
    """파일 크기 검증 테스트 (Req 6.6)"""

    def test_file_under_50mb_passes(self, tmp_path: Path) -> None:
        """50MB 이하 파일은 검증 통과"""
        # 10MB 크기의 임시 파일 생성
        tflite_file = tmp_path / "test_model.tflite"
        tflite_file.write_bytes(b"\x00" * (10 * 1024 * 1024))

        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )
        assert converter.validate_file_size(str(tflite_file)) is True

    def test_file_exactly_50mb_passes(self, tmp_path: Path) -> None:
        """정확히 50MB 파일은 검증 통과"""
        tflite_file = tmp_path / "test_model.tflite"
        tflite_file.write_bytes(b"\x00" * (50 * 1024 * 1024))

        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )
        assert converter.validate_file_size(str(tflite_file)) is True

    def test_file_over_50mb_fails(self, tmp_path: Path) -> None:
        """50MB 초과 파일은 검증 실패"""
        tflite_file = tmp_path / "test_model.tflite"
        # 51MB 파일 생성
        tflite_file.write_bytes(b"\x00" * (51 * 1024 * 1024))

        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )
        assert converter.validate_file_size(str(tflite_file)) is False

    def test_nonexistent_file_fails(self, tmp_path: Path) -> None:
        """존재하지 않는 파일은 검증 실패"""
        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )
        assert converter.validate_file_size("/nonexistent/path.tflite") is False

    def test_custom_max_size(self, tmp_path: Path) -> None:
        """커스텀 최대 크기 설정"""
        tflite_file = tmp_path / "test_model.tflite"
        # 30MB 파일 생성
        tflite_file.write_bytes(b"\x00" * (30 * 1024 * 1024))

        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )
        # 25MB 제한 → 실패
        assert converter.validate_file_size(str(tflite_file), max_size_mb=25) is False
        # 35MB 제한 → 통과
        assert converter.validate_file_size(str(tflite_file), max_size_mb=35) is True

    def test_empty_file_passes(self, tmp_path: Path) -> None:
        """빈 파일(0 bytes)은 검증 통과"""
        tflite_file = tmp_path / "empty.tflite"
        tflite_file.write_bytes(b"")

        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )
        assert converter.validate_file_size(str(tflite_file)) is True


class TestQuantizationLevels:
    """양자화 수준 관련 테스트 (Req 6.5)"""

    def test_quantization_levels_order(self) -> None:
        """양자화 수준이 올바른 순서로 정의됨"""
        assert QUANTIZATION_LEVELS == ["none", "dynamic", "float16"]

    def test_invalid_quantization_raises_error(self, tmp_path: Path) -> None:
        """지원하지 않는 양자화 옵션은 ValueError 발생"""
        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )
        with pytest.raises(ValueError, match="지원하지 않는 양자화 옵션"):
            converter.convert(quantization="int8_full")

    def test_valid_quantization_options(self) -> None:
        """유효한 양자화 옵션 목록 확인"""
        assert "none" in QUANTIZATION_LEVELS
        assert "dynamic" in QUANTIZATION_LEVELS
        assert "float16" in QUANTIZATION_LEVELS
        assert len(QUANTIZATION_LEVELS) == 3


class TestModelConverterInit:
    """ModelConverter 초기화 테스트"""

    def test_default_output_dir(self) -> None:
        """기본 출력 디렉토리 설정"""
        converter = ModelConverter(model_path="model.keras")
        assert converter.output_dir == "assets/models"

    def test_custom_output_dir(self) -> None:
        """커스텀 출력 디렉토리 설정"""
        converter = ModelConverter(
            model_path="model.keras", output_dir="/custom/path"
        )
        assert converter.output_dir == "/custom/path"

    def test_model_path_stored(self) -> None:
        """모델 경로가 올바르게 저장됨"""
        converter = ModelConverter(model_path="/path/to/model.keras")
        assert converter.model_path == "/path/to/model.keras"


class TestCopyToFlutterAssets:
    """Flutter assets 복사 테스트"""

    def test_copy_existing_file(self, tmp_path: Path) -> None:
        """존재하는 파일을 Flutter assets로 복사"""
        # 원본 파일 생성
        source_file = tmp_path / "source_model.tflite"
        source_file.write_bytes(b"fake_tflite_content")

        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )

        # copy_to_flutter_assets는 프로젝트 루트 기준으로 assets/models/ 사용
        # 테스트에서는 파일 존재 여부만 검증
        dest_path = converter.copy_to_flutter_assets(str(source_file))

        assert os.path.exists(dest_path)
        assert dest_path.endswith(DEFAULT_TFLITE_FILENAME)

    def test_copy_nonexistent_file_raises_error(self, tmp_path: Path) -> None:
        """존재하지 않는 파일 복사 시 FileNotFoundError 발생"""
        converter = ModelConverter(
            model_path="dummy.keras", output_dir=str(tmp_path)
        )
        with pytest.raises(FileNotFoundError):
            converter.copy_to_flutter_assets("/nonexistent/model.tflite")


class TestConvertWithNonexistentModel:
    """존재하지 않는 모델로 변환 시도 테스트"""

    def test_convert_nonexistent_model_raises_error(self, tmp_path: Path) -> None:
        """존재하지 않는 모델 파일로 변환 시 ModelConversionError 발생"""
        converter = ModelConverter(
            model_path="/nonexistent/model.keras",
            output_dir=str(tmp_path),
        )
        with pytest.raises(ModelConversionError, match="모델 로딩 실패"):
            converter.convert()

    def test_convert_with_fallback_nonexistent_model(self, tmp_path: Path) -> None:
        """존재하지 않는 모델 파일로 fallback 변환 시 ModelConversionError 발생"""
        import numpy as np

        converter = ModelConverter(
            model_path="/nonexistent/model.keras",
            output_dir=str(tmp_path),
        )
        # 더미 테스트 데이터
        dummy_images = np.zeros((2, 224, 224, 3), dtype=np.float32)
        dummy_labels = np.array([[1, 0, 0, 0], [0, 1, 0, 0]], dtype=np.float32)

        with pytest.raises(ModelConversionError, match="모델 로딩 실패"):
            converter.convert_with_fallback((dummy_images, dummy_labels))


class TestConstants:
    """상수값 검증 테스트"""

    def test_max_accuracy_diff(self) -> None:
        """최대 정확도 차이가 5%로 설정됨"""
        assert MAX_ACCURACY_DIFF == 0.05

    def test_max_file_size_mb(self) -> None:
        """최대 파일 크기가 50MB로 설정됨"""
        assert MAX_FILE_SIZE_MB == 50

    def test_default_tflite_filename(self) -> None:
        """기본 TFLite 파일명 확인"""
        assert DEFAULT_TFLITE_FILENAME == "emotion_model.tflite"
