import 'package:flutter_app/src/util/course_grading_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourseGradingUtils.parse 拆得出百分比的情況', () {
    test('一項一行', () {
      expect(
        CourseGradingUtils.parse('平時作業 30%\n期中考 30%\n期末考 40%'),
        const [
          GradingItem('平時作業', 30),
          GradingItem('期中考', 30),
          GradingItem('期末考', 40),
        ],
      );
    });

    test('全部擠在同一行', () {
      expect(
        CourseGradingUtils.parse('平時作業30%期中考30%期末考40%'),
        const [
          GradingItem('平時作業', 30),
          GradingItem('期中考', 30),
          GradingItem('期末考', 40),
        ],
      );
    });

    test('全形百分號與全形數字', () {
      expect(
        CourseGradingUtils.parse('出席：２０％\n報告：８０％'),
        const [GradingItem('出席', 20), GradingItem('報告', 80)],
      );
    });

    test('頓號與逗號當成分隔', () {
      expect(
        CourseGradingUtils.parse('作業 50%、期末報告 50%'),
        const [GradingItem('作業', 50), GradingItem('期末報告', 50)],
      );
    });

    test('小數的百分比', () {
      final items = CourseGradingUtils.parse('平時 33.5%\n期末 66.5%')!;
      expect(items.first.percent, 33.5);
      expect(items.first.percentText, '33.5%');
      expect(items.last.percentText, '66.5%');
    });

    test('整數百分比不留小數點', () {
      expect(CourseGradingUtils.parse('期末考 40%')!.single.percentText, '40%');
    });

    test('只有一項也表格化', () {
      expect(
        CourseGradingUtils.parse('期末考 100%'),
        const [GradingItem('期末考', 100)],
      );
    });
  });

  group('CourseGradingUtils.parse 退回純文字的情況', () {
    test('空字串', () {
      expect(CourseGradingUtils.parse(''), isNull);
      expect(CourseGradingUtils.parse('   \n  '), isNull);
    });

    test('完全沒有百分比', () {
      expect(CourseGradingUtils.parse('依課堂表現與期末報告綜合評定'), isNull);
    });

    test('敘述裡夾一個百分比', () {
      expect(
        CourseGradingUtils.parse('期末報告佔 100%，遲交每天扣總分一成，缺席三次以上不予計分'),
        isNull,
        reason: '整段是敘述，硬切成表格會比不切還難讀',
      );
    });

    test('只有部分項目帶百分比', () {
      expect(CourseGradingUtils.parse('期中考 30%\n期末考另行公布'), isNull);
    });

    test('百分比前面沒有名目', () {
      expect(CourseGradingUtils.parse('100%'), isNull);
    });

    test('名目長得像句子', () {
      expect(
        CourseGradingUtils.parse('本課程的成績由授課教師依照下列比重綜合評定共計 100%'),
        isNull,
      );
    });
  });
}
