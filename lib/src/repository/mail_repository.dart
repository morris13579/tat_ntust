import 'package:flutter/foundation.dart';
import 'package:flutter_app/src/model/mail/mail_contact.dart';
import 'package:flutter_app/src/model/mail/mail_content.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/config/mail_config.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/model/mail/mail_outbox_item.dart';
import 'package:flutter_app/src/model/mail/mail_page.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/repository/run.dart';
import 'package:flutter_app/src/store/mail_store.dart';
import 'package:flutter_app/src/store/model.dart';

/// 校內信箱的取資料入口。
///
/// **`requires` 是空集合**：信箱不依賴 SSO 也不依賴 Moodle，它有自己的一組
/// 密碼，而且 IMAP 是每條連線各自 `LOGIN`，沒有跨請求的 session 要維護。
/// 所以 `SystemId` 刻意不新增成員，見 docs/WEBMAIL_IMAP.md §4.2。
/// 走 `run()` 仍然划算：連線探測、進度框、快取回退與重試迴圈都是現成的。
class MailRepository {
  MailRepository();

  static MailRepository instance = MailRepository();

  /// 收件匣的路徑。IMAP 規定它一定叫這個名字，不必先問伺服器。
  static const String inboxPath = MailConfig.inboxPath;

  /// 本機已經有的信，日期新到舊。空清單代表沒快取過。
  ///
  /// 給頁面「先畫再更新」用：先前每次進頁面都空白轉圈等一次連線，四千封的
  /// 信箱那是一秒多的白畫面。
  Future<List<MailMessageJson>> cachedMessages(
          [String folderPath = inboxPath]) =>
      MailStore.instance.readMessages(folderPath);

  Future<List<MailFolderJson>> cachedFolders() =>
      MailStore.instance.readFolders();

  /// 底下這幾個是測試的縫：`MailConnector` 會真的開 socket。
  @visibleForTesting
  Future<List<MailMessageJson>?> fetchFolder(String path) =>
      MailConnector.fetchFolder(path);

  @visibleForTesting
  Future<List<MailFolderJson>?> fetchFolders() => MailConnector.fetchFolders();

  @visibleForTesting

  /// 跨資料夾搜尋。可覆寫給測試用，和 [searchMessages] 同一個角色。
  Future<List<MailMessageJson>?> searchAllMessages(
          List<String> paths, String keyword) =>
      MailConnector.searchFolders(paths, keyword);

  Future<List<MailMessageJson>?> searchMessages(String path, String keyword) =>
      MailConnector.search(path, keyword);

  @visibleForTesting
  Future<MailContent?> fetchContent(int uid, {String folderPath = inboxPath}) =>
      MailConnector.fetchContent(uid, folderPath: folderPath);

  /// 抓一個附件的位元組。失敗回 null。不走 `run()`：進度由呼叫端自己畫，
  /// 附件可能很大，全螢幕遮罩擋著什麼都看不到。
  Future<Uint8List?> fetchAttachment(int uid, String fetchId,
          {String folderPath = inboxPath}) =>
      MailConnector.fetchAttachment(uid, fetchId, folderPath: folderPath);

  @visibleForTesting
  Future<bool> sendDraft(MailDraft draft) => MailConnector.send(draft);

  /// 當場驗一組密碼。密碼對話框存進 Keychain 之前一定要先過這一關。
  Future<MailAuthOutcome> verifyPassword(String account, String password) =>
      MailConnector.verify(account, password);

  /// 標記已讀／未讀。
  ///
  /// **不走 `run()`**：那一層帶的是快取、進度框與重試對話框，而這是一顆旗標，
  /// 失敗就讓下一次重新整理去對齊，不值得為它蓋一次全螢幕遮罩。
  Future<bool> setSeen(int uid,
      {required bool seen, String folderPath = inboxPath}) async {
    if (!await MailConnector.setSeen(uid, seen: seen, folderPath: folderPath)) {
      return false;
    }
    // 本機同步改一列就好，不必整批重寫。
    await MailStore.instance.updateSeen(folderPath, uid, seen: seen);
    return true;
  }

  /// 丟進回收筒。同樣不走 `run()`，理由同 [setSeen]。
  Future<bool> moveToTrash(int uid, {String folderPath = inboxPath}) =>
      _moveToRole(uid, MailFolderRole.trash, folderPath);

  /// 封存。和刪除是同一個動作、只差目標資料夾——刪除是「不想再看到」，封存是
  /// 「看完了但要留著」，兩者都要把信從收件匣移走。
  Future<bool> moveToArchive(int uid, {String folderPath = inboxPath}) =>
      _moveToRole(uid, MailFolderRole.archive, folderPath);

  /// 搬到指定的資料夾。給「移到⋯」那個選單用。
  Future<bool> moveToFolder(int uid, String targetPath,
      {String folderPath = inboxPath}) async {
    if (!await MailConnector.moveToFolder(uid, targetPath,
        folderPath: folderPath)) {
      return false;
    }
    await MailStore.instance.deleteMessage(folderPath, uid);
    return true;
  }

  Future<bool> _moveToRole(
      int uid, MailFolderRole role, String folderPath) async {
    if (!await MailConnector.moveToRole(uid, role, folderPath: folderPath)) {
      return false;
    }
    await MailStore.instance.deleteMessage(folderPath, uid);
    return true;
  }

  /// 再載入一頁（比 [beforeUid] 更舊的信）。
  ///
  /// **不走 `run()`**：捲到底再抓一頁失敗時，該做的是讓那顆「載入更多」變回
  /// 可以再按，不是蓋一層全螢幕遮罩。
  Future<MailPage?> loadMore(String folderPath, int beforeUid) async {
    final page =
        await MailConnector.fetchFolderPage(folderPath, beforeUid: beforeUid);
    if (page == null) return null;
    // **先驗 UIDVALIDITY 再寫。** 它變了代表伺服器把 UID 全部作廢，本機那一
    // 批對應到的已經是別的信；這時候 append 進去等於把兩批不相干的 UID 混在
    // 一起。整個資料夾丟掉重來。
    if (!await _uidValidityMatches(folderPath, page.uidValidity)) return null;
    await MailStore.instance.appendMessages(folderPath, page.messages);
    await rememberSenders(folderPath, page.messages);
    return page;
  }

  /// 快取的 `UIDVALIDITY` 還對得上嗎。對不上就把那個資料夾的快取清掉並記下
  /// 新的值，回 false 讓呼叫端重抓第一頁。
  Future<bool> _uidValidityMatches(String folderPath, int uidValidity) async {
    if (uidValidity == 0) return true; // 問不到就不擋，退回舊行為。
    final cached = await MailStore.instance.readUidValidity(folderPath);
    if (cached == uidValidity) return true;
    if (cached != null) {
      Log.d('mail: $folderPath 的 UIDVALIDITY 從 $cached 變成 $uidValidity，'
          '本機快取整個作廢');
      await MailStore.instance.replaceMessages(folderPath, const []);
    }
    await MailStore.instance.writeUidValidity(folderPath, uidValidity);
    return cached == null;
  }

  /// 比 [afterUid] 新的信。**不走 `run()`**：這是 App 開著時每分鐘一次的檢查，
  /// 失敗就等下一輪，不該為它蓋遮罩或彈重試框。
  Future<List<MailMessageJson>?> fetchNewerThan(int afterUid,
          {String folderPath = inboxPath}) =>
      MailConnector.fetchNewerThan(afterUid, folderPath: folderPath);

  /// 資料夾目前最新的 UID。同樣不走 `run()`，理由同上。
  Future<int?> latestUid({String folderPath = inboxPath}) =>
      MailConnector.latestUid(folderPath: folderPath);

  /// 未讀數。同樣不走 `run()`：拿不到就不顯示，不該為它彈任何東西。
  Future<int?> unreadCount([String folderPath = inboxPath]) =>
      MailConnector.unreadCount(folderPath);

  /// 信箱密碼設定了沒有。UI 要靠它決定先開對話框還是直接載入。
  bool get hasMailPassword => Model.instance.getMailPassword().isNotEmpty;

  /// 一個資料夾裡最近的信。抓到就寫進本機。
  ///
  /// 密碼沒設定時丟 [NotSignedIn]：那是不可重試的，`run()` 不會彈重試框，
  /// 呼叫端該做的是開密碼對話框而不是再試一次。
  ///
  /// **快取回退自己做**，沒有用 `run()` 的 `cache:`：那一層吃的是
  /// `CacheKey`（SharedPreferences 的 JSON blob），而信件存在 SQLite。
  Future<Result<List<MailMessageJson>>> getMessages(
      [String folderPath = inboxPath]) async {
    final result = await run<List<MailMessageJson>>(
      requires: const {},
      errorMessage: R.current.mailLoadFailed,
      debugLabel: 'mail.messages',
      fetch: () async {
        if (!hasMailPassword) throw const TaskFailure(NotSignedIn());
        final fetched = await fetchFolder(folderPath);
        if (fetched != null) {
          await MailStore.instance.replaceMessages(folderPath, fetched);
          await rememberSenders(folderPath, fetched);
        }
        return fetched;
      },
    );
    if (result is! Failed<List<MailMessageJson>>) return result;

    // 抓不到但本機有 → Stale，畫面會標示這是舊資料。
    final cached = await MailStore.instance.readMessages(folderPath);
    if (cached.isEmpty) return result;
    return Stale(cached, result.reason);
  }

  /// 資料夾清單，含每個資料夾的信件數與未讀數。
  ///
  /// **一律重抓。** 資料夾本身一學期變不了幾次，但上面的計數是一直在動的；
  /// 「本機有就不打網路」會讓數字永遠停在第一次抓到的樣子。畫面先用
  /// [cachedFolders] 畫出來，這一趟回來再換掉。
  Future<Result<List<MailFolderJson>>> getFolders() async {
    return run<List<MailFolderJson>>(
      requires: const {},
      errorMessage: R.current.mailLoadFailed,
      debugLabel: 'mail.folders',
      fetch: () async {
        if (!hasMailPassword) throw const TaskFailure(NotSignedIn());
        final fetched = await fetchFolders();
        if (fetched != null) {
          await MailStore.instance.replaceFolders(fetched);
        }
        return fetched;
      },
    );
  }

  /// 搜尋。**刻意不快取**：關鍵字是無限多的，每一組各存一包只會把
  /// SharedPreferences 撐爆，而且搜尋結果過期得比清單還快。
  Future<Result<List<MailMessageJson>>> search(
    String keyword, {
    String folderPath = inboxPath,
    List<String>? allFolderPaths,
  }) =>
      run<List<MailMessageJson>>(
        requires: const {},
        errorMessage: R.current.mailLoadFailed,
        debugLabel: 'mail.search',
        fetch: () {
          if (!hasMailPassword) throw const TaskFailure(NotSignedIn());
          // 給了全部路徑就是「在全部資料夾再找一次」，否則只找目前這一個。
          return allFolderPaths == null
              ? searchMessages(folderPath, keyword)
              : searchAllMessages(allFolderPaths, keyword);
        },
      );

  /// 單封信的內文。
  ///
  /// **刻意不快取**：內文與附件塞不進 `CacheKey` 那種 blob，而每次重抓的代價
  /// 是一次連線。Phase 1 先接受這個取捨，之後要做離線閱讀再開 `MailBodyStore`。
  ///
  /// 也**刻意不丟 `LoginFailed`**：`run()` 看到帶 detail 的 `LoginFailed` 會
  /// 多畫一顆通往 App 登入頁的按鈕，而信箱要的是另一組密碼，那顆按鈕會把
  /// 使用者送去改錯的密碼。
  Future<Result<MailContent>> getContent(int uid,
          {String folderPath = inboxPath}) =>
      run<MailContent>(
        requires: const {},
        errorMessage: R.current.mailBodyLoadFailed,
        debugLabel: 'mail.body',
        fetch: () {
          if (!hasMailPassword) throw const TaskFailure(NotSignedIn());
          return fetchContent(uid, folderPath: folderPath);
        },
      );

  /// 寄出一封信。
  ///
  /// **走 `run()` 而且開進度框**：寄信要連 SMTP、認證、傳附件，在行動網路上
  /// 是好幾秒的事，沒有遮罩使用者會以為沒反應而按第二次——那會真的寄出兩封。
  Future<Result<bool>> send(MailDraft draft) => run<bool>(
        requires: const {},
        progressMessage: R.current.mailSend,
        errorMessage: R.current.mailSendFailed,
        debugLabel: 'mail.send',
        // 失敗回 null 是 connector 的慣例，`run()` 靠它判斷成敗。
        fetch: () async {
          if (!await sendDraft(draft)) return null;
          await rememberRecipients(draft);
          return true;
        },
      );

  /// 寄件匣那一條路上的寄送。**不走 `run()`**：佇列是背景在跑的，替它蓋遮罩
  /// 或彈重試框會打斷使用者當下在做的事。成敗由寄件匣那一列自己講。
  Future<bool> sendQueued(MailDraft draft) async {
    try {
      if (!hasMailPassword) return false;
      if (!await sendDraft(draft)) return false;
      await rememberRecipients(draft);
      return true;
    } catch (e, stack) {
      Log.eWithStack('mail.sendQueued failed: $e', stack);
      return false;
    }
  }

  Future<int> enqueueOutbox(MailDraft draft) =>
      MailStore.instance.enqueueOutbox(draft);

  Future<List<MailOutboxItem>> readOutbox() => MailStore.instance.readOutbox();

  Future<void> updateOutbox(int id, MailOutboxState state,
          {int? attempts, String? lastError}) =>
      MailStore.instance
          .updateOutbox(id, state, attempts: attempts, lastError: lastError);

  Future<void> deleteOutbox(int id) => MailStore.instance.deleteOutbox(id);

  /// 把這一批信的寄件者記進通訊紀錄，給收件者欄的自動完成用。
  ///
  /// **廣告信匣與回收筒不記。** 那兩個資料夾裡的位址正是使用者不想再看到的，
  /// 把它們餵進自動完成等於幫垃圾信排到最前面。
  ///
  /// 角色是從已快取的資料夾清單查的。還沒抓過清單時只認得出 `INBOX`——那兩個
  /// 要排除的資料夾名字在 wire 上是 modified UTF-7，拿 `mailFolderRole` 去比
  /// 對不上。那是開 App 第一趟的事，而第一趟開的就是收件匣。
  @visibleForTesting
  Future<void> rememberSenders(
      String folderPath, List<MailMessageJson> messages) async {
    final role = await _roleOf(folderPath);
    if (role == MailFolderRole.junk || role == MailFolderRole.trash) return;
    // 寄件備份匣裡的寄件者是自己，記下來只會讓使用者在收件者欄看到自己。
    if (role == MailFolderRole.sent || role == MailFolderRole.drafts) return;

    final contacts = <MailContact>[];
    for (final m in messages) {
      if (m.fromEmail.isEmpty) continue;
      contacts.add(MailContact(
        email: m.fromEmail,
        name: m.fromName,
        lastSeenMillis: m.dateMillis,
      ));
    }
    await MailStore.instance.rememberContacts(contacts);
  }

  /// 寄成功之後把收件者記下來，`sentCount` 加一。
  ///
  /// **密件副本也記。** 那是使用者自己打進去的人，不記的話下一次還要再打一遍；
  /// 通訊紀錄只存在本機，不會因此洩漏給別的收件者。
  @visibleForTesting
  Future<void> rememberRecipients(MailDraft draft) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await MailStore.instance.rememberContacts([
      for (final a in [...draft.to, ...draft.cc, ...draft.bcc])
        if (a.trim().isNotEmpty)
          MailContact(email: a, lastSeenMillis: now, sentCount: 1),
    ]);
  }

  /// 收件者欄的自動完成。關鍵字是空的就不給建議——一進寫信頁就掉出一串人名
  /// 是噪音，使用者多半已經知道要寄給誰。
  Future<List<MailContact>> suggestContacts(String query) async {
    if (query.trim().isEmpty) return const [];
    return MailStore.instance.searchContacts(query);
  }

  Future<MailFolderRole?> _roleOf(String folderPath) async {
    final cached = await MailStore.instance.readFolders();
    for (final f in cached) {
      if (f.path == folderPath) return f.role;
    }
    return mailFolderRole(folderPath);
  }
}
