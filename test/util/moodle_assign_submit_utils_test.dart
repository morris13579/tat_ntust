import 'dart:io';

import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_assign_fixtures.dart';

/// 交作業那條路的純函式規格。不碰 R.current、不碰網路。
void main() {
  MoodleAssignConfig cfg(String plugin, String name, String value,
          {String subtype = 'assignsubmission'}) =>
      MoodleAssignConfig(
          plugin: plugin, subtype: subtype, name: name, value: value);

  MoodleAssignment assignment({
    int teamsubmission = 0,
    int preventsubmissionnotingroup = 0,
    int timelimit = 0,
    int blindmarking = 0,
    int nosubmissions = 0,
    List<MoodleAssignConfig>? configs,
  }) =>
      MoodleAssignment(
        id: 1,
        teamsubmission: teamsubmission,
        preventsubmissionnotingroup: preventsubmissionnotingroup,
        timelimit: timelimit,
        blindmarking: blindmarking,
        nosubmissions: nosubmissions,
        configs: configs ??
            [cfg('file', 'enabled', '1'), cfg('onlinetext', 'enabled', '1')],
      );

  MoodleAssignSubmissionStatus status({
    bool canedit = true,
    bool cansubmit = false,
    bool locked = false,
    bool submissionsenabled = true,
    bool blindmarking = false,
    int timelimit = 0,
    bool hasLastAttempt = true,
    List<int> usergroups = const [7],
    int? submissiongroup = 7,
  }) =>
      MoodleAssignSubmissionStatus(
        lastattempt: hasLastAttempt
            ? MoodleAssignLastAttempt(
                canedit: canedit,
                cansubmit: cansubmit,
                locked: locked,
                submissionsenabled: submissionsenabled,
                blindmarking: blindmarking,
                timelimit: timelimit,
                usergroups: usergroups,
                submissiongroup: submissiongroup,
              )
            : null,
      );

  group('blockOf', () {
    test('全部允許時回 null', () {
      expect(MoodleAssignSubmitUtils.blockOf(assignment(), status()), isNull);
    });

    test('團隊作業有分到組就不擋——那是 App 現在交得出去的', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(teamsubmission: 1), status()),
          isNull);
    });

    test('團隊作業但沒有分到組', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(teamsubmission: 1, preventsubmissionnotingroup: 1),
              status(usergroups: const [], submissiongroup: null)),
          AssignSubmitBlock.noGroup);
    });

    test('團隊作業但同時在多組', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(teamsubmission: 1, preventsubmissionnotingroup: 1),
              status(usergroups: const [7, 8], submissiongroup: null)),
          AssignSubmitBlock.multipleGroups);
    });

    test('preventsubmissionnotingroup 關著時沒有組別也不擋：伺服器會收進預設組別', () {
      for (final groups in [
        const <int>[],
        const [7, 8]
      ]) {
        expect(
            MoodleAssignSubmitUtils.blockOf(assignment(teamsubmission: 1),
                status(usergroups: groups, submissiongroup: null)),
            isNull);
      }
    });

    test('有作答時限不再是理由：那條路現在走得通', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(assignment(timelimit: 600), status()),
          isNull);
      expect(
          MoodleAssignSubmitUtils.blockOf(assignment(), status(timelimit: 600)),
          isNull);
    });

    test('匿名評分不再是理由：伺服器端的寫入路徑從頭到尾沒有檢查它', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(blindmarking: 1), status()),
          isNull);
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(), status(blindmarking: true)),
          isNull);
    });

    test('第三方繳交外掛：plugindata 給不出來，只能導網頁', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(configs: [
                cfg('file', 'enabled', '1'),
                cfg('turnitintooltwo', 'enabled', '1'),
              ]),
              status()),
          AssignSubmitBlock.unsupportedPlugin);
    });

    test('comments 是唯讀的，不算不支援', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(configs: [
                cfg('file', 'enabled', '1'),
                cfg('comments', 'enabled', '1'),
              ]),
              status()),
          isNull);
    });

    test('assignfeedback 底下的外掛不看：那不是繳交外掛', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(configs: [
                cfg('file', 'enabled', '1'),
                cfg('editpdf', 'enabled', '1', subtype: 'assignfeedback'),
              ]),
              status()),
          isNull);
    });

    test('nosubmissions 是離線評分', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(nosubmissions: 1), status()),
          AssignSubmitBlock.noSubmission);
    });

    test('兩個外掛都沒開', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(configs: [
                cfg('comments', 'enabled', '1', subtype: 'assignfeedback')
              ]),
              status()),
          AssignSubmitBlock.noPlugin);
    });

    test('lastattempt 缺席 = 沒有 viewownsubmissionsummary，什麼都不顯示', () {
      expect(
          MoodleAssignSubmitUtils.blockOf(
              assignment(), status(hasLastAttempt: false)),
          AssignSubmitBlock.closed);
    });

    test('submissionsenabled / locked / canedit 任一不對就是 closed', () {
      for (final s in [
        status(submissionsenabled: false),
        status(locked: true),
        status(canedit: false),
      ]) {
        expect(MoodleAssignSubmitUtils.blockOf(assignment(), s),
            AssignSubmitBlock.closed);
      }
    });

    test('判定順序：沒有組又 canedit=false 時回 noGroup，那才是可行動的理由', () {
      expect(
        MoodleAssignSubmitUtils.blockOf(
            assignment(teamsubmission: 1, preventsubmissionnotingroup: 1),
            status(
                canedit: false, usergroups: const [], submissiongroup: null)),
        AssignSubmitBlock.noGroup,
      );
    });

    test('判定順序：不支援的外掛排在 noPlugin 之前', () {
      expect(
        MoodleAssignSubmitUtils.blockOf(
            assignment(configs: [cfg('turnitintooltwo', 'enabled', '1')]),
            status()),
        AssignSubmitBlock.unsupportedPlugin,
      );
    });

    test('fixture：可繳交的那一份真的可以交', () {
      expect(
        MoodleAssignSubmitUtils.blockOf(
            fixtureSubmittableAssignment(), fixtureStatus('status_can_edit')),
        isNull,
      );
    });

    test('fixture：被鎖定的擋下來，有時限的放行', () {
      final a = fixtureSubmittableAssignment();
      expect(MoodleAssignSubmitUtils.blockOf(a, fixtureStatus('status_locked')),
          AssignSubmitBlock.closed);
      expect(MoodleAssignSubmitUtils.blockOf(a, fixtureStatus('status_timed')),
          isNull);
    });
  });

  /// 儲存鈕的理由表。順序是規格的一部分：只回第一個理由，而且**時限到期
  /// 永遠不在裡面**——伺服器照收只標記遲交，本地擋下來就是把寫好的東西鎖死。
  group('saveBlockOf', () {
    AssignSaveBlock? call({
      bool emptied = false,
      bool over = false,
      bool statementOk = true,
      bool dirty = true,
    }) =>
        MoodleAssignSubmitUtils.saveBlockOf(
          filesEmptied: emptied,
          overWordLimit: over,
          statementOk: statementOk,
          dirty: dirty,
        );

    test('全部過關就是 null', () {
      expect(call(), isNull);
    });

    test('四個理由各自認得出來', () {
      expect(call(emptied: true), AssignSaveBlock.filesEmptied);
      expect(call(over: true), AssignSaveBlock.overWordLimit);
      expect(call(statementOk: false), AssignSaveBlock.statementNotAccepted);
      expect(call(dirty: false), AssignSaveBlock.noChanges);
    });

    test('同時成立時照宣告順序回第一個', () {
      expect(call(emptied: true, over: true, statementOk: false, dirty: false),
          AssignSaveBlock.filesEmptied);
      expect(call(over: true, statementOk: false, dirty: false),
          AssignSaveBlock.overWordLimit);
      expect(call(statementOk: false, dirty: false),
          AssignSaveBlock.statementNotAccepted);
    });
  });

  group('configOf / pluginEnabled', () {
    test('只認 assignsubmission，assignfeedback 的同名外掛不算', () {
      final a = assignment(configs: [
        cfg('file', 'enabled', '1', subtype: 'assignfeedback'),
        cfg('file', 'maxfilesubmissions', '9', subtype: 'assignfeedback'),
      ]);
      expect(MoodleAssignSubmitUtils.pluginEnabled(a, 'file'), isFalse);
      expect(
          MoodleAssignSubmitUtils.configOf(a,
              plugin: 'file', name: 'maxfilesubmissions'),
          isNull);
    });

    test('configs 為空時全部回預設', () {
      final a = assignment(configs: []);
      expect(MoodleAssignSubmitUtils.pluginEnabled(a, 'file'), isFalse);
      expect(MoodleAssignSubmitUtils.pluginEnabled(a, 'onlinetext'), isFalse);
      expect(MoodleAssignSubmitUtils.maxFiles(a), 1);
      expect(MoodleAssignSubmitUtils.maxBytes(a), 0);
      expect(MoodleAssignSubmitUtils.fileTypes(a), isEmpty);
      expect(MoodleAssignSubmitUtils.wordLimit(a), 0);
    });

    test('fixture 的三個檔案設定都讀得出來', () {
      final a = fixtureSubmittableAssignment();
      expect(MoodleAssignSubmitUtils.maxFiles(a), 3);
      expect(MoodleAssignSubmitUtils.maxBytes(a), 2097152);
      expect(MoodleAssignSubmitUtils.fileTypes(a), ['.pdf', '.docx']);
      expect(MoodleAssignSubmitUtils.wordLimit(a), 500);
    });

    test('wordlimitenabled 為 0 時字數上限是 0', () {
      final a = assignment(configs: [
        cfg('onlinetext', 'enabled', '1'),
        cfg('onlinetext', 'wordlimitenabled', '0'),
        cfg('onlinetext', 'wordlimit', '500'),
      ]);
      expect(MoodleAssignSubmitUtils.wordLimit(a), 0);
    });
  });

  group('countWords', () {
    // 分隔符照 Moodle count_words 的 ~[\p{Z}\p{Cc}—–]+~u：多切一刀就是把交得
    // 出去的作業擋下來。
    test('照空白切，連續空白只算一刀', () {
      expect(MoodleAssignSubmitUtils.countWords('hello world'), 2);
      expect(MoodleAssignSubmitUtils.countWords('  hello   world  '), 2);
      expect(MoodleAssignSubmitUtils.countWords(''), 0);
      expect(MoodleAssignSubmitUtils.countWords('   '), 0);
    });

    test('換行與 tab 也是分隔符', () {
      expect(MoodleAssignSubmitUtils.countWords('a\nb\tc'), 3);
    });

    test('破折號兩側要切開，標點不切', () {
      expect(MoodleAssignSubmitUtils.countWords('long—dash'), 2);
      expect(MoodleAssignSubmitUtils.countWords('a–b'), 2);
      expect(MoodleAssignSubmitUtils.countWords("don't stop"), 2);
    });

    test('不加空白的中文整段算一個字，跟伺服器同一套', () {
      expect(MoodleAssignSubmitUtils.countWords('這是一份作業報告'), 1);
      expect(MoodleAssignSubmitUtils.countWords('第一段 第二段'), 2);
    });
  });

  test('maxBytes 缺席時 exceedsSize 一律 false', () {
    expect(MoodleAssignSubmitUtils.exceedsSize(1 << 30, 0), isFalse);
    expect(MoodleAssignSubmitUtils.exceedsSize(10, 10), isFalse);
    expect(MoodleAssignSubmitUtils.exceedsSize(11, 10), isTrue);
  });

  group('checkFileType', () {
    test('空清單一律放行', () {
      expect(MoodleAssignSubmitUtils.checkFileType('a.exe', const []),
          FileTypeCheck.allowed);
    });

    test('副檔名兩種寫法、大小寫都比得中', () {
      const types = ['.pdf', 'docx'];
      expect(MoodleAssignSubmitUtils.checkFileType('報告.PDF', types),
          FileTypeCheck.allowed);
      expect(MoodleAssignSubmitUtils.checkFileType('a.docx', types),
          FileTypeCheck.allowed);
      expect(MoodleAssignSubmitUtils.checkFileType('a.zip', types),
          FileTypeCheck.rejected);
    });

    test('mime 與 image/* 前綴', () {
      expect(
          MoodleAssignSubmitUtils.checkFileType(
              'a.pdf', const ['application/pdf']),
          FileTypeCheck.allowed);
      expect(MoodleAssignSubmitUtils.checkFileType('a.png', const ['image/*']),
          FileTypeCheck.allowed);
      expect(MoodleAssignSubmitUtils.checkFileType('a.pdf', const ['image/*']),
          FileTypeCheck.rejected);
    });

    test('Moodle 的群組名整份降級成 unverifiable，不擋', () {
      expect(MoodleAssignSubmitUtils.checkFileType('a.exe', const ['document']),
          FileTypeCheck.unverifiable);
      // 混著群組名時，對得中的仍然放行。
      expect(
          MoodleAssignSubmitUtils.checkFileType(
              'a.pdf', const ['document', '.pdf']),
          FileTypeCheck.allowed);
      expect(
          MoodleAssignSubmitUtils.checkFileType(
              'a.exe', const ['document', '.pdf']),
          FileTypeCheck.unverifiable);
    });
  });

  group('duplicateFilename', () {
    AssignDraftFile local(String name) =>
        LocalDraftFile(File('/tmp/$name'), name);

    test('沒有重複回 null', () {
      expect(
          MoodleAssignSubmitUtils.duplicateFilename(
              [local('a.pdf'), local('b.pdf')]),
          isNull);
    });

    test('大小寫視為相同，回第一個重複的名字', () {
      expect(
        MoodleAssignSubmitUtils.duplicateFilename(
            [local('a.pdf'), local('b.pdf'), local('A.PDF')]),
        'A.PDF',
      );
    });
  });

  group('plainToHtml / htmlToPlain', () {
    test('跳脫四個字元', () {
      expect(MoodleAssignSubmitUtils.plainToHtml('a & b < c > d "e"'),
          '<p>a &amp; b &lt; c &gt; d &quot;e&quot;</p>');
    });

    test('空字串回空字串，不可以變成 <p></p>', () {
      expect(MoodleAssignSubmitUtils.plainToHtml(''), '');
    });

    test('空行分段，段內換行用 <br>', () {
      expect(MoodleAssignSubmitUtils.plainToHtml('一\n二\n\n三'),
          '<p>一<br>二</p><p>三</p>');
    });

    test('純文字往返', () {
      for (final text in ['hello', '第一行\n第二行', 'a & b', '一\n二\n\n三']) {
        expect(
            MoodleAssignSubmitUtils.htmlToPlain(
                MoodleAssignSubmitUtils.plainToHtml(text)),
            text,
            reason: text);
      }
    });
  });

  group('onlineTextIsPlain', () {
    test('純 <p>/<br> 可以在 App 內編輯', () {
      expect(
          MoodleAssignSubmitUtils.onlineTextIsPlain('<p>你好<br>再見</p>'), isTrue);
      expect(MoodleAssignSubmitUtils.onlineTextIsPlain(''), isTrue);
    });

    test('內嵌檔案一律不給編輯', () {
      for (final html in [
        '<p><img src="x.png"></p>',
        '<video src="x.mp4"></video>',
        '<audio src="x.mp3"></audio>',
        '<p>@@PLUGINFILE@@/x.png</p>',
        '<p><a href="https://moodle2.ntust.edu.tw/pluginfile.php/1/x">x</a></p>',
      ]) {
        expect(MoodleAssignSubmitUtils.onlineTextIsPlain(html), isFalse,
            reason: html);
      }
    });
  });

  group('fileListChanged', () {
    MoodleAssignFile server(String name) =>
        MoodleAssignFile(filename: name, fileurl: 'https://x/$name');
    AssignDraftFile online(String name) =>
        OnlineDraftFile(name, 'https://x/$name');

    test('完全相同的線上清單 = 沒變', () {
      expect(
          MoodleAssignSubmitUtils.fileListChanged(
              [online('a.pdf'), online('b.pdf')],
              [server('a.pdf'), server('b.pdf')]),
          isFalse);
    });

    test('順序不同也算有變：重排要重傳才會是使用者看到的順序', () {
      expect(
          MoodleAssignSubmitUtils.fileListChanged(
              [online('b.pdf'), online('a.pdf')],
              [server('a.pdf'), server('b.pdf')]),
          isTrue);
    });

    test('名字相同但一邊是本機檔案 = 有變', () {
      expect(
          MoodleAssignSubmitUtils.fileListChanged(
              [LocalDraftFile(File('/tmp/a.pdf'), 'a.pdf')], [server('a.pdf')]),
          isTrue);
    });

    test('長度不同 = 有變', () {
      expect(
          MoodleAssignSubmitUtils.fileListChanged(const [], [server('a.pdf')]),
          isTrue);
    });
  });

  /// 還原 `@@PLUGINFILE@@`。這是**每一次儲存都要跑**的那一支：送出的字串會被
  /// `file_postupdate_standard_editor` 的 `empty($editor['itemid'])` 分支逐字
  /// 寫進資料庫，存錯一次就再也救不回來。
  group('restorePluginfileUrls', () {
    const area = 'https://moodle2.ntust.edu.tw/webservice/pluginfile.php'
        '/555/assignsubmission_onlinetext/submissions_onlinetext/8801';

    MoodleAssignFile inline(String name, String url, {String path = '/'}) =>
        MoodleAssignFile(filename: name, filepath: path, fileurl: url);

    test('絕對網址換回資料庫原本的那個字串', () {
      final files = [inline('a.png', '$area/a.png')];
      expect(
          MoodleAssignSubmitUtils.restorePluginfileUrls(
              '<p><img src="$area/a.png"></p>', files),
          '<p><img src="@@PLUGINFILE@@/a.png"></p>');
    });

    test('PHP rawurlencode 的檔名也認得——只試 encodeComponent 會對不起來', () {
      final files = [
        inline('Lecture (1).png', '$area/Lecture%20%281%29.png'),
      ];
      expect(
          MoodleAssignSubmitUtils.restorePluginfileUrls(
              '<img src="$area/Lecture%20%281%29.png">', files),
          '<img src="@@PLUGINFILE@@/Lecture%20%281%29.png">');
    });

    test('冪等：已經還原過的再跑一次原封不動', () {
      final files = [inline('a.png', '$area/a.png')];
      const restored = '<p><img src="@@PLUGINFILE@@/a.png"></p>';
      expect(MoodleAssignSubmitUtils.restorePluginfileUrls(restored, files),
          restored);
      final once = MoodleAssignSubmitUtils.restorePluginfileUrls(
          '<p><img src="$area/a.png"></p>', files);
      expect(MoodleAssignSubmitUtils.restorePluginfileUrls(once, files), once);
    });

    test('沒有內嵌檔案、空字串、名字對不上時都是原樣回傳', () {
      expect(
          MoodleAssignSubmitUtils.restorePluginfileUrls('<p>純文字</p>', const []),
          '<p>純文字</p>');
      expect(
          MoodleAssignSubmitUtils.restorePluginfileUrls(
              '', [inline('a.png', '$area/a.png')]),
          '');
      expect(
          MoodleAssignSubmitUtils.restorePluginfileUrls(
              '<img src="$area/a.png">', [inline('b.png', '$area/a.png')]),
          '<img src="$area/a.png">');
    });

    test('別的 filearea 的 pluginfile 網址不會被動到', () {
      const other = 'https://moodle2.ntust.edu.tw/webservice/pluginfile.php'
          '/555/mod_resource/content/0/notes.pdf';
      final out = MoodleAssignSubmitUtils.restorePluginfileUrls(
          '<img src="$area/a.png"><a href="$other">講義</a>',
          [inline('a.png', '$area/a.png')]);
      expect(out, '<img src="@@PLUGINFILE@@/a.png"><a href="$other">講義</a>');
    });

    test('一次推導還原同一區的每一個引用', () {
      final files = [
        inline('a.png', '$area/a.png'),
        inline('b.png', '$area/b.png'),
      ];
      expect(
          MoodleAssignSubmitUtils.restorePluginfileUrls(
              '<img src="$area/a.png"><img src="$area/b.png">', files),
          '<img src="@@PLUGINFILE@@/a.png"><img src="@@PLUGINFILE@@/b.png">');
    });

    test('跟討論區那條路是同一個前綴：展開再還原等於沒動過', () {
      const token = '@@PLUGINFILE@@/Lecture%20%281%29.png';
      final forumFiles = [
        MoodleForumFile(
            filename: 'Lecture (1).png',
            filepath: '/',
            url: '$area/Lecture%20%281%29.png'),
      ];
      final displayed =
          MoodleForumUtils.resolveInlinePluginFiles(token, forumFiles);
      expect(displayed, contains(area));
      expect(
          MoodleAssignSubmitUtils.restorePluginfileUrls(displayed, [
            inline('Lecture (1).png', '$area/Lecture%20%281%29.png'),
          ]),
          token);
    });
  });
}
