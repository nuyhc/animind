"""전체 학습 파이프라인 실행 스크립트

1. 데이터 증강
2. 모델 학습
3. 평가
4. TFLite 변환
5. Flutter assets 배포
"""

import os
import random
import sys

import numpy as np

# 재현성을 위한 전역 시드 (증강은 표준 random 모듈에 의존하므로 학습 이전에 고정)
SEED = 42

# 프로젝트 루트를 기준으로 경로 설정
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
DATASET_PATH = os.path.join(PROJECT_ROOT, "dataset", "Master Folder")

# 프로젝트 루트를 sys.path에 추가하여 training 패키지 import 가능하게 함
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from training.data_augmentor import DataAugmentor, CATEGORIES
from training.model_trainer import ModelTrainer
from training.model_converter import ModelConverter


def main():
    print("=" * 60)
    print("동물 감정 인식 - 학습 파이프라인 실행")
    print("=" * 60)

    # 0. 전역 시드 고정 (증강 단계 이전에 수행해야 재현성 보장)
    random.seed(SEED)
    np.random.seed(SEED)

    # 1. 데이터 증강
    print("\n[1/5] 데이터 증강 중...")
    augmentor = DataAugmentor(DATASET_PATH)
    train_data = augmentor.run_augmentation_pipeline(min_expansion_ratio=4)

    print(f"\n최종 학습 데이터:")
    for cat in CATEGORIES:
        print(f"  {cat}: {len(train_data.get(cat, []))}장")

    # 2. 모델 학습 데이터 준비
    print("\n[2/5] 학습 데이터 준비 중...")
    trainer = ModelTrainer(dataset_path=DATASET_PATH, seed=SEED, model_version="1.0.0")

    # 학습 데이터 변환 (numpy 배열)
    train_images, train_labels = trainer.prepare_data(train_data)
    print(f"  학습 이미지 형태: {train_images.shape}")
    print(f"  학습 레이블 형태: {train_labels.shape}")

    # 검증/테스트 데이터 로딩
    valid_paths = augmentor.get_validation_data()
    test_paths = augmentor.get_test_data()

    valid_images, valid_labels = trainer.prepare_data_from_paths(valid_paths)
    test_images, test_labels = trainer.prepare_data_from_paths(test_paths)

    print(f"  검증 이미지 형태: {valid_images.shape}")
    print(f"  테스트 이미지 형태: {test_images.shape}")

    # 3. 모델 학습 (2단계: 헤드 학습 → 상위 레이어 파인튜닝)
    print("\n[3/5] 모델 학습 중...")
    trainer.build_model()
    history = trainer.train(
        train_data=(train_images, train_labels),
        valid_data=(valid_images, valid_labels),
        epochs=25,
        batch_size=32,
        fine_tune_epochs=15,
        fine_tune_at=100,
    )
    print(f"  파인튜닝 단계 에포크 수: {len(history.history['loss'])}")

    # 4. 평가
    print("\n[4/5] 모델 평가 중...")
    report = trainer.generate_report(test_data=(test_images, test_labels))

    print(f"  전체 정확도: {report['accuracy']:.4f}")
    print(f"  Macro F1: {report['macro_f1']:.4f}")
    for cat in CATEGORIES:
        print(f"  {cat} - Precision: {report['per_class_precision'][cat]:.4f}, "
              f"Recall: {report['per_class_recall'][cat]:.4f}, "
              f"F1: {report['per_class_f1'][cat]:.4f}")

    # 성능 기준 검증
    criteria_result = trainer.check_performance_criteria(report)
    if criteria_result["passed"]:
        print("\n  ✓ 모든 성능 기준 충족!")
    else:
        print("\n  ✗ 성능 기준 미달:")
        for failure in criteria_result["failures"]:
            print(f"    - {failure}")
        print("\n  경고: 성능 기준을 만족하지 못하지만 변환을 계속 진행합니다.")

    # 모델 및 보고서 저장
    model_save_path = os.path.join(PROJECT_ROOT, "training", "output", "emotion_model.keras")
    trainer.save_model(model_save_path)

    report_save_path = os.path.join(PROJECT_ROOT, "training", "output", "evaluation_report.json")
    trainer.save_report(report, report_save_path)

    # 5. TFLite 변환
    print("\n[5/5] TFLite 변환 중...")
    output_dir = os.path.join(PROJECT_ROOT, "training", "output")
    converter = ModelConverter(model_path=model_save_path, output_dir=output_dir)

    try:
        tflite_path = converter.convert_with_fallback(
            test_data=(test_images, test_labels)
        )
        print(f"  TFLite 변환 성공: {tflite_path}")

        # Flutter assets로 복사
        dest_path = converter.copy_to_flutter_assets(tflite_path)
        print(f"  Flutter assets 배포 완료: {dest_path}")

    except Exception as e:
        print(f"  TFLite 변환 실패: {e}")
        print("  모델을 양자화 없이 직접 변환합니다...")
        tflite_path = converter.convert(quantization="none")
        dest_path = converter.copy_to_flutter_assets(tflite_path)
        print(f"  Flutter assets 배포 완료: {dest_path}")

    print("\n" + "=" * 60)
    print("파이프라인 완료!")
    print("=" * 60)


if __name__ == "__main__":
    main()
