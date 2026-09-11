import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_quiz_fixtures.dart';

/// 三支 quiz 函式回應的本機判讀規格。判讀抽成公開純函式（與 `assignmentsOf`
/// 同慣例），不碰網路。
void main() {
  void resetConnectorStatics() {
    MoodleWebApiConnector.siteInfo = null;
    MoodleWebApiConnector.userId = null;
    MoodleWebApiConnector.onApiError = null;
    MoodleWebApiConnector.wsToken = null;
  }

  setUp(resetConnectorStatics);
  tearDown(resetConnectorStatics);

  group('quizzesOf', () {
    test('正常回應剝出全部測驗，維持伺服器順序', () {
      final list =
          MoodleWebApiConnector.quizzesOf(loadMoodleQuizFixture('get_quizzes'));

      expect(list, isNotNull);
      expect(list!.map((q) => q.id), [5101, 5102]);
      expect(list.map((q) => q.coursemodule), [94001, 94002]);
    });

    test('name 的 HTML 實體會被還原（format_string 把 & 寫成 &amp;）', () {
      // 與 MoodleAssignment.name 同一套：清單、AppBar 與 WebView 標題都是
      // 純文字 sink，不還原使用者就會看到 &amp;。
      final list = MoodleWebApiConnector.quizzesOf(
          loadMoodleQuizFixture('get_quizzes'))!;

      expect(list[0].name, '期中考 & 小考');
      expect(
        MoodleWebApiConnector.quizzesOf({
          'quizzes': [
            {'id': 1, 'name': 'x &lt; y &amp; z'}
          ],
          'warnings': [],
        })!
            .single
            .name,
        'x < y & z',
      );
    });

    test('空清單加上 warnings 是失敗（未選課或無權限），不是「沒有測驗」', () {
      expect(
        MoodleWebApiConnector.quizzesOf(
            loadMoodleQuizFixture('get_quizzes_not_enrolled')),
        isNull,
      );
    });

    test('空清單而且沒有 warnings 回空清單（這門課真的沒有測驗）', () {
      final list = MoodleWebApiConnector.quizzesOf(
          loadMoodleQuizFixture('get_quizzes_empty'));

      expect(list, isNotNull);
      expect(list, isEmpty);
    });

    test('形狀不對一律回 null', () {
      expect(MoodleWebApiConnector.quizzesOf('<html>login</html>'), isNull);
      expect(MoodleWebApiConnector.quizzesOf(null), isNull);
      expect(MoodleWebApiConnector.quizzesOf(<dynamic>[]), isNull);
      expect(MoodleWebApiConnector.quizzesOf({'warnings': []}), isNull);
    });
  });

  group('quizAttemptsOf', () {
    test('維持伺服器的 attempt ASC 順序', () {
      final list = MoodleWebApiConnector.quizAttemptsOf(
          loadMoodleQuizFixture('attempts_mixed'))!;

      expect(list.map((a) => a.attempt), [1, 2, 3]);
      expect(list.map((a) => a.state), ['finished', 'abandoned', 'inprogress']);
    });

    test('preview 的那幾筆被濾掉', () {
      final list = MoodleWebApiConnector.quizAttemptsOf(
          loadMoodleQuizFixture('attempts_with_preview'))!;

      expect(list.map((a) => a.id), [71011]);
    });

    test('空清單是合法結果', () {
      expect(
        MoodleWebApiConnector.quizAttemptsOf(
            loadMoodleQuizFixture('attempts_none')),
        isEmpty,
      );
    });

    test('Moodle 5.0 才有的兩個 state 原樣帶上來', () {
      final list = MoodleWebApiConnector.quizAttemptsOf(
          loadMoodleQuizFixture('attempts_moodle_500_states'))!;

      expect(list.map((a) => a.state), ['submitted', 'notstarted']);
    });

    test('attempts 缺席或不是陣列時回 null', () {
      expect(MoodleWebApiConnector.quizAttemptsOf({'warnings': []}), isNull);
      expect(MoodleWebApiConnector.quizAttemptsOf({'attempts': 'x'}), isNull);
      expect(MoodleWebApiConnector.quizAttemptsOf(null), isNull);
      expect(MoodleWebApiConnector.quizAttemptsOf(<dynamic>[]), isNull);
    });
  });

  group('quizBestGradeOf', () {
    test('三種正常回應都建得出模型', () {
      final graded = MoodleWebApiConnector.quizBestGradeOf(
          loadMoodleQuizFixture('best_grade'))!;
      expect(graded.hasgrade, isTrue);
      expect(graded.grade, 12.5);
      expect(graded.gradetopass, 10);

      final none = MoodleWebApiConnector.quizBestGradeOf(
          loadMoodleQuizFixture('best_grade_no_grade'))!;
      expect(none.hasgrade, isFalse);
      expect(none.grade, isNull);

      final noPass = MoodleWebApiConnector.quizBestGradeOf(
          loadMoodleQuizFixture('best_grade_no_pass'))!;
      expect(noPass.hasGradeToPass, isFalse);
    });

    test('hasgrade 缺席回 null（快取解碼就是靠這個標記）', () {
      expect(MoodleWebApiConnector.quizBestGradeOf({'warnings': []}), isNull);
      expect(MoodleWebApiConnector.quizBestGradeOf(null), isNull);
      expect(MoodleWebApiConnector.quizBestGradeOf('x'), isNull);
    });
  });

  group('preferredQuizAttemptsFunction', () {
    MoodleProfileEntity profileWith(List<String> names) =>
        MoodleProfileEntity.fromJson({
          'functions': [
            for (final n in names) {'name': n, 'version': '2024042200'},
          ],
        });

    test('siteInfo 還沒載入 → 舊名（4.5 唯一存在的一支）', () {
      expect(MoodleWebApiConnector.siteInfo, isNull);
      expect(MoodleWebApiConnector.preferredQuizAttemptsFunction(),
          'mod_quiz_get_user_attempts');
    });

    test('functions[] 是空的（knowsWsFunctions 為 false）→ 舊名', () {
      MoodleWebApiConnector.siteInfo = profileWith([]);

      expect(MoodleWebApiConnector.preferredQuizAttemptsFunction(),
          MoodleWebApiConnector.quizAttemptsFunction);
    });

    test('只有舊名 → 舊名', () {
      MoodleWebApiConnector.siteInfo =
          profileWith([MoodleWebApiConnector.quizAttemptsFunction]);

      expect(MoodleWebApiConnector.preferredQuizAttemptsFunction(),
          MoodleWebApiConnector.quizAttemptsFunction);
    });

    test('站台列了新名 → 用新名（站台升級到 5.x 時的判準）', () {
      MoodleWebApiConnector.siteInfo = profileWith([
        MoodleWebApiConnector.quizAttemptsFunction,
        MoodleWebApiConnector.quizUserAttemptsFunction,
      ]);

      expect(MoodleWebApiConnector.preferredQuizAttemptsFunction(),
          'mod_quiz_get_user_quiz_attempts');
    });
  });

  group('wsFunctionBlocked', () {
    test('site_info 沒列 mod_quiz_get_quizzes_by_courses 時在送出前就擋下', () {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity.fromJson({
        'functions': [
          {'name': 'core_course_get_contents', 'version': '2022041900'},
        ],
      });

      final blocked = MoodleWebApiConnector.wsFunctionBlocked(
          MoodleWebApiConnector.quizzesFunction);

      expect(blocked, isNotNull);
      expect(blocked!.skippedBeforeRequest, isTrue);
      expect(blocked.errorcode, 'accessexception');
      expect(
        MoodleWebApiConnector.wsFunctionBlocked(
            MoodleWebApiConnector.quizBestGradeFunction),
        isNotNull,
      );
    });
  });

  group('quizViewUrl', () {
    test('用 cmid 組出 mod/quiz/view.php', () {
      // 參數是 course module id（quizzes[].coursemodule），不是 quiz id。
      expect(
        MoodleWebApiConnector.quizViewUrl(4242),
        'https://moodle2.ntust.edu.tw/mod/quiz/view.php?id=4242',
      );
    });
  });

  group('常數', () {
    test('function 名稱與 status', () {
      expect(MoodleWebApiConnector.quizzesFunction,
          'mod_quiz_get_quizzes_by_courses');
      expect(MoodleWebApiConnector.quizAttemptsFunction,
          'mod_quiz_get_user_attempts');
      expect(MoodleWebApiConnector.quizUserAttemptsFunction,
          'mod_quiz_get_user_quiz_attempts');
      expect(MoodleWebApiConnector.quizBestGradeFunction,
          'mod_quiz_get_user_best_grade');
      // 伺服器預設的 'finished' 會漏掉 inprogress 與 overdue。
      expect(MoodleWebApiConnector.quizAttemptsStatus, 'all');
    });
  });
}
