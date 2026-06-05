/// 전처리 완료된 이미지 데이터
class PreprocessedImage {
  /// 모델 입력 형태의 텐서 데이터 [1, 224, 224, 3]
  final List<List<List<List<double>>>> tensorData;

  /// 이미지 너비 (224)
  final int width;

  /// 이미지 높이 (224)
  final int height;

  const PreprocessedImage({
    required this.tensorData,
    this.width = 224,
    this.height = 224,
  });
}
