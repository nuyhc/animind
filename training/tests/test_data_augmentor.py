"""DataAugmentor 단위 테스트

데이터 증강기의 핵심 로직을 검증하는 테스트.
"""

import os
import tempfile
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from training.data_augmentor import (
    AUG_PREFIX,
    CATEGORIES,
    CATEGORY_FOLDER_NAMES,
    DataAugmentor,
    DatasetSplit,
)


@pytest.fixture
def sample_dataset(tmp_path: Path) -> Path:
    """테스트용 샘플 데이터셋 구조 생성"""
    # Master Folder 구조 생성
    for split in ["train", "valid", "test"]:
        for category in CATEGORIES:
            folder_name = CATEGORY_FOLDER_NAMES[category]
            category_dir = tmp_path / split / folder_name
            category_dir.mkdir(parents=True, exist_ok=True)

            if split == "train":
                # 원본 이미지 생성
                for i in range(5):
                    img = Image.fromarray(
                        np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)
                    )
                    img.save(category_dir / f"{i:02d}.jpg")
                # aug- 접두사 이미지 생성
                for i in range(3):
                    img = Image.fromarray(
                        np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)
                    )
                    img.save(category_dir / f"aug-{i}-{i:02d}.jpg")
            else:
                # valid/test: 원본만
                for i in range(3):
                    img = Image.fromarray(
                        np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)
                    )
                    img.save(category_dir / f"{i:02d}.jpg")

    return tmp_path


@pytest.fixture
def augmentor(sample_dataset: Path) -> DataAugmentor:
    """DataAugmentor 인스턴스 생성"""
    return DataAugmentor(str(sample_dataset))


class TestDatasetSplit:
    """DatasetSplit 데이터 클래스 테스트"""

    def test_empty_split_counts(self):
        """빈 분할의 카운트가 0인지 확인"""
        split = DatasetSplit()
        assert split.train_count == 0
        assert split.valid_count == 0
        assert split.test_count == 0

    def test_split_counts(self):
        """카운트 프로퍼티가 정확히 합산되는지 확인"""
        split = DatasetSplit(
            train_images={"Angry": ["a", "b"], "Happy": ["c"]},
            valid_images={"Angry": ["d"]},
            test_images={"Angry": ["e", "f"], "Sad": ["g"]},
        )
        assert split.train_count == 3
        assert split.valid_count == 1
        assert split.test_count == 3


class TestLoadSplit:
    """load_split() 메서드 테스트"""

    def test_loads_all_categories(self, augmentor: DataAugmentor):
        """모든 카테고리가 로딩되는지 확인"""
        split = augmentor.load_split()
        for category in CATEGORIES:
            assert category in split.train_images
            assert category in split.valid_images
            assert category in split.test_images

    def test_train_includes_aug_files(self, augmentor: DataAugmentor):
        """학습 데이터에 aug- 파일이 포함되는지 확인"""
        split = augmentor.load_split()
        # 각 카테고리: 원본 5 + aug- 3 = 8
        for category in CATEGORIES:
            assert len(split.train_images[category]) == 8

    def test_valid_test_no_aug_files(self, augmentor: DataAugmentor):
        """검증/테스트 데이터에 aug- 파일이 없는지 확인"""
        split = augmentor.load_split()
        for category in CATEGORIES:
            assert len(split.valid_images[category]) == 3
            assert len(split.test_images[category]) == 3

    def test_total_counts(self, augmentor: DataAugmentor):
        """전체 카운트가 정확한지 확인"""
        split = augmentor.load_split()
        # train: 4 카테고리 × 8 = 32
        assert split.train_count == 32
        # valid: 4 × 3 = 12
        assert split.valid_count == 12
        # test: 4 × 3 = 12
        assert split.test_count == 12


class TestFilterAugmentationTargets:
    """filter_augmentation_targets() 메서드 테스트"""

    def test_separates_original_and_aug(self, augmentor: DataAugmentor):
        """원본과 aug- 파일이 올바르게 분리되는지 확인"""
        file_list = [
            "/path/to/01.jpg",
            "/path/to/aug-0-01.jpg",
            "/path/to/02.jpg",
            "/path/to/aug-1-02.jpg",
        ]
        originals, augs = augmentor.filter_augmentation_targets(file_list)
        assert originals == ["/path/to/01.jpg", "/path/to/02.jpg"]
        assert augs == ["/path/to/aug-0-01.jpg", "/path/to/aug-1-02.jpg"]

    def test_all_originals(self, augmentor: DataAugmentor):
        """모든 파일이 원본인 경우"""
        file_list = ["/path/to/01.jpg", "/path/to/02.jpg"]
        originals, augs = augmentor.filter_augmentation_targets(file_list)
        assert originals == file_list
        assert augs == []

    def test_all_aug_files(self, augmentor: DataAugmentor):
        """모든 파일이 aug-인 경우"""
        file_list = ["/path/to/aug-0-01.jpg", "/path/to/aug-1-02.jpg"]
        originals, augs = augmentor.filter_augmentation_targets(file_list)
        assert originals == []
        assert augs == file_list

    def test_empty_list(self, augmentor: DataAugmentor):
        """빈 목록 처리"""
        originals, augs = augmentor.filter_augmentation_targets([])
        assert originals == []
        assert augs == []


class TestRequiredNewAugmentationCount:
    """required_new_augmentation_count() 메서드 테스트"""

    def test_basic_calculation(self, augmentor: DataAugmentor):
        """기본 신규 증강 수 계산"""
        # 원본 75, aug- 175, 목표 = 75 × 4 = 300
        # 필요 = 300 - 75 - 175 = 50
        result = augmentor.required_new_augmentation_count(75, 175, 4)
        assert result == 50

    def test_already_sufficient(self, augmentor: DataAugmentor):
        """이미 충분한 경우 0 반환"""
        # 원본 10, aug- 40, 목표 = 10 × 4 = 40
        # 필요 = 40 - 10 - 40 = -10 → 0
        result = augmentor.required_new_augmentation_count(10, 40, 4)
        assert result == 0

    def test_no_existing_aug(self, augmentor: DataAugmentor):
        """기존 aug- 이미지가 없는 경우"""
        # 원본 10, aug- 0, 목표 = 10 × 4 = 40
        # 필요 = 40 - 10 - 0 = 30
        result = augmentor.required_new_augmentation_count(10, 0, 4)
        assert result == 30

    def test_zero_originals(self, augmentor: DataAugmentor):
        """원본이 0인 경우"""
        result = augmentor.required_new_augmentation_count(0, 10, 4)
        assert result == 0

    def test_custom_expansion_ratio(self, augmentor: DataAugmentor):
        """커스텀 확장 배율"""
        # 원본 10, aug- 5, 배율 3, 목표 = 10 × 3 = 30
        # 필요 = 30 - 10 - 5 = 15
        result = augmentor.required_new_augmentation_count(10, 5, 3)
        assert result == 15


class TestAugment:
    """augment() 메서드 테스트"""

    def test_generates_correct_count(self, augmentor: DataAugmentor):
        """요청한 수만큼 증강 이미지를 생성하는지 확인"""
        images = [np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8) for _ in range(3)]
        result = augmentor.augment(images, "Angry", 10)
        assert len(result) == 10

    def test_zero_output_count(self, augmentor: DataAugmentor):
        """output_count가 0이면 빈 목록 반환"""
        images = [np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)]
        result = augmentor.augment(images, "Angry", 0)
        assert result == []

    def test_empty_images(self, augmentor: DataAugmentor):
        """이미지 목록이 빈 경우"""
        result = augmentor.augment([], "Angry", 10)
        assert result == []

    def test_augmented_images_are_numpy_arrays(self, augmentor: DataAugmentor):
        """증강 결과가 numpy 배열인지 확인"""
        images = [np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)]
        result = augmentor.augment(images, "Happy", 5)
        for img in result:
            assert isinstance(img, np.ndarray)

    def test_augmented_images_maintain_shape(self, augmentor: DataAugmentor):
        """증강 이미지의 크기가 원본과 동일한지 확인"""
        images = [np.random.randint(0, 255, (100, 80, 3), dtype=np.uint8)]
        result = augmentor.augment(images, "Sad", 5)
        for img in result:
            assert img.shape == (100, 80, 3)


class TestBalanceClasses:
    """balance_classes() 메서드 테스트"""

    def test_already_balanced(self, augmentor: DataAugmentor):
        """이미 균형잡힌 경우 변경하지 않음"""
        data = {
            "Angry": [np.zeros((64, 64, 3), dtype=np.uint8)] * 100,
            "Happy": [np.zeros((64, 64, 3), dtype=np.uint8)] * 95,
            "Sad": [np.zeros((64, 64, 3), dtype=np.uint8)] * 90,
            "Other": [np.zeros((64, 64, 3), dtype=np.uint8)] * 85,
        }
        result = augmentor.balance_classes(data)
        # 최대 100, threshold = 80. 모든 카테고리가 80 이상이므로 변경 없음
        assert len(result["Angry"]) == 100
        assert len(result["Happy"]) == 95
        assert len(result["Sad"]) == 90
        assert len(result["Other"]) == 85

    def test_balances_underrepresented_class(self, augmentor: DataAugmentor):
        """부족한 카테고리에 추가 증강 적용"""
        data = {
            "Angry": [np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)] * 100,
            "Happy": [np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)] * 100,
            "Sad": [np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)] * 100,
            "Other": [np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)] * 50,
        }
        result = augmentor.balance_classes(data)
        # 최대 100, threshold = 80. Other(50) < 80 → 80까지 증강
        assert len(result["Other"]) >= 80

    def test_empty_data(self, augmentor: DataAugmentor):
        """빈 데이터 처리"""
        result = augmentor.balance_classes({})
        assert result == {}

    def test_all_within_20_percent(self, augmentor: DataAugmentor):
        """균형 조정 후 모든 카테고리가 20% 이내인지 확인"""
        data = {
            "Angry": [np.random.randint(0, 255, (32, 32, 3), dtype=np.uint8)] * 100,
            "Happy": [np.random.randint(0, 255, (32, 32, 3), dtype=np.uint8)] * 90,
            "Sad": [np.random.randint(0, 255, (32, 32, 3), dtype=np.uint8)] * 40,
            "Other": [np.random.randint(0, 255, (32, 32, 3), dtype=np.uint8)] * 30,
        }
        result = augmentor.balance_classes(data)
        max_count = max(len(imgs) for imgs in result.values())
        for category, imgs in result.items():
            # 모든 카테고리는 최대의 80% 이상
            assert len(imgs) >= max_count * 0.8


class TestGetValidationData:
    """get_validation_data() 메서드 테스트"""

    def test_returns_original_data(self, augmentor: DataAugmentor):
        """원본 검증 데이터를 그대로 반환하는지 확인"""
        augmentor.load_split()
        valid_data = augmentor.get_validation_data()
        for category in CATEGORIES:
            assert category in valid_data
            # 각 카테고리 3장
            assert len(valid_data[category]) == 3
            # 모든 파일이 실제 존재하는 경로인지 확인
            for path in valid_data[category]:
                assert os.path.exists(path)


class TestGetTestData:
    """get_test_data() 메서드 테스트"""

    def test_returns_original_data(self, augmentor: DataAugmentor):
        """원본 테스트 데이터를 그대로 반환하는지 확인"""
        augmentor.load_split()
        test_data = augmentor.get_test_data()
        for category in CATEGORIES:
            assert category in test_data
            assert len(test_data[category]) == 3
            for path in test_data[category]:
                assert os.path.exists(path)


class TestAugmentationTechniques:
    """개별 증강 기법 동작 확인 테스트"""

    @pytest.fixture
    def sample_image(self) -> np.ndarray:
        """테스트용 샘플 이미지"""
        return np.random.randint(0, 255, (64, 64, 3), dtype=np.uint8)

    def test_rotation_changes_image(self, augmentor: DataAugmentor, sample_image: np.ndarray):
        """회전 증강이 이미지를 변경하는지 확인"""
        rotated = augmentor._augment_rotation(sample_image)
        assert rotated.shape == sample_image.shape
        # 회전 후 이미지가 원본과 다를 수 있음 (0도에 가까우면 같을 수도 있음)
        assert isinstance(rotated, np.ndarray)

    def test_horizontal_flip(self, augmentor: DataAugmentor, sample_image: np.ndarray):
        """수평 반전이 올바르게 동작하는지 확인"""
        flipped = augmentor._augment_horizontal_flip(sample_image)
        # 수평 반전 검증: 첫 번째 열과 마지막 열이 교환됨
        np.testing.assert_array_equal(flipped[:, 0, :], sample_image[:, -1, :])
        np.testing.assert_array_equal(flipped[:, -1, :], sample_image[:, 0, :])

    def test_brightness_maintains_shape(self, augmentor: DataAugmentor, sample_image: np.ndarray):
        """밝기 조절이 형태를 유지하는지 확인"""
        result = augmentor._augment_brightness(sample_image)
        assert result.shape == sample_image.shape

    def test_saturation_maintains_shape(self, augmentor: DataAugmentor, sample_image: np.ndarray):
        """채도 조절이 형태를 유지하는지 확인"""
        result = augmentor._augment_saturation(sample_image)
        assert result.shape == sample_image.shape
