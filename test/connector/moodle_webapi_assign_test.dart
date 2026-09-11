import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_assign_fixtures.dart';

/// `mod_assign_get_assignments` 與 `mod_assign_get_submission_status` 回應的
/// 本機判讀規格。判讀抽成公開純函式（與 `userGradesOf` 同慣例），不碰網路。
void main() {
  void resetConnectorStatics() {
    MoodleWebApiConnector.siteInfo = null;
    MoodleWebApiConnector.userId = null;
    MoodleWebApiConnector.onApiError = null;
    MoodleWebApiConnector.wsToken = null;
  }

  setUp(resetConnectorStatics);
  tearDown(resetConnectorStatics);

  group('assignmentsOf', () {
    test('正常回應剝出全部作業，維持伺服器順序', () {
      final list = MoodleWebApiConnector.assignmentsOf(
          loadMoodleAssignFixture('get_assignments'));

      expect(list, isNotNull);
      expect(list!.map((a) => a.id), [4101, 4102]);
    });

    test('name 的 HTML 實體會被還原（format_string 把 & 寫成 &amp;）', () {
      final list = MoodleWebApiConnector.assignmentsOf(
          loadMoodleAssignFixture('get_assignments'))!;

      // 與課程目錄的 Modules.name、行事曆的事件名同一套：清單、AppBar 與
      // WebView 標題都是純文字 sink，不還原使用者就會看到 &amp;。
      expect(list[0].name, 'HW1 & Report');
      expect(list[1].name, '期末專題');
      expect(
        MoodleWebApiConnector.assignmentsOf({
          'courses': [
            {
              'assignments': [
                {'id': 1, 'name': 'x &lt; y &amp; z'}
              ]
            }
          ],
        })!
            .single
            .name,
        'x < y & z',
      );
    });

    test('courses 為空是失敗（站台用 warnings 說未選課），不是「沒有作業」', () {
      expect(
        MoodleWebApiConnector.assignmentsOf(
            loadMoodleAssignFixture('get_assignments_not_enrolled')),
        isNull,
      );
    });

    test('有課但 assignments 為空回空清單（這門課沒有作業是成功）', () {
      final list = MoodleWebApiConnector.assignmentsOf({
        'courses': [
          {'id': 1, 'fullname': 'x', 'shortname': 'x', 'assignments': []}
        ],
        'warnings': [],
      });

      expect(list, isNotNull);
      expect(list, isEmpty);
    });

    test('形狀不對一律回 null', () {
      expect(MoodleWebApiConnector.assignmentsOf('<html>login</html>'), isNull);
      expect(MoodleWebApiConnector.assignmentsOf(null), isNull);
      expect(MoodleWebApiConnector.assignmentsOf(<dynamic>[]), isNull);
    });
  });

  group('submissionStatusOf', () {
    test('正常回應建出模型', () {
      final s = MoodleWebApiConnector.submissionStatusOf(
          loadMoodleAssignFixture('status_none'));

      expect(s, isNotNull);
      expect(s!.lastattempt, isNotNull);
      expect(s.lastattempt!.submission, isNull);
    });

    test('gradefordisplay 的 &nbsp; 會被還原成 U+00A0，Text 才畫得對', () {
      // display_grade 在 Real 顯示型態下組的是 `<分數>&nbsp;/&nbsp;<滿分>`，
      // PARAM_RAW 原樣送出；不還原使用者看到的是字面上的 &nbsp;。
      final s = MoodleWebApiConnector.submissionStatusOf(
          loadMoodleAssignFixture('status_graded'))!;

      expect(s.feedback!.gradefordisplay, '85.00\u00a0/\u00a0100.00');
      expect(s.feedback!.gradefordisplay, isNot(contains('&')));
    });

    test('量尺成績與沒有 feedback 的回應不受影響', () {
      expect(
        MoodleWebApiConnector.submissionStatusOf(
                loadMoodleAssignFixture('status_workflow_released'))!
            .feedback!
            .gradefordisplay,
        'A',
      );
      expect(
        MoodleWebApiConnector.submissionStatusOf(
                loadMoodleAssignFixture('status_none'))!
            .feedback,
        isNull,
      );
    });

    test('形狀不對回 null', () {
      expect(MoodleWebApiConnector.submissionStatusOf(<dynamic>[]), isNull);
      expect(MoodleWebApiConnector.submissionStatusOf(null), isNull);
      expect(MoodleWebApiConnector.submissionStatusOf('x'), isNull);
    });
  });

  group('isOwnHost / isOwnPluginFileUrl / isAutologinScript', () {
    test('isOwnHost 只比 host', () {
      expect(
          MoodleWebApiConnector.isOwnHost(
              Uri.parse('https://moodle2.ntust.edu.tw/mod/assign/view.php')),
          isTrue);
      expect(
          MoodleWebApiConnector.isOwnHost(
              Uri.parse('http://moodle2.ntust.edu.tw/')),
          isTrue);
      expect(
          MoodleWebApiConnector.isOwnHost(
              Uri.parse('https://moodle.ntust.edu.tw/')),
          isFalse);
      expect(MoodleWebApiConnector.isOwnHost(Uri.parse('https://example.com')),
          isFalse);
      expect(MoodleWebApiConnector.isOwnHost(null), isFalse);
    });

    test('isOwnPluginFileUrl：只有自家 https 的 pluginfile 網址', () {
      const own =
          'https://moodle2.ntust.edu.tw/webservice/pluginfile.php/555/mod_assign/intro/0/a.png';
      expect(MoodleWebApiConnector.isOwnPluginFileUrl(own), isTrue);
      expect(
          MoodleWebApiConnector.isOwnPluginFileUrl(
              'https://moodle2.ntust.edu.tw/pluginfile.php/555/mod_assign/intro/0/a.png'),
          isTrue);
      // 外站、data: URI、自家但不是 pluginfile、http，都交回預設 factory。
      expect(
          MoodleWebApiConnector.isOwnPluginFileUrl(
              'https://example.com/pluginfile.php/1/a.png'),
          isFalse);
      expect(
          MoodleWebApiConnector.isOwnPluginFileUrl(
              'data:image/png;base64,iVBORw0KGgo='),
          isFalse);
      expect(
          MoodleWebApiConnector.isOwnPluginFileUrl(
              'https://moodle2.ntust.edu.tw/theme/image.php/boost/core/1/i/x'),
          isFalse);
      expect(
          MoodleWebApiConnector.isOwnPluginFileUrl(
              'http://moodle2.ntust.edu.tw/webservice/pluginfile.php/1/a.png'),
          isFalse);
      expect(MoodleWebApiConnector.isOwnPluginFileUrl(''), isFalse);
      expect(MoodleWebApiConnector.isOwnPluginFileUrl('::bad'), isFalse);
    });

    test('isAutologinScript：自家的 admin/tool/mobile/autologin.php', () {
      expect(
          MoodleWebApiConnector.isAutologinScript(Uri.parse(
              'https://moodle2.ntust.edu.tw/admin/tool/mobile/autologin.php?userid=1&key=x')),
          isTrue);
      expect(
          MoodleWebApiConnector.isAutologinScript(
              Uri.parse('https://moodle2.ntust.edu.tw/mod/assign/view.php')),
          isFalse);
      expect(
          MoodleWebApiConnector.isAutologinScript(
              Uri.parse('https://example.com/admin/tool/mobile/autologin.php')),
          isFalse);
      expect(MoodleWebApiConnector.isAutologinScript(null), isFalse);
    });
  });

  group('assignViewUrl', () {
    test('用 cmid 組出 mod/assign/view.php', () {
      expect(
        MoodleWebApiConnector.assignViewUrl(93001),
        'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=93001',
      );
    });
  });

  group('wsFunctionBlocked', () {
    MoodleProfileEntity profileWith(List<Map<String, dynamic>> functions) =>
        MoodleProfileEntity.fromJson({'functions': functions});

    test('site_info 沒列 mod_assign_get_assignments 時在送出前就擋下', () {
      MoodleWebApiConnector.siteInfo = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      final blocked = MoodleWebApiConnector.wsFunctionBlocked(
          MoodleWebApiConnector.assignmentsFunction);

      expect(blocked, isNotNull);
      expect(blocked!.skippedBeforeRequest, isTrue);
      expect(blocked.errorcode, 'accessexception');
      expect(
        MoodleWebApiConnector.wsFunctionBlocked(
            MoodleWebApiConnector.submissionStatusFunction),
        isNotNull,
      );
    });

    test('siteInfo 還沒載入時放行（fail-open）', () {
      expect(MoodleWebApiConnector.siteInfo, isNull);
      expect(
        MoodleWebApiConnector.wsFunctionBlocked(
            MoodleWebApiConnector.assignmentsFunction),
        isNull,
      );
    });
  });

  group('常數', () {
    test('function 名稱', () {
      expect(MoodleWebApiConnector.assignmentsFunction,
          'mod_assign_get_assignments');
      expect(MoodleWebApiConnector.submissionStatusFunction,
          'mod_assign_get_submission_status');
    });
  });
}
