import 'package:flutter_app/src/controller/announcement/announcement_center_controller.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/repository/result.dart';

/// 通知頁的假資料，只給開發者選單的預覽用：Flutter 的 `AnnouncementCenterPreviewPage` 與原生版
/// 共用這一份。假資料**不會**流到正式流程：只有預覽會把它塞進 controller。

/// 預覽選單上的順序。
const announcementPreviewMenu = [
  AnnouncementPreviewCase.withNotice,
  AnnouncementPreviewCase.moodleOnly,
  AnnouncementPreviewCase.empty,
  AnnouncementPreviewCase.disabledOnMoodle,
  AnnouncementPreviewCase.multipleNotices,
  AnnouncementPreviewCase.variants,
];

/// 開發用的項目，字串刻意不進翻譯檔（同 `DevPage`）。標題就用設計稿的
/// 檔名，對照設計稿時不用再翻譯一次。
extension AnnouncementPreviewCaseText on AnnouncementPreviewCase {
  String get title => switch (this) {
        AnnouncementPreviewCase.withNotice => '通知 有公告',
        AnnouncementPreviewCase.moodleOnly => '通知 只有 Moodle',
        AnnouncementPreviewCase.empty => '通知 全空',
        AnnouncementPreviewCase.disabledOnMoodle => '通知 全空（在 Moodle 關掉）',
        AnnouncementPreviewCase.multipleNotices => '通知 多則 TAT 公告',
        AnnouncementPreviewCase.variants => '通知 各種類型',
      };

  String get subtitle => switch (this) {
        AnnouncementPreviewCase.withNotice => 'TAT 公告卡 + Moodle 通知',
        AnnouncementPreviewCase.moodleOnly => '沒有 TAT 公告，清單從第一個分組開始',
        AnnouncementPreviewCase.empty => '空狀態，要置中',
        AnnouncementPreviewCase.disabledOnMoodle => '空清單但未讀數不是 0，第二行說明不一樣',
        AnnouncementPreviewCase.multipleNotices =>
          '卡片仍然只畫最新的一則，其餘在「看完整公告」裡翻頁',
        AnnouncementPreviewCase.variants => '設計稿沒畫的分支：其餘圖示、就地展開、長標題、跨年日期',
      };
}

enum AnnouncementPreviewCase {
  withNotice,
  multipleNotices,
  moodleOnly,
  empty,
  disabledOnMoodle,
  variants
}

/// 只在記憶體裡動的 controller。每一個會打網路或寫紅點的方法都覆寫掉：
/// 預覽的重點是版面，不是讓假資料跑進快取或未讀數。
class AnnouncementCenterPreviewController extends AnnouncementCenterController {
  AnnouncementCenterPreviewController(AnnouncementPreviewCase which) {
    appNotices.value = Ok(_noticesOf(which));
    notifications.value = Ok(_notificationsOf(which));
  }

  @override
  Future<void> loadAppNotices() async {}

  @override
  Future<void> loadNotifications({bool background = true}) async {}

  @override
  Future<void> refreshAll() async {}

  @override
  Future<void> markRead(MoodleNotification n) async {
    final list = notifications.value?.dataOrNull;
    if (list == null || n.read) return;
    n.read = true;
    n.timeread = announcementPreviewNow.millisecondsSinceEpoch ~/ 1000;
    list.unreadcount = (list.unreadcount - 1).clamp(0, 1 << 31);
    // Ok 沒有覆寫 ==，Rxn 只在指派新實例時通知。
    notifications.value = Ok(list);
  }

  @override
  Future<bool> markAllRead() async {
    final list = notifications.value?.dataOrNull;
    if (list == null) return false;
    for (final n in list.notifications) {
      n.read = true;
      n.timeread = announcementPreviewNow.millisecondsSinceEpoch ~/ 1000;
    }
    list.unreadcount = 0;
    notifications.value = Ok(list);
    return true;
  }
}

/// 預覽用的「現在」。固定成 2025/9/5（星期五）而不是真的今天：分組是
/// 今天／本週／更早三個桶，時刻寫死配上真的今天，星期一跑預覽時整批會掉進
/// 「更早」，那就看不到設計稿上的三個小標了。底下每一列的時間也一起寫死，
/// 兩者相對關係固定，預覽才不會今天長一個樣、明天長另一個樣。這個時間同時
/// 注入頁面的 `clock`，畫面上的時間欄與分組才是同一個時間點算出來的。
final DateTime announcementPreviewNow = DateTime(2025, 9, 5, 15, 30);

const String _previewHost = 'https://moodle2.ntust.edu.tw';

/// TAT 公告。時間刻意不照順序寫，才看得出畫面上那一則是 `sortForList` 挑的
/// 最新一則，而不是清單的第一筆。
///
/// RemoteConfigUtils 把公告時間重建成 UTC 欄位裝台北的牆上時間，假資料照同一
/// 套寫，日期才不會在預覽裡位移八小時。
List<AnnouncementInfoJson> _noticesOf(AnnouncementPreviewCase which) => switch (which) {
      AnnouncementPreviewCase.withNotice => [_release350],
      AnnouncementPreviewCase.multipleNotices => [_maintenance, _release350, _survey],
      _ => const [],
    };

final _release350 = AnnouncementInfoJson(
  title: '3.5.0 更新：課表可以分享了',
  content: '這一版可以用 QR 把課表給同學，也可以掃別人的。\n\n'
      '- 修掉成績頁展開後看不到回饋的問題\n'
      '- 通知改成依時間分組\n',
  startTime: DateTime.utc(2025, 9, 1, 9, 0),
  endTime: DateTime.utc(2025, 10, 1, 9, 0),
  test: true,
);

final _maintenance = AnnouncementInfoJson(
  title: '9/6 校務系統維護，成績與課表可能讀不到',
  content: '學校 9/6 02:00–06:00 維護校務系統。\n\n'
      '這段時間成績、課表與選課資訊都會讀不到，維護結束後就會恢復，'
      '不需要重新登入。\n',
  startTime: DateTime.utc(2025, 9, 3, 20, 0),
  endTime: DateTime.utc(2025, 9, 10, 9, 0),
  test: true,
);

final _survey = AnnouncementInfoJson(
  title: '想要哪些功能？填個問卷告訴我們',
  content: 'TAT 是學生自己維護的，接下來要做什麼由大家決定。\n\n'
      '問卷大概兩分鐘，選項裡有課表小工具、課程評價與行事曆匯出。\n',
  startTime: DateTime.utc(2025, 8, 20, 12, 0),
  endTime: DateTime.utc(2025, 9, 20, 12, 0),
  test: true,
);

MoodleNotificationList _notificationsOf(AnnouncementPreviewCase which) {
  switch (which) {
    case AnnouncementPreviewCase.withNotice:
    case AnnouncementPreviewCase.multipleNotices:
    case AnnouncementPreviewCase.moodleOnly:
      return _listOf(_designNotifications());
    case AnnouncementPreviewCase.variants:
      return _listOf(_variantNotifications());
    case AnnouncementPreviewCase.empty:
      return MoodleNotificationList(
          notifications: <MoodleNotification>[], unreadcount: 0);
    case AnnouncementPreviewCase.disabledOnMoodle:
      // 清單空但未讀數不是 0，正是伺服器在使用者關掉站內通知時回的樣子
      // （`MoodleNotificationUtils.looksDisabledByUser`）。
      return MoodleNotificationList(
          notifications: <MoodleNotification>[], unreadcount: 3);
  }
}

/// 未讀數由清單自己算，改假資料時不必再同步一個手寫的數字。
MoodleNotificationList _listOf(List<MoodleNotification> items) =>
    MoodleNotificationList(
      notifications: items,
      unreadcount: items.where((n) => !n.read).length,
    );

/// 設計稿「通知 有公告 / 只有 Moodle」那兩張畫面上的七列，標題、來源與日期
/// 逐列照抄，所以這兩個項目可以跟設計稿並排比對。
///
/// 未讀是前兩列：設計稿用 15px 的字重 500／400 分未讀已讀，那兩列是 500。
/// component 與 eventtype 是回推的——設計稿畫的是圖示，圖示在程式裡由
/// `NotificationTile.iconFor` 從這兩個欄位算出來。
List<MoodleNotification> _designNotifications() => [
      _previewNotification(
        id: 9001,
        subject: 'Quiz 3 成績已公布',
        body: '各位同學好，Quiz 3 的成績已經上傳，請自行到成績頁查看。'
            '對分數有疑問請於一週內來信助教。',
        created: DateTime(2025, 9, 5, 14, 20),
        source: '機率與統計',
        url: '$_previewHost/mod/forum/discuss.php?d=41208',
        component: 'mod_forum',
      ),
      _previewNotification(
        id: 9002,
        subject: 'HW4 明天 23:59 截止',
        body: '作業「HW4」將於 9月6日 23:59 截止繳交。',
        created: DateTime(2025, 9, 5, 9, 5),
        source: '計算機組織',
        url: '$_previewHost/mod/assign/view.php?id=77004',
        component: 'mod_assign',
      ),
      _previewNotification(
        id: 9003,
        subject: 'HW3 已評分 · 92',
        body: '助教已完成評分並留下回饋。',
        created: DateTime(2025, 9, 4, 16, 40),
        source: '機率與統計',
        url: '$_previewHost/grade/report/user/index.php?id=1421',
        component: 'moodle',
        eventtype: 'gradenotification',
        read: true,
      ),
      _previewNotification(
        id: 9004,
        subject: '5/2 以看錄影方式上課！',
        body: '本週因教師出差改為觀看錄影，請於週日前看完並回覆討論區。',
        created: DateTime(2025, 9, 3, 10, 12),
        source: '計算機組織',
        url: '$_previewHost/mod/forum/discuss.php?d=41103',
        component: 'mod_forum',
        read: true,
      ),
      _previewNotification(
        id: 9005,
        subject: 'Project 4 已開放繳交',
        body: '期末專題「Project 4」已開放繳交，請於 10月15日 前上傳報告與原始碼。',
        created: DateTime(2025, 9, 2, 8, 30),
        source: '計算機組織',
        url: '$_previewHost/mod/assign/view.php?id=77102',
        component: 'mod_assign',
        read: true,
      ),
      _previewNotification(
        id: 9006,
        subject: 'Q2 已評分 · 82',
        body: '你在「Q2」的成績已經公布。',
        created: DateTime(2025, 8, 28, 11, 5),
        source: '機率與統計',
        url: '$_previewHost/grade/report/user/index.php?id=1421',
        component: 'moodle',
        eventtype: 'gradenotification',
        read: true,
      ),
      _previewNotification(
        id: 9007,
        subject: 'Quiz 1 公告',
        body: 'Quiz 1 於下週三第一節考，範圍到第 3 章，可帶一張 A4 手寫大抄。',
        created: DateTime(2025, 8, 19, 13, 0),
        source: '計算機組織',
        url: '$_previewHost/mod/forum/discuss.php?d=40877',
        component: 'mod_forum',
        read: true,
      ),
    ];

/// 設計稿只畫了三種圖示與清一色可開啟的列，但 `NotificationTile` 的分支比那
/// 多。這幾列各自踩一個設計稿上看不到的分支，另外開一個項目而不是混進上面
/// 那七列，是為了讓上面兩張畫面還能逐列對照設計稿。
List<MoodleNotification> _variantNotifications() => [
      // 標題兩行還是放不下（`maxLines: 2` 截斷），來源也長到要 ellipsis——
      // 活動名稱是老師打的，長度沒有上限。
      _previewNotification(
        id: 9101,
        subject: '期中考考場與座位表已公布，請於考前確認教室、座位號碼與應試注意事項，逾時不得入場',
        body: '座位表請見附件，考試當天請攜帶學生證。',
        created: DateTime(2025, 9, 5, 13, 5),
        source: '微積分（甲）一 A 班（含遠距同步班）',
        url: '$_previewHost/mod/quiz/view.php?id=78210',
        component: 'mod_quiz',
      ),
      _previewNotification(
        id: 9102,
        subject: '教學意見調查已開放填答，填完才能查詢本學期成績',
        body: '請於 1月10日 前完成本學期所有課程的教學意見調查。',
        created: DateTime(2025, 9, 5, 11, 40),
        source: '課務組',
        url: '$_previewHost/mod/feedback/view.php?id=79001',
        component: 'mod_feedback',
      ),
      _previewNotification(
        id: 9103,
        subject: '第 2 章 線上教材已開放',
        body: '請在下次上課前看完第 2 章的互動教材。',
        created: DateTime(2025, 9, 4, 9, 0),
        source: '線性代數',
        url: '$_previewHost/mod/lesson/view.php?id=76540',
        component: 'mod_lesson',
        read: true,
      ),
      // 沒有專屬圖示的模組走 puzzle。
      _previewNotification(
        id: 9104,
        subject: '共筆頁面已更新',
        body: '有同學更新了「第 3 週 共筆」。',
        created: DateTime(2025, 9, 3, 21, 15),
        source: '演算法',
        url: '$_previewHost/mod/wiki/view.php?id=75330',
        component: 'mod_wiki',
        read: true,
      ),
      // 沒有 contexturl，也沒有來源名稱：點下去就地展開，來源欄顯示未知來源。
      _previewNotification(
        id: 9105,
        subject: '系統維護：9/7 02:00–06:00 暫停服務',
        body: '維護期間無法登入或繳交作業，造成不便敬請見諒。',
        created: DateTime(2025, 9, 2, 18, 0),
        component: 'moodle',
        read: true,
      ),
      // contexturl 指到外站：`MoodleNotificationUtils.openUrlOf` 只認自家
      // https 站台，所以這一列一樣是就地展開，不是開網頁。
      _previewNotification(
        id: 9106,
        subject: '課程問卷（Google 表單）',
        body: '請填寫本週的課堂回饋：https://docs.google.com/forms/d/e/1FAIpQLSc/viewform',
        created: DateTime(2025, 8, 27, 10, 0),
        source: '計算機組織',
        url: 'https://docs.google.com/forms/d/e/1FAIpQLSc/viewform',
        component: 'mod_forum',
        read: true,
      ),
      // 跨年的那一列：時間欄從「9月4日」變成帶年份的長格式。
      _previewNotification(
        id: 9107,
        subject: '113-1 選課結果已公布',
        body: '初選結果已公布，請至選課系統確認。',
        created: DateTime(2024, 12, 20, 9, 0),
        source: '教務處',
        url: '$_previewHost/my/',
        component: 'moodle',
        read: true,
      ),
    ];

/// [url] 留空或指到外站就是「沒有可以開的位址」那一種：那一列點下去是就地展開。
MoodleNotification _previewNotification({
  required int id,
  required String subject,
  required String body,
  required DateTime created,
  String? source,
  String? url,
  String? component,
  String? eventtype,
  bool read = false,
}) {
  final seconds = created.millisecondsSinceEpoch ~/ 1000;
  return MoodleNotification(
    id: id,
    subject: subject,
    text: '<p>$body</p>',
    fullmessage: body,
    fullmessagehtml: '<p>$body</p>',
    smallmessage: body,
    contexturl: url,
    contexturlname: source,
    timecreated: seconds,
    timeread: read ? seconds : null,
    read: read,
    component: component,
    eventtype: eventtype,
  );
}
