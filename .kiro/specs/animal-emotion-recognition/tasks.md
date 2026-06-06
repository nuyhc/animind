# Implementation Plan: 동물 감정 인식 (Animal Emotion Recognition)

## Overview

본 구현 계획은 Kaggle "Pets Facial Expression Dataset" 기반의 딥러닝 모델 학습 파이프라인(Python)과 Flutter 모바일 앱을 포함한다. Python 학습 파이프라인에서 데이터 증강, 모델 학습, TFLite 변환을 수행하고, Flutter 앱에서 온디바이스 추론과 한국어 결과 표현을 구현한다.

## Tasks

- [ ] 1. 프로젝트 구조 및 핵심 인터페이스 설정
  - [x] 1.1 Flutter 프로젝트 초기화 및 디렉토리 구조 생성
    - Flutter 프로젝트 생성 (Android 8.0+, iOS 14.0+ 지원)
    - `lib/domain/`, `lib/data/`, `lib/presentation/`, `lib/infrastructure/` 레이어 디렉토리 생성
    - `test/unit/`, `test/property/`, `test/widget/`, `test/integration/` 테스트 디렉토리 생성
    - `training/` 디렉토리 (Python 학습 파이프라인용) 생성
    - pubspec.yaml에 핵심 의존성 추가: `tflite_flutter`, `image_picker`, `riverpod`, `sqflite`, `hive`, `permission_handler`, `image`
    - dev_dependencies에 `glados` (속성 기반 테스트) 추가
    - _Requirements: 4.6_

  - [x] 1.2 핵심 도메인 모델 및 인터페이스 정의
    - `EmotionCategory` enum (angry, happy, sad, other) 정의
    - `EmotionPrediction`, `ClassificationResult` (sealed class), `ValidationResult` (sealed class) 정의
    - `ImageMetadata`, `ImageInputResult`, `PreprocessedImage` 데이터 클래스 정의
    - `FormattedResult`, `FormattedPrediction` 데이터 클래스 정의
    - `AnalysisHistoryEntry` 모델 (SQLite 변환 포함) 정의
    - `EmotionMapping` (이모지, 한국어명, 표현 템플릿) 정의
    - _Requirements: 2.3, 3.1, 3.2, 3.3, 4.4_

  - [x] 1.3 추상 서비스 인터페이스 정의
    - `ImageInputService` 추상 클래스 (captureFromCamera, pickFromGallery, validateImage)
    - `PreprocessorService` 추상 클래스 (preprocess)
    - `EmotionClassifierService` 추상 클래스 (initialize, classify, dispose)
    - `ResultFormatter` 추상 클래스 (format)
    - `HistoryManager` 추상 클래스 (saveResult, getHistory, deleteOldestHistory, clearOldestThumbnailCaches)
    - `MemoryMonitor` 추상 클래스 (getAppMemoryUsageMB, isUnderMemoryPressure, checkAnalysisAvailability)
    - _Requirements: 1.1, 1.2, 1.3, 2.2, 3.1, 4.4, 7.3, 7.4_

- [ ] 2. 이미지 입력 및 유효성 검증 구현
  - [x] 2.1 이미지 유효성 검증 로직 구현
    - `ImageValidator` 클래스 구현
    - 형식 검증: JPG, PNG만 허용, 나머지는 `ValidationErrorType.unsupportedFormat` 반환
    - 크기 검증: 10MB 초과 시 `ValidationErrorType.fileSizeExceeded` 반환
    - 해상도 검증: 가로/세로 50px 미만 시 `ValidationErrorType.resolutionTooLow` 반환
    - 의미 검증(동물 포함 여부)은 수행하지 않음
    - _Requirements: 1.4, 1.5, 1.8, 1.9_

  - [x]* 2.2 이미지 유효성 검증 속성 테스트 작성
    - **Property 2: 이미지 유효성 검증 정확성**
    - 임의 형식/크기/해상도 조합에 대한 검증 정확성 테스트
    - **Validates: Requirements 1.4, 1.5, 1.8**

  - [x] 2.3 이미지 입력 서비스 구현
    - `ImageInputServiceImpl` 구현 (image_picker 패키지 활용)
    - 카메라 촬영 기능 (`captureFromCamera`)
    - 갤러리 선택 기능 (`pickFromGallery`)
    - 권한 관리 (permission_handler 활용)
    - 취소 시 null 반환 처리
    - _Requirements: 1.1, 1.2, 1.6, 1.7_

  - [x]* 2.4 이미지 입력 서비스 단위 테스트 작성
    - 취소 처리, 권한 거부 시나리오 테스트
    - _Requirements: 1.6, 1.7_

- [ ] 3. 전처리 서비스 구현
  - [x] 3.1 이미지 전처리 로직 구현
    - `PreprocessorServiceImpl` 구현
    - 224x224 리사이즈 처리
    - 픽셀값 0.0~1.0 정규화
    - 텐서 데이터 [1, 224, 224, 3] 형태로 변환
    - _Requirements: 1.3_

  - [x]* 3.2 전처리 출력 불변조건 속성 테스트 작성
    - **Property 1: 전처리 출력 불변조건**
    - 임의 크기/픽셀값 이미지에 대해 출력 224x224, 값 범위 [0.0, 1.0] 검증
    - **Validates: Requirements 1.3**

- [x] 4. Checkpoint - 입력 및 전처리 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. 감정 분류 서비스 구현
  - [x] 5.1 감정 분류기 후처리 로직 구현
    - `EmotionClassifierServiceImpl` 구현
    - TFLite 모델 로딩 (tflite_flutter 패키지)
    - Softmax 정규화 후처리 (합계 1.0 보장)
    - 4개 카테고리 확률 내림차순 정렬
    - 최상위 카테고리 추출
    - 불확실 판정 (최상위 신뢰도 50% 미만)
    - 추론 실패 시 `InferenceError` 반환, 입력 이미지 보존
    - _Requirements: 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_

  - [x]* 5.2 분류 출력 불변조건 속성 테스트 작성
    - **Property 3: 분류 출력 불변조건**
    - 임의 4차원 실수 벡터(logits)에 대해 정확히 4개 카테고리, 합계 1.0, 최상위 정확성 검증
    - **Validates: Requirements 2.2, 2.3, 2.4**

  - [x]* 5.3 불확실 판정 정확성 속성 테스트 작성
    - **Property 4: 불확실 판정 정확성**
    - 최대 확률 50% 미만 시 불확실 판정 반환, 50% 이상 시 미반환 검증
    - **Validates: Requirements 2.5**

  - [x]* 5.4 비대상 이미지 입력 정책 속성 테스트 작성
    - **Property 15: 비대상 이미지 의미 검증 제외**
    - 유효 이미지는 항상 4개 감정 분류 흐름으로 처리됨을 검증
    - **Validates: Requirements 1.9, 2.6, 2.7**

- [ ] 6. 결과 포매터 구현
  - [x] 6.1 한국어 결과 포맷팅 구현
    - `ResultFormatterImpl` 구현
    - "[감정 표현] 것 같아요" 문장 구조 생성
    - 카테고리별 표현 템플릿에서 무작위 선택
    - 이모지 매핑
    - 신뢰도 정수 백분율 변환
    - 불확실 결과 시 안내 문구 + 상위 3개 목록 생성
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x]* 6.2 결과 한국어 포맷팅 속성 테스트 작성
    - **Property 5: 결과 한국어 포맷팅**
    - 임의 감정 카테고리에 대해 문장 구조, 템플릿, 이모지, 정수 백분율 검증
    - **Validates: Requirements 3.1, 3.2, 3.3**

  - [x]* 6.3 불확실 결과 포맷팅 속성 테스트 작성
    - **Property 6: 불확실 결과 포맷팅**
    - 불확실 판정 시 안내 문구, 상위 3개 항목 정렬 및 형식 검증
    - **Validates: Requirements 3.4, 3.5**

- [x] 7. Checkpoint - 분류 및 결과 표현 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. 이력 관리 및 메모리 모니터 구현
  - [x] 8.1 SQLite 데이터베이스 및 이력 관리자 구현
    - `analysis_history` 테이블 생성 (스키마대로)
    - `HistoryManagerImpl` 구현
    - 이력 저장 (`saveResult`)
    - 이력 조회 (최신순, `getHistory`)
    - 20건 초과 시 가장 오래된 항목 삭제 (`deleteOldestHistory`)
    - 썸네일 캐시 정리 (`clearOldestThumbnailCaches`) - 오래된 순서대로 삭제, 이력 row 보존
    - _Requirements: 4.4, 4.5, 4.11, 7.4_

  - [x]* 8.2 이력 저장 라운드 트립 속성 테스트 작성
    - **Property 7: 이력 저장 라운드 트립**
    - 임의 이력 항목 저장 후 조회 시 모든 필드 동일 보존 검증
    - **Validates: Requirements 4.4**

  - [x]* 8.3 이력 크기 불변조건 속성 테스트 작성
    - **Property 8: 이력 크기 불변조건**
    - 임의 수(1~100)의 이력 추가 후 항상 20건 이하 유지 검증
    - **Validates: Requirements 4.5**

  - [x]* 8.4 캐시 삭제 순서 속성 테스트 작성
    - **Property 14: 캐시 삭제 순서**
    - 메모리 부족 시 가장 오래된 썸네일부터 삭제, 이력 row 보존 검증
    - **Validates: Requirements 4.11, 7.4**

  - [x] 8.5 메모리 모니터 구현
    - `MemoryMonitorImpl` 구현
    - 앱 RSS 메모리 사용량 조회
    - 메모리 압박 판단 (180MB 초과 또는 OS 경고)
    - `MemoryStatus` 반환 (available, needsCacheClean, insufficient)
    - OS 메모리 경고 이벤트 스트림 구독
    - _Requirements: 7.3, 7.4, 7.5_

- [x] 9. Checkpoint - 이력 및 메모리 관리 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Python 학습 파이프라인 구현
  - [x] 10.1 데이터 증강기 구현
    - `training/data_augmentor.py` 생성
    - `DataAugmentor` 클래스 구현
    - `load_split()`: Master Folder 사전 분할 구조 로딩 (train/valid/test)
    - `filter_augmentation_targets()`: aug- 접두사 파일 분리 (학습 포함, 증강 제외)
    - `required_new_augmentation_count()`: 신규 증강 수 계산 (원본 × 4배 기준)
    - `augment()`: 회전(±30도), 수평 반전, 밝기(±20%), 채도(±20%) 증강
    - `balance_classes()`: 4개 카테고리 간 20% 이내 균형 조정
    - `get_validation_data()`, `get_test_data()`: 원본 그대로 반환
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [x]* 10.2 증강 확장 비율 속성 테스트 작성
    - **Property 9: 데이터 증강 확장 비율**
    - 임의 학습 이미지 구성에 대해 최종 학습 세트 ≥ 원본 × 4 검증
    - **Validates: Requirements 5.2**

  - [x]* 10.3 검증/테스트 데이터 증강 미적용 속성 테스트 작성
    - **Property 10: 검증/테스트 데이터 증강 미적용**
    - 증강 후에도 검증/테스트 데이터 원본 동일 검증
    - **Validates: Requirements 5.3**

  - [x]* 10.4 증강 대상 선별 속성 테스트 작성
    - **Property 11: 증강 대상 선별 (aug- 접두사 제외)**
    - aug- 파일은 학습에 포함하되 증강 대상에서 제외됨을 검증
    - **Validates: Requirements 5.4**

  - [x]* 10.5 클래스 균형 유지 속성 테스트 작성
    - **Property 12: 증강 후 클래스 균형 유지**
    - 불균형 데이터셋에 대해 균형 조정 후 최대 카테고리 대비 20% 이내 검증
    - **Validates: Requirements 5.5, 5.6**

  - [x] 10.6 모델 학습기 구현
    - `training/model_trainer.py` 생성
    - MobileNetV2 전이 학습 설정 (ImageNet 사전학습 가중치)
    - 분류 헤드 추가 (4개 출력 노드, softmax)
    - 조기 종료 (patience=5, validation loss 기준)
    - 학습 실행 및 평가
    - 평가 보고서 생성 (accuracy, macro F1, confusion matrix, 클래스별 metrics, seed, 모델 버전)
    - 성능 기준 검증 (전체 정확도 ≥70%, macro F1 ≥0.60, 카테고리별 ≥60%)
    - _Requirements: 6.1, 6.2, 6.7, 6.8, 6.9_

  - [x]* 10.7 조기 종료 조건 속성 테스트 작성
    - **Property 13: 조기 종료 조건 감지**
    - 임의 검증 손실 시퀀스에서 5 에포크 연속 미감소 시 종료 활성화 검증
    - **Validates: Requirements 6.7**

  - [x] 10.8 모델 변환기 구현
    - `training/model_converter.py` 생성
    - Keras 모델 → TFLite 변환
    - 변환 전후 정확도 차이 ≤5% 검증
    - 모델 파일 크기 ≤50MB 검증
    - 실패 시 양자화 수준 조정 재시도
    - 변환된 .tflite 파일을 Flutter assets 경로로 복사
    - _Requirements: 6.3, 6.4, 6.5, 6.6_

- [x] 11. Checkpoint - 학습 파이프라인 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Flutter UI 구현
  - [x] 12.1 메인 화면 구현
    - 카메라 촬영 버튼, 갤러리 선택 버튼, 이력 진입 버튼
    - 지원 입력 조건 안내 (JPG/PNG, 10MB 이하, 최소 50x50, 반려동물 표정 권장)
    - 터치 영역 최소 44x44dp
    - _Requirements: 4.1, 4.9, 4.12_

  - [x] 12.2 분석 중 상태 화면 구현
    - 입력 이미지 미리보기
    - 로딩 인디케이터
    - 진행 중 문구
    - _Requirements: 4.2_

  - [x] 12.3 일반 결과 화면 구현
    - 입력 이미지, 감정 이모지, 감정 카테고리, 정수 신뢰도, 한국어 결과 문장 표시
    - 다시 분석하기 버튼, 이력 보기 버튼
    - _Requirements: 4.3, 4.10_

  - [x] 12.4 불확실 결과 화면 구현
    - 불확실 안내 문구 ("표정이 분명하지 않아요")
    - 상위 3개 감정 후보 목록 (이모지, 카테고리명, 신뢰도)
    - 다시 분석하기 버튼, 이력 보기 버튼
    - _Requirements: 3.4, 3.5, 4.8_

  - [x] 12.5 오류 상태 화면 및 권한 안내 화면 구현
    - 오류 메시지 + 재시도/메인 복귀 버튼
    - 권한 필요 메시지 + 설정 이동 버튼 + 메인 복귀 버튼
    - _Requirements: 3.6, 4.7, 4.8_

  - [x] 12.6 이력 화면 구현
    - 최신순 이력 목록 (썸네일/대체 썸네일, 카테고리, 신뢰도, 분석 일시)
    - 빈 이력 상태 (빈 상태 메시지 + 분석 시작 버튼)
    - 캐시 삭제된 이력의 대체 썸네일 표시
    - _Requirements: 4.4, 4.8, 4.11_

  - [x]* 12.7 위젯 테스트 작성
    - 메인 화면 버튼 존재 여부
    - 결과 화면 구성 요소
    - 불확실 결과 상태 UI
    - 빈 이력 상태
    - 권한 안내 상태
    - _Requirements: 4.1, 4.3, 4.8_

- [ ] 13. 상태 관리 및 전체 흐름 연결
  - [x] 13.1 Riverpod 상태 관리 및 의존성 주입 설정
    - Provider 정의 (각 서비스별)
    - 분석 유스케이스 흐름 연결: 이미지 입력 → 검증 → 메모리 확인 → 전처리 → 분류 → 포맷 → 결과 표시 → 이력 저장
    - 오류 처리 흐름 통합 (실패 격리, 재시도 지원)
    - _Requirements: 1.1, 1.2, 2.2, 3.1, 4.2, 4.3, 7.1_

  - [x] 13.2 메모리 모니터와 이력 관리 연동
    - 분석 전 메모리 상태 확인
    - 캐시 정리 후 재확인 로직
    - 분석 거부 메시지 표시
    - 캐시 정리 알림 UI
    - _Requirements: 7.3, 7.4, 7.5_

  - [x] 13.3 접근성 및 반응형 규칙 적용
    - 모든 이미지 기반 결과에 스크린 리더용 대체 설명 추가
    - WCAG AA 명도 대비 준수
    - 시스템 글자 크기 확대 대응 (텍스트 오버플로 방지)
    - _Requirements: 4.12_

- [x] 14. Final Checkpoint - 전체 통합 검증
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Python 학습 파이프라인(tasks 10.x)은 Flutter 앱과 독립적으로 실행 가능
- 학습된 .tflite 모델 파일은 Flutter assets로 배포됨
- `glados` 패키지(Dart)와 `hypothesis` 패키지(Python)를 속성 기반 테스트에 사용

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["2.1", "3.1", "10.1"] },
    { "id": 3, "tasks": ["2.2", "2.3", "3.2", "10.2", "10.3", "10.4", "10.5"] },
    { "id": 4, "tasks": ["2.4", "5.1", "10.6"] },
    { "id": 5, "tasks": ["5.2", "5.3", "5.4", "6.1", "10.7", "10.8"] },
    { "id": 6, "tasks": ["6.2", "6.3", "8.1", "8.5"] },
    { "id": 7, "tasks": ["8.2", "8.3", "8.4"] },
    { "id": 8, "tasks": ["12.1", "12.2", "12.3", "12.4", "12.5", "12.6"] },
    { "id": 9, "tasks": ["12.7", "13.1"] },
    { "id": 10, "tasks": ["13.2", "13.3"] }
  ]
}
```
