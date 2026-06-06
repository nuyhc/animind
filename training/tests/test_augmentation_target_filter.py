"""증강 대상 선별 속성 기반 테스트

aug- 접두사 파일은 학습에 포함하되 증강 대상에서 제외됨을 검증한다.
filter_augmentation_targets()가 원본과 aug- 파일을 올바르게 분리하는지
임의의 파일 목록에 대해 속성 기반 테스트로 검증한다.

Feature: animal-emotion-recognition, Property 11: 증강 대상 선별 (aug- 접두사 제외)
Validates: Requirements 5.4
"""

from hypothesis import given, settings
from hypothesis import strategies as st

from training.data_augmentor import AUG_PREFIX, DataAugmentor


# --- 전략(Strategy) 정의 ---

# 유효한 이미지 파일 확장자
_IMAGE_EXTENSIONS = st.sampled_from([".jpg", ".jpeg", ".png"])

# 일반 파일명 (aug-로 시작하지 않는 파일명)
_original_filename = st.from_regex(
    r"[a-zA-Z0-9][a-zA-Z0-9_\-]{0,20}", fullmatch=True
).filter(lambda s: not s.startswith("aug-"))

# aug- 접두사가 붙은 파일명
_aug_filename = st.builds(
    lambda suffix: f"{AUG_PREFIX}{suffix}",
    st.from_regex(r"[a-zA-Z0-9][a-zA-Z0-9_\-]{0,20}", fullmatch=True),
)

# 디렉토리 경로 (Unix 또는 Windows 스타일)
_directory_path = st.from_regex(
    r"/[a-z]{1,10}(/[a-z]{1,10}){0,3}", fullmatch=True
)


def _build_file_path(directory: str, filename: str, ext: str) -> str:
    """디렉토리 + 파일명 + 확장자를 결합하여 전체 경로를 생성한다"""
    return f"{directory}/{filename}{ext}"


# 원본 파일 전체 경로 전략
_original_file_path = st.builds(
    _build_file_path,
    _directory_path,
    _original_filename,
    _IMAGE_EXTENSIONS,
)

# aug- 파일 전체 경로 전략
_aug_file_path = st.builds(
    _build_file_path,
    _directory_path,
    _aug_filename,
    _IMAGE_EXTENSIONS,
)

# 원본과 aug- 파일이 혼합된 파일 목록 전략
_mixed_file_list = st.lists(
    st.one_of(_original_file_path, _aug_file_path),
    min_size=0,
    max_size=50,
)


# --- 테스트 픽스처 ---

# DataAugmentor 인스턴스 (filter_augmentation_targets는 dataset_path를 사용하지 않음)
_augmentor = DataAugmentor("/dummy/path")


# --- 속성 테스트 ---


class TestAugmentationTargetFilterProperty:
    """Property 11: 증강 대상 선별 (aug- 접두사 제외)

    임의의 파일 목록에서:
    - aug- 파일은 학습에 포함하되 증강 대상에서 제외됨을 검증
    - 원본 파일만 증강 대상으로 선별됨을 검증

    Feature: animal-emotion-recognition, Property 11: 증강 대상 선별 (aug- 접두사 제외)
    Validates: Requirements 5.4
    """

    @given(file_list=_mixed_file_list)
    @settings(max_examples=200)
    def test_originals_do_not_start_with_aug_prefix(self, file_list: list[str]):
        """속성 (a): 반환된 원본 파일은 모두 aug- 접두사로 시작하지 않아야 한다

        **Validates: Requirements 5.4**
        """
        originals, _ = _augmentor.filter_augmentation_targets(file_list)

        import os

        for file_path in originals:
            filename = os.path.basename(file_path)
            assert not filename.startswith(
                AUG_PREFIX
            ), f"원본 목록에 aug- 파일이 포함됨: {file_path}"

    @given(file_list=_mixed_file_list)
    @settings(max_examples=200)
    def test_aug_files_all_start_with_aug_prefix(self, file_list: list[str]):
        """속성 (b): 반환된 aug- 파일은 모두 aug- 접두사로 시작해야 한다

        **Validates: Requirements 5.4**
        """
        _, aug_files = _augmentor.filter_augmentation_targets(file_list)

        import os

        for file_path in aug_files:
            filename = os.path.basename(file_path)
            assert filename.startswith(
                AUG_PREFIX
            ), f"aug- 목록에 원본 파일이 포함됨: {file_path}"

    @given(file_list=_mixed_file_list)
    @settings(max_examples=200)
    def test_no_files_lost_or_duplicated(self, file_list: list[str]):
        """속성 (c, d): 파일이 손실되거나 중복되지 않아야 한다

        분리 후 두 목록의 합집합이 원본 목록과 동일해야 한다.

        **Validates: Requirements 5.4**
        """
        originals, aug_files = _augmentor.filter_augmentation_targets(file_list)

        # (c) 총 수가 일치해야 함
        assert len(originals) + len(aug_files) == len(
            file_list
        ), f"파일 수 불일치: {len(originals)} + {len(aug_files)} != {len(file_list)}"

        # (d) 합집합이 원본과 동일해야 함 (순서 무관, 중복 포함)
        combined = originals + aug_files
        assert sorted(combined) == sorted(
            file_list
        ), "분리 후 합집합이 원본 목록과 일치하지 않음"
