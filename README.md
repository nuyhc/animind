# animind

반려동물 사진에서 감정을 추론하는 온디바이스 Flutter 앱.

카메라 촬영 또는 갤러리 이미지를 입력받아 **기기 내에서** TFLite 모델로 4개 감정
(화남 / 행복 / 슬픔 / 기타)을 분류하고, 한국어 결과 문장과 신뢰도를 제공한다.
네트워크 전송 없이 모든 분석이 단말에서 수행된다.

## 주요 기능

- 카메라 촬영 / 갤러리 선택 입력 (JPG·PNG, 10MB 이하, 최소 50×50)
- 온디바이스 감정 분류 (MobileNetV2 전이학습 → TFLite)
- 최대 확률 50% 미만 시 불확실 판정 + 상위 3개 후보 안내
- 분석 이력 저장 (SQLite, 최신 20건 유지) 및 썸네일 캐시 관리
- 메모리 압박 감지 시 캐시 단계적 정리
- 접근성 대응 (스크린 리더 라벨, 44×44dp 터치 영역, WCAG AA 명도 대비)

## 아키텍처

Clean Architecture 3계층으로 구성된다.

```
lib/
├── domain/        # 순수 Dart - 모델 + 서비스 인터페이스 (Flutter 비의존)
│   ├── models/
│   └── services/
├── data/          # 도메인 인터페이스의 구현체
│   └── services/
└── presentation/  # Flutter UI + Riverpod 상태 관리
    ├── providers/
    └── screens/
```

- 상태 관리: **Riverpod** (`flutter_riverpod`)
- 결과/검증 상태는 sealed class로 모델링하여 exhaustive 처리
- 분석 흐름: 입력 → 검증 → 메모리 확인 → 전처리 → 분류 → 포맷 → 결과 표시 → 이력 저장

## 기술 스택

| 영역 | 사용 |
|------|------|
| 앱 | Flutter, Dart 3, Riverpod |
| 추론 | tflite_flutter |
| 저장소 | sqflite (SQLite) |
| 입력/권한 | image_picker, permission_handler |
| 모델 학습 | Python, TensorFlow/Keras (MobileNetV2) |

## 실행

```bash
flutter pub get
flutter run            # 연결된 Android/iOS 기기 또는 에뮬레이터
```

> 감정 분류 모델(`assets/models/emotion_model.tflite`, 약 22MB)은 저장소에
> 포함되어 있어 클론 후 바로 실행할 수 있다. 모델을 다시 학습하려면
> 아래 학습 파이프라인을 사용한다.

## 테스트

```bash
flutter test           # 단위 / 위젯 / 속성(property) 테스트
dart analyze           # 정적 분석
```

테스트는 단위(`test/unit/`), 위젯(`test/widget/`), 속성 기반(`test/property/`)으로
구성되며 핵심 불변조건(전처리 출력 범위, 분류 합계, 이력 크기 등)을 검증한다.

## 모델 학습 파이프라인

`training/` 디렉터리에 Python 학습 파이프라인이 있다.

```bash
cd training
python run_pipeline.py     # 데이터 증강 → 학습 → 평가 → TFLite 변환
```

- `model_trainer.py` — MobileNetV2 전이학습 (4개 출력, softmax)
- `model_converter.py` — Keras → TFLite 변환 및 정확도 검증
- `run_pipeline.py` — 전체 파이프라인 오케스트레이션

학습 산출물(`training/output/`)과 모델 파일은 버전 관리에서 제외된다.

## 라이선스

내부 프로젝트.
