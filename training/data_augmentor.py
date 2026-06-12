"""데이터 증강 서비스 모듈

소규모 Kaggle "Pets Facial Expression Dataset" 보완을 위한
데이터 증강 파이프라인을 구현한다.

Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6
"""

from __future__ import annotations

import os
import random
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import numpy as np
from PIL import Image, ImageEnhance


# 데이터셋 카테고리 폴더명 매핑 (대소문자 구분)
CATEGORY_FOLDER_NAMES: dict[str, str] = {
    "Angry": "Angry",
    "Happy": "happy",
    "Sad": "Sad",
    "Other": "Other",
}

# 카테고리 목록
CATEGORIES: list[str] = ["Angry", "Happy", "Sad", "Other"]

# 증강 이미지 접두사
AUG_PREFIX: str = "aug-"

# 최소 확장 배율 (최종 학습 세트 >= 원본 × 이 값)
DEFAULT_MIN_EXPANSION_RATIO: int = 4


@dataclass
class DatasetSplit:
    """데이터셋 분할 결과

    train/valid/test 각 분할의 카테고리별 이미지 경로를 보관한다.
    """

    train_images: dict[str, list[str]] = field(default_factory=dict)
    valid_images: dict[str, list[str]] = field(default_factory=dict)
    test_images: dict[str, list[str]] = field(default_factory=dict)

    @property
    def train_count(self) -> int:
        """학습 이미지 총 수"""
        return sum(len(v) for v in self.train_images.values())

    @property
    def valid_count(self) -> int:
        """검증 이미지 총 수"""
        return sum(len(v) for v in self.valid_images.values())

    @property
    def test_count(self) -> int:
        """테스트 이미지 총 수"""
        return sum(len(v) for v in self.test_images.values())


class DataAugmentor:
    """소규모 데이터셋 보완을 위한 데이터 증강 서비스

    Master Folder의 사전 분할 구조를 활용하여 학습 데이터를 증강하고,
    카테고리 간 균형을 맞춘다.
    """

    def __init__(self, dataset_path: str) -> None:
        """
        Args:
            dataset_path: Master Folder 경로
        """
        self._dataset_path = Path(dataset_path)
        self._split: Optional[DatasetSplit] = None

    @property
    def dataset_path(self) -> Path:
        """데이터셋 기본 경로"""
        return self._dataset_path

    def load_split(self) -> DatasetSplit:
        """사전 분할된 데이터셋 구조를 로딩한다 (Req 5.1)

        Master Folder 내 train/valid/test 디렉토리에서
        각 카테고리별 이미지 파일 경로를 수집한다.

        Returns:
            DatasetSplit: train, valid, test 분할 데이터
        """
        split = DatasetSplit()

        # 각 분할별로 카테고리 이미지 로딩
        for split_name, target_dict in [
            ("train", split.train_images),
            ("valid", split.valid_images),
            ("test", split.test_images),
        ]:
            split_dir = self._dataset_path / split_name
            for category in CATEGORIES:
                folder_name = CATEGORY_FOLDER_NAMES[category]
                category_dir = split_dir / folder_name
                if category_dir.exists():
                    # 이미지 파일만 수집 (jpg, jpeg, png)
                    image_files = sorted(
                        [
                            str(f)
                            for f in category_dir.iterdir()
                            if f.is_file()
                            and f.suffix.lower() in (".jpg", ".jpeg", ".png")
                        ]
                    )
                    target_dict[category] = image_files
                else:
                    target_dict[category] = []

        self._split = split
        return split

    def filter_augmentation_targets(
        self, file_list: list[str]
    ) -> tuple[list[str], list[str]]:
        """aug- 접두사 파일과 원본 파일을 분리한다 (Req 5.4)

        - aug- 접두사 파일: 학습 데이터로 활용하되 증강 대상에서 제외
        - 원본 파일: 학습 데이터 + 증강 대상

        Args:
            file_list: 파일 경로 목록

        Returns:
            (원본 파일 목록, aug- 파일 목록) 튜플
        """
        originals: list[str] = []
        aug_files: list[str] = []

        for file_path in file_list:
            filename = os.path.basename(file_path)
            if filename.startswith(AUG_PREFIX):
                aug_files.append(file_path)
            else:
                originals.append(file_path)

        return originals, aug_files

    def required_new_augmentation_count(
        self,
        original_count: int,
        existing_aug_count: int,
        min_expansion_ratio: int = DEFAULT_MIN_EXPANSION_RATIO,
    ) -> int:
        """최종 학습 세트가 원본 기준 최소 배수를 만족하기 위한 신규 증강 수를 계산한다 (Req 5.2)

        최종 학습 세트 = 원본 + 기존 aug- 이미지 + 신규 증강 이미지.
        반환값은 max(0, 원본 수 × 최소 배수 - 원본 수 - 기존 aug- 수)이다.

        Args:
            original_count: 원본(non-aug) 이미지 수
            existing_aug_count: 기존 aug- 접두사 이미지 수
            min_expansion_ratio: 최소 확장 배율 (기본값 4)

        Returns:
            신규 증강해야 할 이미지 수
        """
        target_total = original_count * min_expansion_ratio
        current_total = original_count + existing_aug_count
        return max(0, target_total - current_total)

    def augment(
        self,
        images: list[np.ndarray],
        category: str,
        output_count: int,
    ) -> list[np.ndarray]:
        """원본 이미지에 증강 기법을 적용하여 필요한 신규 증강 이미지를 생성한다 (Req 5.2)

        증강 기법:
        - 회전: 최대 ±30도
        - 수평 반전
        - 밝기 조절: ±20%
        - 채도 조절: ±20%

        Args:
            images: 원본 이미지 numpy 배열 목록 (RGB, uint8 또는 float)
            category: 감정 카테고리명
            output_count: 생성해야 하는 신규 증강 이미지 수

        Returns:
            신규 증강 이미지 numpy 배열 목록
        """
        if output_count <= 0 or len(images) == 0:
            return []

        augmented: list[np.ndarray] = []

        for i in range(output_count):
            # 원본 이미지에서 순환 선택
            source_image = images[i % len(images)]
            # 증강 기법 랜덤 조합 적용
            aug_image = self._apply_random_augmentation(source_image)
            augmented.append(aug_image)

        return augmented

    def balance_classes(
        self, augmented_data: dict[str, list[np.ndarray]]
    ) -> dict[str, list[np.ndarray]]:
        """4개 카테고리 간 클래스 균형을 맞춘다 (Req 5.5, 5.6)

        특정 카테고리가 최대 카테고리 대비 20% 이상 적으면
        해당 카테고리에 추가 증강을 적용한다.

        Args:
            augmented_data: {카테고리: 이미지 numpy 배열 목록} 딕셔너리

        Returns:
            균형 조정된 데이터 딕셔너리
        """
        if not augmented_data:
            return augmented_data

        # 최대 카테고리 수 산출
        max_count = max(len(imgs) for imgs in augmented_data.values())

        if max_count == 0:
            return augmented_data

        # 20% 이내 허용 임계값 (최대 카테고리의 80%)
        threshold = int(max_count * 0.8)

        result = dict(augmented_data)

        for category, imgs in result.items():
            current_count = len(imgs)
            if current_count < threshold:
                # 추가 증강 필요량 계산 (최소 threshold까지)
                additional_needed = threshold - current_count
                if current_count > 0:
                    # 기존 이미지로부터 추가 증강 생성
                    additional_images = self.augment(
                        imgs, category, additional_needed
                    )
                    result[category] = imgs + additional_images

        return result

    def get_validation_data(self) -> dict[str, list[str]]:
        """검증 데이터를 원본 그대로 반환한다 (증강 미적용) (Req 5.3)

        Returns:
            {카테고리: [이미지 경로]} 딕셔너리
        """
        if self._split is None:
            self.load_split()
        assert self._split is not None
        return dict(self._split.valid_images)

    def get_test_data(self) -> dict[str, list[str]]:
        """테스트 데이터를 원본 그대로 반환한다 (증강 미적용) (Req 5.3)

        Returns:
            {카테고리: [이미지 경로]} 딕셔너리
        """
        if self._split is None:
            self.load_split()
        assert self._split is not None
        return dict(self._split.test_images)

    def _apply_random_augmentation(self, image: np.ndarray) -> np.ndarray:
        """이미지에 랜덤 증강 기법을 적용한다

        최소 1개, 최대 4개의 증강 기법을 무작위 조합하여 적용한다.

        Args:
            image: 입력 이미지 numpy 배열 (RGB)

        Returns:
            증강된 이미지 numpy 배열
        """
        # 적용할 증강 기법 목록 (모두 입력과 동일한 shape를 유지)
        augmentation_funcs = [
            self._augment_rotation,
            self._augment_horizontal_flip,
            self._augment_brightness,
            self._augment_saturation,
            self._augment_zoom,
            self._augment_shift,
            self._augment_contrast,
        ]

        # 최소 2개, 최대 4개 기법을 무작위 조합 (다양성 확보, 과변형 방지)
        num_augmentations = random.randint(2, min(4, len(augmentation_funcs)))
        selected = random.sample(augmentation_funcs, num_augmentations)

        result = image.copy()
        for func in selected:
            result = func(result)

        return result

    def _augment_rotation(self, image: np.ndarray) -> np.ndarray:
        """회전 증강: 최대 ±30도

        Args:
            image: 입력 이미지 numpy 배열

        Returns:
            회전된 이미지 numpy 배열
        """
        angle = random.uniform(-30.0, 30.0)
        pil_image = Image.fromarray(image.astype(np.uint8))
        # 빈 영역은 검은색으로 채움
        rotated = pil_image.rotate(angle, resample=Image.BILINEAR, fillcolor=(0, 0, 0))
        return np.array(rotated)

    def _augment_horizontal_flip(self, image: np.ndarray) -> np.ndarray:
        """수평 반전 증강

        Args:
            image: 입력 이미지 numpy 배열

        Returns:
            수평 반전된 이미지 numpy 배열
        """
        return np.fliplr(image).copy()

    def _augment_brightness(self, image: np.ndarray) -> np.ndarray:
        """밝기 조절 증강: ±20%

        Args:
            image: 입력 이미지 numpy 배열

        Returns:
            밝기 조절된 이미지 numpy 배열
        """
        # ±20% 범위의 밝기 팩터 (0.8 ~ 1.2)
        factor = random.uniform(0.8, 1.2)
        pil_image = Image.fromarray(image.astype(np.uint8))
        enhancer = ImageEnhance.Brightness(pil_image)
        enhanced = enhancer.enhance(factor)
        return np.array(enhanced)

    def _augment_saturation(self, image: np.ndarray) -> np.ndarray:
        """채도 조절 증강: ±20%

        Args:
            image: 입력 이미지 numpy 배열

        Returns:
            채도 조절된 이미지 numpy 배열
        """
        # ±20% 범위의 채도 팩터 (0.8 ~ 1.2)
        factor = random.uniform(0.8, 1.2)
        pil_image = Image.fromarray(image.astype(np.uint8))
        enhancer = ImageEnhance.Color(pil_image)
        enhanced = enhancer.enhance(factor)
        return np.array(enhanced)

    def _augment_zoom(self, image: np.ndarray) -> np.ndarray:
        """줌(중앙 크롭 후 원본 크기로 확대) 증강: 75~95% 영역 크롭

        피사체 스케일 변화에 대한 강건성을 높인다. 크롭 후 원본 크기로
        리사이즈하므로 입력과 동일한 shape를 유지한다.

        Args:
            image: 입력 이미지 numpy 배열

        Returns:
            줌 증강된 이미지 numpy 배열 (원본과 동일 shape)
        """
        height, width = image.shape[:2]
        crop_ratio = random.uniform(0.75, 0.95)
        crop_h = max(1, int(height * crop_ratio))
        crop_w = max(1, int(width * crop_ratio))
        top = random.randint(0, height - crop_h)
        left = random.randint(0, width - crop_w)
        cropped = image[top : top + crop_h, left : left + crop_w]
        pil_image = Image.fromarray(cropped.astype(np.uint8))
        resized = pil_image.resize((width, height), Image.BILINEAR)
        return np.array(resized)

    def _augment_shift(self, image: np.ndarray) -> np.ndarray:
        """평행 이동 증강: 최대 ±10% (수평/수직)

        피사체 위치 변화에 대한 강건성을 높인다. 빈 영역은 검은색으로
        채우며 입력과 동일한 shape를 유지한다.

        Args:
            image: 입력 이미지 numpy 배열

        Returns:
            이동된 이미지 numpy 배열 (원본과 동일 shape)
        """
        height, width = image.shape[:2]
        max_dx = int(width * 0.1)
        max_dy = int(height * 0.1)
        dx = random.randint(-max_dx, max_dx) if max_dx > 0 else 0
        dy = random.randint(-max_dy, max_dy) if max_dy > 0 else 0
        pil_image = Image.fromarray(image.astype(np.uint8))
        shifted = pil_image.transform(
            (width, height),
            Image.AFFINE,
            (1, 0, -dx, 0, 1, -dy),
            resample=Image.BILINEAR,
            fillcolor=(0, 0, 0),
        )
        return np.array(shifted)

    def _augment_contrast(self, image: np.ndarray) -> np.ndarray:
        """대비 조절 증강: ±25%

        조명/대비 변화에 대한 강건성을 높인다.

        Args:
            image: 입력 이미지 numpy 배열

        Returns:
            대비 조절된 이미지 numpy 배열
        """
        factor = random.uniform(0.75, 1.25)
        pil_image = Image.fromarray(image.astype(np.uint8))
        enhancer = ImageEnhance.Contrast(pil_image)
        enhanced = enhancer.enhance(factor)
        return np.array(enhanced)

    def load_images_from_paths(self, file_paths: list[str]) -> list[np.ndarray]:
        """파일 경로 목록에서 이미지를 로딩한다

        Args:
            file_paths: 이미지 파일 경로 목록

        Returns:
            numpy 배열 형태의 이미지 목록 (RGB, uint8)
        """
        images: list[np.ndarray] = []
        for path in file_paths:
            try:
                img = Image.open(path).convert("RGB")
                images.append(np.array(img))
            except (OSError, IOError) as e:
                # 손상된 파일은 건너뛴다
                print(f"[경고] 이미지 로딩 실패: {path} - {e}")
                continue
        return images

    def run_augmentation_pipeline(
        self,
        min_expansion_ratio: int = DEFAULT_MIN_EXPANSION_RATIO,
    ) -> dict[str, list[np.ndarray]]:
        """전체 증강 파이프라인을 실행한다

        1. 데이터셋 로딩
        2. 카테고리별 원본/aug- 파일 분리
        3. 필요 증강 수 계산
        4. 증강 수행
        5. 클래스 균형 조정

        Args:
            min_expansion_ratio: 최소 확장 배율 (기본값 4)

        Returns:
            {카테고리: [증강된 이미지 numpy 배열]} 딕셔너리
                (원본 + 기존 aug- + 신규 증강 모두 포함)
        """
        # 1. 데이터셋 로딩
        if self._split is None:
            self.load_split()
        assert self._split is not None

        all_train_data: dict[str, list[np.ndarray]] = {}

        for category in CATEGORIES:
            train_files = self._split.train_images.get(category, [])

            # 2. 원본/aug- 파일 분리
            originals, aug_files = self.filter_augmentation_targets(train_files)

            # 3. 필요 증강 수 계산
            needed = self.required_new_augmentation_count(
                original_count=len(originals),
                existing_aug_count=len(aug_files),
                min_expansion_ratio=min_expansion_ratio,
            )

            # 원본 이미지 로딩 (증강 대상)
            original_images = self.load_images_from_paths(originals)

            # 기존 aug- 이미지 로딩
            aug_images = self.load_images_from_paths(aug_files)

            # 4. 신규 증강 수행 (원본만 대상)
            new_augmented = self.augment(original_images, category, needed)

            # 최종 학습 세트: 원본 + 기존 aug- + 신규 증강
            all_train_data[category] = original_images + aug_images + new_augmented

            print(
                f"[정보] {category}: 원본 {len(originals)}장, "
                f"기존 aug- {len(aug_files)}장, "
                f"신규 증강 {len(new_augmented)}장, "
                f"최종 {len(all_train_data[category])}장"
            )

        # 5. 클래스 균형 조정
        balanced_data = self.balance_classes(all_train_data)

        for category in CATEGORIES:
            print(
                f"[정보] 균형 조정 후 {category}: "
                f"{len(balanced_data.get(category, []))}장"
            )

        return balanced_data
