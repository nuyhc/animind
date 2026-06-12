"""기존 학습 모델의 최종 softmax를 제거하여 logits 출력 모델로 재생성한다.

배경:
    앱(emotion_classifier_service_impl.dart)과 모든 분류 관련 테스트는
    "모델은 logits를 출력하고, 앱이 softmax를 적용한다"는 계약을 전제로 한다.
    그러나 학습된 모델의 마지막 층이 softmax라 앱에서 softmax가 이중 적용되어
    신뢰도가 비정상적으로 눌리는 버그가 있었다.

    본 스크립트는 재학습 없이 기존 가중치를 그대로 보존한 채 마지막 Dense 층의
    활성화만 softmax → linear로 바꿔 logits 출력 모델을 만들고, TFLite로 재변환하여
    Flutter assets에 배포한다. argmax(예측 카테고리)는 보존되며 신뢰도 계산만 정상화된다.

사용:
    training/.venv/Scripts/python.exe training/strip_softmax.py
"""

from __future__ import annotations

import os
import shutil

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

from tensorflow import keras  # noqa: E402

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

KERAS_IN = os.path.join(PROJECT_ROOT, "training", "output", "emotion_model.keras")
KERAS_OUT = os.path.join(PROJECT_ROOT, "training", "output", "emotion_model.keras")
KERAS_BACKUP = os.path.join(
    PROJECT_ROOT, "training", "output", "emotion_model_softmax_backup.keras"
)


def strip_final_softmax(model: keras.Model) -> keras.Model:
    """동일 아키텍처에서 마지막 Dense 층의 활성화만 linear로 바꾼 모델을 반환한다.

    가중치는 그대로 이식하므로 학습 결과(예측 분포의 argmax)는 보존되고,
    출력은 softmax 확률이 아니라 logits가 된다.
    """
    config = model.get_config()

    # 함수형 모델의 마지막 레이어 설정을 찾아 활성화를 linear로 변경한다.
    last_layer_cfg = config["layers"][-1]["config"]
    previous_activation = last_layer_cfg.get("activation")
    if previous_activation != "softmax":
        raise RuntimeError(
            f"마지막 층 활성화가 softmax가 아닙니다(={previous_activation}). "
            "이미 logits 출력이거나 구조가 예상과 다릅니다."
        )
    last_layer_cfg["activation"] = "linear"

    logits_model = keras.Model.from_config(config)
    # 아키텍처가 동일하므로(활성화는 가중치 없음) 전체 가중치를 그대로 이식한다.
    logits_model.set_weights(model.get_weights())
    return logits_model


def main() -> None:
    print(f"[정보] 모델 로딩: {KERAS_IN}")
    model = keras.models.load_model(KERAS_IN)

    # 원본(softmax) 모델 백업
    if not os.path.exists(KERAS_BACKUP):
        shutil.copy2(KERAS_IN, KERAS_BACKUP)
        print(f"[정보] softmax 원본 백업: {KERAS_BACKUP}")

    print("[정보] 최종 softmax 제거 → logits 출력 모델 생성")
    logits_model = strip_final_softmax(model)

    logits_model.save(KERAS_OUT)
    print(f"[정보] logits 모델 저장: {KERAS_OUT}")

    # TFLite 재변환 및 Flutter assets 배포 (기존 변환기 재사용)
    import sys

    if PROJECT_ROOT not in sys.path:
        sys.path.insert(0, PROJECT_ROOT)
    from training.model_converter import ModelConverter

    output_dir = os.path.join(PROJECT_ROOT, "training", "output")
    converter = ModelConverter(model_path=KERAS_OUT, output_dir=output_dir)

    # 원본 자산(~9MB)과 동등하게 float16 양자화로 변환, 실패 시 무양자화로 폴백
    try:
        tflite_path = converter.convert(quantization="float16")
    except Exception as e:  # noqa: BLE001 - 변환 실패 시 폴백
        print(f"[경고] float16 변환 실패, 무양자화로 재시도: {e}")
        tflite_path = converter.convert(quantization="none")

    dest = converter.copy_to_flutter_assets(tflite_path)
    print(f"[정보] Flutter assets 배포 완료: {dest}")
    print("[완료] logits 출력 모델로 재생성되었습니다.")


if __name__ == "__main__":
    main()
