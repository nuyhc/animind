import '../models/classification_result.dart';
import '../models/formatted_result.dart';

/// 분류 결과를 한국어 문장으로 변환하는 서비스
abstract class ResultFormatter {
  /// 분류 결과를 한국어 표현으로 변환한다
  FormattedResult format(ClassificationSuccess result);
}
