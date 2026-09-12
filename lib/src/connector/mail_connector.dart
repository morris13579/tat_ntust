import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/config/mail_config.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_content.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_page.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/mail_text_decoder.dart';
import 'package:flutter_app/src/util/html_style_inliner.dart';

/// 驗證信箱密碼的結果。
///
/// 「密碼錯」與「連不上」一定要分開：兩者的訊息不同，而且只有前者該把使用者
/// 留在密碼對話框裡重打。
enum MailAuthOutcome { ok, rejected, unreachable }

/// 校內信箱（Mail2000）的 IMAP 出口。
///
/// **這是 App 的第二種對外連線**：走 raw `SecureSocket`，不經過 `DioConnector`
/// 的單一 Dio、cookie jar、`RedactingLogInterceptor`，Alice 也攔不到它。
/// 見 docs/WEBMAIL_IMAP.md。
///
/// 三條安全規則，改動時不要繞過：
/// 1. `ImapClient` 的 `isLogEnabled` 保持預設 `false`。開啟會把整段對話
///    （含 `LOGIN <帳號> <密碼>`）印到 stdout。
/// 2. **不設 `onBadCertificate`**。憑證是有效的正式憑證，任何「先放行方便
///    測試」的程式碼都不該進版控。
/// 3. 密碼只在 [_open] 那一刻讀出來，不留成欄位。
class MailConnector {
  MailConnector._();

  /// 開一條登入好的 IMAP 連線。呼叫端負責 `logout()`。
  ///
  /// 連線失敗會讓例外逸出（多半是 `SocketException` / `TimeoutException`），
  /// 帳密被拒則是 `ImapException`——兩者由呼叫端分開處理。
  static Future<ImapClient> _open(String account, String password) async {
    // **一定要給 defaultResponseTimeout / defaultWriteTimeout。**
    // connectToServer 的 timeout 只蓋 TCP + TLS 握手；沒有這兩個，login 之後
    // 的每一條指令都是無限期等待，而伺服器踢連線時 enough_mail 不會讓等待中
    // 的 future 失敗。詳見 MailConfig.responseTimeout。
    final client = ImapClient(
      defaultResponseTimeout: MailConfig.responseTimeout,
      defaultWriteTimeout: MailConfig.writeTimeout,
    );
    await client.connectToServer(
      MailConfig.host,
      MailConfig.imapPort,
      isSecure: true,
      timeout: MailConfig.connectTimeout,
    );
    await client.login(account, password);
    return client;
  }

  /// 用目前存著的憑證開一條連線。信箱密碼沒設定時回 null。
  static Future<ImapClient?> _openWithStoredCredentials() async {
    final password = Model.instance.getMailPassword();
    if (password.isEmpty) return null;
    return _open(Model.instance.getAccount(), password);
  }

  /// 當場驗一組密碼對不對。
  ///
  /// 存密碼之前一定要先過這一關：舊的 WebMail 對話框是不驗證就存，使用者要
  /// 等到下一次收信失敗才知道打錯了。
  static Future<MailAuthOutcome> verify(String account, String password) async {
    ImapClient? client;
    try {
      client = await _open(account, password);
      return MailAuthOutcome.ok;
    } on ImapException catch (e) {
      // 連線本身成功了才會走到 login，所以這裡的失敗就是帳密被拒。
      // e.message 可能帶伺服器原文，但不要往上傳——它會進 log。
      Log.d("mail verify rejected: ${e.message}");
      return MailAuthOutcome.rejected;
    } catch (e) {
      Log.d("mail verify unreachable: $e");
      return MailAuthOutcome.unreachable;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 伺服器上所有的資料夾。失敗回 null。
  static Future<List<MailFolderJson>?> fetchFolders() async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      final boxes = await client.listMailboxes();
      final folders = <MailFolderJson>[];
      for (final box in boxes) {
        // `STATUS` 是一個資料夾一次往返。實測 `SEARCH ALL` 只要 0.1 秒，
        // STATUS 更輕，十來個資料夾的成本可以接受。任何一個失敗都只讓那一個
        // 沒有數字，不要讓整份清單掛掉。
        var messages = -1;
        var unseen = -1;
        try {
          final status = await client
              .statusMailbox(box, [StatusFlags.messages, StatusFlags.unseen]);
          messages = status.messagesExists;
          unseen = status.messagesUnseen;
        } catch (e) {
          Log.d('mail status failed for ${box.path}: $e');
        }
        folders.add(MailFolderJson(
          // **存 wire 上的 modified UTF-7，不是解碼後的中文。**
          // selectMailboxByPath() 把參數直接當成 encodedPath 用（它不編碼），
          // 而 box.path 是解碼後的。存錯這一個，每一個中文資料夾都會
          // `NO SELECT can't open mailbox`——實測收件匣以外全中。
          // COPY / APPEND 反過來：那兩個 API 會自己編一次，所以要餵解碼值，
          // 見 moveToRole 與 _appendToSent。
          path: box.encodedPath,
          name: box.name,
          role: mailFolderRole(box.name),
          messageCount: messages,
          unreadCount: unseen,
        ));
      }
      return folders..sort((a, b) => a.role.index.compareTo(b.role.index));
    } catch (e, stack) {
      Log.eWithStack("mail fetchFolders failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 在指定資料夾裡搜尋主旨或寄件者。
  ///
  /// **不走伺服器端 `SEARCH`**，改成抓最新 [MailConfig.searchWindow] 封
  /// envelope 回本機篩。理由與實測數字見 [MailConfig.searchWindow]：這台
  /// Mail2000 的 `SEARCH SUBJECT` 要 69 秒，跑到一半連線就被伺服器以
  /// `auto logout; idle for too long` 踢掉，搜尋永遠不會回來。
  static Future<List<MailMessageJson>?> search(
    String folderPath,
    String keyword,
  ) async {
    final needle = keyword.trim().toLowerCase();
    if (needle.isEmpty) return fetchFolder(folderPath);

    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      final box = await client.selectMailboxByPath(folderPath);
      final total = box.messagesExists;
      if (total == 0) return const [];

      final start = max(1, total - MailConfig.searchWindow + 1);
      final result = await client.fetchMessages(
        MessageSequence.fromRange(start, total),
        "(UID ENVELOPE FLAGS)",
      );
      return sortedByDate(result.messages)
          .where((m) => matchesKeyword(m, needle))
          .toList();
    } catch (e, stack) {
      Log.eWithStack("mail search failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 一頁信。[beforeUid] 是游標——只回比它更舊的那些；null 代表第一頁。
  ///
  /// **游標用 UID，不用序號。** 序號會因為 `EXPUNGE` 整批位移，直接拿序號當
  /// 游標，第二頁會把已經顯示過的信再送一次。
  ///
  /// **但不要每頁都 `SEARCH ALL`。** 那是整個信箱的成本——四千多封就回四千多
  /// 個 UID（約 26 KB）要穿過網路再解析，而且每一頁重來一次，信箱越大越慢。
  /// 這裡真正需要的只有一個數字：游標那一封排第幾。`UID FETCH` 的回應行
  /// （`* <序號> FETCH (UID …)`）本身就帶序號，問一封信就夠；換算出來之後照
  /// 序號抓連續一段，和第一頁（[fetchFolder]）同一條路、同一個 fetch spec。
  static Future<MailPage?> fetchFolderPage(
    String folderPath, {
    int? beforeUid,
    int limit = MailConfig.pageSize,
  }) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      final box = await client.selectMailboxByPath(folderPath);
      final uidValidity = box.uidValidity ?? 0;
      final total = box.messagesExists;
      final end = total == 0
          ? 0
          : (beforeUid == null
              ? total
              : await _sequenceBefore(client, beforeUid));
      if (end < 1) {
        return MailPage(
            messages: const [], hasMore: false, uidValidity: uidValidity);
      }

      final start = pageStart(end, limit);
      final result = await client.fetchMessages(
        MessageSequence.fromRange(start, end),
        "(UID ENVELOPE FLAGS)",
      );
      return MailPage(
        // **再用游標濾一次。** 序號是這一秒的快照；中途有人把比游標更舊的信
        // `EXPUNGE` 掉時，邊界會多含到一封已經在清單裡的。清單那一列的 key 是
        // `mail-<uid>`，重複一個就是 Duplicate keys found 的紅畫面。
        messages: sortedByDate(result.messages)
            .where((m) => beforeUid == null || m.uid < beforeUid)
            .toList(),
        // 由伺服器那一端算，不要讓 UI 拿「不足 limit」去猜。
        hasMore: start > 1,
        uidValidity: uidValidity,
      );
    } catch (e, stack) {
      Log.eWithStack("mail fetchFolderPage failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 一頁的起點序號（1 起算）。**純函式，測試直接打這裡。**
  @visibleForTesting
  static int pageStart(int end, int limit) => end > limit ? end - limit + 1 : 1;

  /// 游標那一封的**前一個**序號；沒有更舊的回 0。
  ///
  /// 序號就寫在 `UID FETCH` 的回應行上，所以一封信就問得到。只有游標那封剛好
  /// 被別的裝置刪掉時才退回 `SEARCH`，而且範圍鎖在比它舊的那一段（回應是一行
  /// 數字），不是整個信箱。
  static Future<int> _sequenceBefore(ImapClient client, int beforeUid) async {
    if (beforeUid <= 1) return 0;
    final anchor = await client.uidFetchMessage(beforeUid, '(UID)');
    final id =
        anchor.messages.isEmpty ? null : anchor.messages.first.sequenceId;
    if (id != null) return id - 1;
    final search = await client.uidSearchMessages(
        searchCriteria: 'UID 1:${beforeUid - 1}');
    return search.matchingSequence?.toList().length ?? 0;
  }

  /// 資料夾裡比 [afterUid] 新的信。沒有新的回空清單，失敗回 null。
  ///
  /// 給「App 開著的時候看有沒有新信」用，所以要盡量便宜：`SELECT` 就會回
  /// `UIDNEXT`，只要它不比 [afterUid] 大就直接收工，一次 FETCH 都不用發。
  /// 實測一輪 connect + LOGIN + SELECT + 收工是 0.3 秒。
  ///
  /// **`UID n:*` 一定至少回一封。** IMAP 的規矩是這個範圍查不到東西時會回
  /// 最後一封，所以拿回來一定要再用 [afterUid] 濾一次，否則每一輪都會把同
  /// 一封舊信當成新的。
  static Future<List<MailMessageJson>?> fetchNewerThan(
    int afterUid, {
    String folderPath = MailConfig.inboxPath,
  }) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      final box = await client.selectMailboxByPath(folderPath);
      if (box.messagesExists == 0) return const [];
      final uidNext = box.uidNext;
      if (uidNext != null && uidNext <= afterUid + 1) return const [];

      final result = await client.uidFetchMessages(
        MessageSequence.fromRangeToLast(afterUid + 1, isUidSequence: true),
        "(UID ENVELOPE FLAGS)",
      );
      return sortedByDate(result.messages)
          .where((m) => m.uid > afterUid)
          .toList();
    } catch (e, stack) {
      Log.eWithStack("mail fetchNewerThan($afterUid) failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 資料夾目前最新的 UID，抓不到回 null。
  ///
  /// 開始盯之前先問一次，才不會把使用者信箱裡本來就有的四千封當成「剛到的」
  /// 全部彈出來。
  static Future<int?> latestUid({
    String folderPath = MailConfig.inboxPath,
  }) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      final box = await client.selectMailboxByPath(folderPath);
      final uidNext = box.uidNext;
      // UIDNEXT 是「下一封會拿到的號碼」，所以現有最大的是它減一。空資料夾
      // 也適用：UIDNEXT 1 代表最大 UID 是 0，而 0 不是合法 UID。
      if (uidNext != null) return uidNext - 1;
      if (box.messagesExists == 0) return 0;
      // 沒回 UIDNEXT 的話退回去問最後一封的 UID。
      final result = await client.fetchMessages(
        MessageSequence.fromRangeToLast(box.messagesExists),
        "(UID)",
      );
      return result.messages.isEmpty ? 0 : result.messages.last.uid ?? 0;
    } catch (e, stack) {
      Log.eWithStack("mail latestUid failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 在多個資料夾裡搜尋，結果照日期合併成一份。
  ///
  /// **一條連線掃完所有資料夾。** 每個資料夾各開一次連線的話，光是 TLS 交握
  /// 加登入就是七輪往返——而實測七個資料夾裡六個是空的，真正的工作量遠小於
  /// 建立連線的成本。
  ///
  /// 任何一個資料夾失敗只讓那一個沒有結果，其餘照樣回；全部都失敗才回 null。
  static Future<List<MailMessageJson>?> searchFolders(
    List<String> folderPaths,
    String keyword,
  ) async {
    final needle = keyword.trim().toLowerCase();
    if (needle.isEmpty || folderPaths.isEmpty) return const [];

    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;

      final hits = <MailMessageJson>[];
      var anySucceeded = false;
      for (final path in folderPaths) {
        try {
          final box = await client.selectMailboxByPath(path);
          anySucceeded = true;
          final total = box.messagesExists;
          if (total == 0) continue;
          final start = max(1, total - MailConfig.searchWindow + 1);
          final result = await client.fetchMessages(
            MessageSequence.fromRange(start, total),
            "(UID ENVELOPE FLAGS)",
          );
          hits.addAll(sortedByDate(result.messages)
              .where((m) => matchesKeyword(m, needle)));
        } catch (e) {
          Log.d('mail searchFolders: $path 失敗，跳過：$e');
        }
      }
      if (!anySucceeded) return null;
      // 跨資料夾之後 UID 不再唯一，排序只靠日期。
      hits.sort((a, b) => b.dateMillis.compareTo(a.dateMillis));
      return hits;
    } catch (e, stack) {
      Log.eWithStack("mail searchFolders failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 一封信符不符合關鍵字。**純函式，測試直接打這裡。**
  ///
  /// [needle] 必須已經 trim 過並轉小寫，這裡不重複做——它會被呼叫幾百次。
  /// 只比主旨與寄件者，不比內文：內文不在 envelope 裡，要比就得把每封信整封
  /// 抓下來。
  static bool matchesKeyword(MailMessageJson message, String needle) =>
      message.subject.toLowerCase().contains(needle) ||
      message.fromName.toLowerCase().contains(needle) ||
      message.fromEmail.toLowerCase().contains(needle);

  /// 某個資料夾裡未讀的數量。失敗回 null。
  static Future<int?> unreadCount(String folderPath) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      await client.selectMailboxByPath(folderPath);
      final result = await client.uidSearchMessages(searchCriteria: 'UNSEEN');
      return result.matchingSequence?.toList().length ?? 0;
    } catch (e, stack) {
      Log.eWithStack("mail unreadCount failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 指定資料夾最近 [MailConfig.inboxFetchLimit] 封的 envelope。
  ///
  /// 失敗回 null（connector 的慣例）。空資料夾回空清單，那是合法結果。
  static Future<List<MailMessageJson>?> fetchFolder(String folderPath) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      final box = await client.selectMailboxByPath(folderPath);
      final total = box.messagesExists;
      if (total == 0) return const [];

      // 伺服器沒有 SORT，只能自己抓一段回來排。取序號最大的那一段＝最新的。
      final start = max(1, total - MailConfig.inboxFetchLimit + 1);
      final result = await client.fetchMessages(
        MessageSequence.fromRange(start, total),
        "(UID ENVELOPE FLAGS)",
      );
      return sortedByDate(result.messages);
    } catch (e, stack) {
      Log.eWithStack("mail fetchFolder failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 伺服器沒有 `SORT`，排序一律在本機做。**純函式，測試直接打這裡。**
  static List<MailMessageJson> sortedByDate(List<MimeMessage> messages) =>
      messages.map(toMessageJson).toList()
        ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis));

  /// 抓一個附件的位元組。失敗回 null。
  ///
  /// 用 `BODY[fetchId]` 只抓那一個 part，不必把整封信（可能幾十 MB）重抓一次。
  static Future<Uint8List?> fetchAttachment(int uid, String fetchId,
      {String folderPath = MailConfig.inboxPath}) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      // **不可以寫死 selectInbox()。** UID 只在資料夾內唯一，在回收筒點一封
      // 信卻去收件匣抓同一個 UID，不是「讀取內文失敗」就是顯示到另一封信。
      await client.selectMailboxByPath(folderPath);
      final result = await client.uidFetchMessage(uid, 'BODY[$fetchId]');
      if (result.messages.isEmpty) return null;
      return result.messages.first.decodeContentBinary();
    } catch (e, stack) {
      Log.eWithStack("mail fetchAttachment($uid, $fetchId) failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 一封信的可顯示內容：內文 HTML 加附件清單。失敗回 null。
  ///
  /// 兩者都來自同一次 `BODY[]`，拆成兩個方法會變成把整封信抓兩次。
  static Future<MailContent?> fetchContent(int uid,
      {String folderPath = MailConfig.inboxPath}) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      // **不可以寫死 selectInbox()。** UID 只在資料夾內唯一，在回收筒點一封
      // 信卻去收件匣抓同一個 UID，不是「讀取內文失敗」就是顯示到另一封信。
      await client.selectMailboxByPath(folderPath);
      final result = await client.uidFetchMessage(uid, "BODY[]");
      if (result.messages.isEmpty) return null;
      final message = result.messages.first;

      final html = decodeBestTextPart(message, 'text/html');
      final body = html != null
          ? inlineCidImages(message, HtmlStyleInliner.inline(html))
          : plainTextToHtml(decodeBestTextPart(message, 'text/plain') ?? '');

      return MailContent(html: body, attachments: attachmentsOf(message));
    } catch (e, stack) {
      Log.eWithStack("mail fetchContent($uid) failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 內文的 part：**前序走訪、取第一個符合的**。

  /// **不可以用「最後一個符合的」。** `allPartsFlat` 是整棵樹的展開，裡面
  /// 除了內文，還有附件、以及夾帶信件（`message/rfc822`）自己的內文 part，
  /// 而那些通常排在真正的內文**後面**。Google Meet 的邀請信正是這個形狀
  /// （multipart/mixed 包 multipart/alternative 再夾一個 text/calendar），
  /// 取最後一個就會挑到夾帶物裡的 part，畫面上看起來就是「內文不見了」。
  ///
  /// 三條規則：附件不算內文；不走進 `message/rfc822`（那是另一封信）；
  /// 同一層優先取先出現的。
  @visibleForTesting
  static MimePart? findBodyPart(MimePart part, String mediaType) {
    if (_isAttachment(part)) return null;
    // message/rfc822 是「夾在這封信裡的另一封信」，它的內文不是這封信的內文。
    if (part.mediaType.text == 'message/rfc822') return null;
    if (part.mediaType.text == mediaType) return part;
    for (final child in part.parts ?? const <MimePart>[]) {
      final hit = findBodyPart(child, mediaType);
      if (hit != null) return hit;
    }
    return null;
  }

  /// 這個 part 是不是附件。`Content-Disposition: attachment` 說了算；沒有這個
  /// 標頭但有 filename 的（有些寄件端這樣寫）也算。
  static bool _isAttachment(MimePart part) {
    final disposition = part.getHeaderContentDisposition();
    if (disposition == null) return false;
    if (disposition.disposition == ContentDisposition.attachment) return true;
    return disposition.filename?.isNotEmpty ?? false;
  }

  /// 從一封已抓回的信裡列出附件。**純函式，測試直接打這裡。**
  ///
  /// 只取 `Content-Disposition: attachment` 的 part：內嵌圖片（`inline` 加
  /// `cid:`）已經被 [inlineCidImages] 畫進內文了，再列一次只是重複。
  static List<MailAttachment> attachmentsOf(MimeMessage message) => [
        for (final info in message.findContentInfo())
          MailAttachment(
            fetchId: info.fetchId,
            // 沒有檔名的附件在真實信件裡不罕見（掃描器、自動產生的報表）。
            // 給一個看得懂的預設，總比畫一列空白好。
            name: info.contentDisposition?.filename ??
                info.contentType?.parameters['name'] ??
                info.fetchId,
            mediaType: info.contentType?.mediaType.text ?? '',
            sizeBytes: info.contentDisposition?.size ?? 0,
          ),
      ];

  /// 單封信的內文**HTML**，失敗回 null。
  ///
  /// 只有 `text/plain` 的信要先轉成 HTML 再回去：下游是 `HtmlWidget`，直接
  /// 把純文字餵進去的話換行會全部消失，內文裡的 `<` 還會被當成標籤開頭吃掉
  /// 後面一整段。校內信有相當比例是純文字，這不是邊角案例。
  static Future<String?> fetchBody(int uid,
      {String folderPath = MailConfig.inboxPath}) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return null;
      // **不可以寫死 selectInbox()。** UID 只在資料夾內唯一，在回收筒點一封
      // 信卻去收件匣抓同一個 UID，不是「讀取內文失敗」就是顯示到另一封信。
      await client.selectMailboxByPath(folderPath);
      final result = await client.uidFetchMessage(uid, "BODY[]");
      if (result.messages.isEmpty) return null;
      final message = result.messages.first;
      final html = decodeBestTextPart(message, 'text/html');
      if (html != null) {
        return inlineCidImages(message, HtmlStyleInliner.inline(html));
      }
      final plain = decodeBestTextPart(message, 'text/plain');
      return plain == null ? null : plainTextToHtml(plain);
    } catch (e, stack) {
      Log.eWithStack("mail fetchBody($uid) failed: $e", stack);
      return null;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 標記已讀／未讀。
  static Future<bool> setSeen(int uid,
      {required bool seen, String folderPath = MailConfig.inboxPath}) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return false;
      await client.selectMailboxByPath(folderPath);
      await client.uidStore(
        MessageSequence.fromId(uid, isUid: true),
        [MessageFlags.seen],
        action: seen ? StoreAction.add : StoreAction.remove,
      );
      return true;
    } catch (e, stack) {
      Log.eWithStack("mail setSeen($uid) failed: $e", stack);
      return false;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 把一封信丟進回收筒。
  static Future<bool> moveToTrash(int uid,
          {String folderPath = MailConfig.inboxPath}) =>
      moveToRole(uid, MailFolderRole.trash, folderPath: folderPath);

  /// 把一封信從 [folderPath] 搬到 [target] 角色的資料夾。
  ///
  /// **伺服器沒有 `MOVE`**，所以是 COPY → STORE `\Deleted` → EXPUNGE 三步。
  /// 三步之間斷線會在來源資料夾留下一封已標刪除的副本，UI 要能容忍重複。
  ///
  /// **找不到目標資料夾就整個放棄**，不做「只標 \Deleted」的退路：那對回收筒
  /// 來說是把信就地刪掉、對封存來說更是完全相反的結果，兩種都比「沒動作」糟。
  static Future<bool> moveToRole(int uid, MailFolderRole target,
      {String folderPath = MailConfig.inboxPath}) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return false;
      final destination = await _findFolder(client, target);
      if (destination == null) {
        Log.d('mail moveToRole: 找不到 ${target.name} 資料夾');
        return false;
      }
      return await _move(client, uid,
          from: folderPath, toEncoded: destination.encodedPath);
    } catch (e, stack) {
      Log.eWithStack("mail moveToRole($uid, ${target.name}) failed: $e", stack);
      return false;
    } finally {
      await _quietLogout(client);
    }
  }

  /// 把一封信搬到指定的資料夾（wire 路徑）。給「移到⋯」那個選單用。
  static Future<bool> moveToFolder(int uid, String targetEncodedPath,
      {String folderPath = MailConfig.inboxPath}) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return false;
      return await _move(client, uid,
          from: folderPath, toEncoded: targetEncodedPath);
    } catch (e, stack) {
      Log.eWithStack("mail moveToFolder($uid) failed: $e", stack);
      return false;
    } finally {
      await _quietLogout(client);
    }
  }

  /// COPY → STORE `\Deleted` → EXPUNGE。伺服器沒有 `MOVE`，只能三步。
  ///
  /// [toEncoded] 是 wire 路徑（我們自己存的那一種），但 `uidCopy` 要的是解碼
  /// 值——它內部會自己編一次，傳 wire 值進去會被編成 `&-Vt5lNntS-`，COPY 到
  /// 一個不存在的資料夾。所以這裡先解回來。
  static Future<bool> _move(ImapClient client, int uid,
      {required String from, required String toEncoded}) async {
    if (toEncoded == from) return true; // 已經在那裡了。
    final separator = client.serverInfo.pathSeparator ?? '/';
    final decoded = decodeMailboxPath(toEncoded, separator);

    await client.selectMailboxByPath(from);
    final sequence = MessageSequence.fromId(uid, isUid: true);
    await client.uidCopy(sequence, targetMailboxPath: decoded);
    await client.uidStore(sequence, [MessageFlags.deleted],
        action: StoreAction.add);
    await client.expunge();
    return true;
  }

  /// wire 路徑（modified UTF-7）解回人看得懂的那一種。
  ///
  /// **`flags` 一定要給可變的清單。** 目標名字解出來是 `INBOX` 時，
  /// `Mailbox` 的建構式會往 flags 補一個 `MailboxFlag.inbox`
  /// （enough_mail mailbox.dart:89）。傳 `const []` 進去當場丟
  /// `UnsupportedError`，而它會被 [moveToFolder] 的 catch 吃掉變成「操作失敗」
  /// ——「從回收筒搬回收件匣」整個功能壞掉就是這樣來的，而且只有目標是收件匣
  /// 時才會發生，所以看起來像回收筒特有的毛病。
  @visibleForTesting
  static String decodeMailboxPath(String encoded, String separator) => Mailbox(
        encodedName: encoded,
        encodedPath: encoded,
        flags: <MailboxFlag>[],
        pathSeparator: separator,
      ).path;

  /// 把草稿組成要送出去的 MIME。**純函式（除了讀附件檔），測試直接打這裡。**
  ///
  /// **容器一定要自己宣告。** 不宣告的話 enough_mail 看到「根沒有 contentType
  /// 但有子 part」就補成 multipart/mixed——兩份內文變成並列，收件端顯示純文字
  /// 那一份，於是「收到的信和寄出時看到的完全不同」。內文要的是
  /// multipart/alternative（RFC 2046 §5.1.4：純文字在前、HTML 在後，收件端挑
  /// 最後一個看得懂的）。
  ///
  /// 兩個子 part 都釘成 quoted-printable：純英文內文會被判成 7bit，而
  /// enough_mail 的 `wrapText()` 會在 7bit 下硬換行，長網址與 data: URI 會被
  /// 從中間切斷。
  @visibleForTesting
  static Future<MimeMessage> buildMimeMessage(
      MailDraft draft, MailAddress from) async {
    final builder = MessageBuilder()
      ..from = [from]
      ..to = draft.to.map((e) => MailAddress(null, e)).toList()
      ..cc = draft.cc.map((e) => MailAddress(null, e)).toList()
      ..subject = draft.subject;
    // **密件副本刻意不設進 builder。** `MessageBuilder.bcc` 會真的寫出一行
    // `Bcc:` 標頭，於是每個收件者都看得到密件副本是誰——那正好是它要避免的事。
    // 它只該出現在 SMTP 的 `RCPT TO`，見 send() 裡的 recipients。

    final plain = htmlToPlainText(draft.body);
    if (draft.attachments.isEmpty) {
      builder.setContentType(MediaSubtype.multipartAlternative.mediaType);
      builder.addTextPlain(plain,
          transferEncoding: TransferEncoding.quotedPrintable);
      builder.addTextHtml(draft.body,
          transferEncoding: TransferEncoding.quotedPrintable);
    } else {
      // 有附件時外層是 multipart/mixed，內文的 alternative 包在裡面當第一個
      // part。addMultipartAlternative() 沒有 transferEncoding 參數，所以自己
      // 開一個 alternative 子容器。
      builder.setContentType(MediaSubtype.multipartMixed.mediaType);
      builder.addPart(mediaSubtype: MediaSubtype.multipartAlternative)
        ..addTextPlain(plain,
            transferEncoding: TransferEncoding.quotedPrintable)
        ..addTextHtml(draft.body,
            transferEncoding: TransferEncoding.quotedPrintable);
      for (final file in draft.attachments) {
        await builder.addFile(file, MediaType.guessFromFileName(file.path));
      }
    }
    return builder.buildMimeMessage();
  }

  /// 寄出一封信。成功回 true。
  ///
  /// 寄完會把副本 `APPEND` 進寄件備份匣——伺服器**不會**自己做這件事，不補的話
  /// 使用者在任何裝置上都找不到自己寄過什麼。找不到寄件備份匣就跳過，
  /// **但整封信仍然算寄成功**：信已經送出去了，備份失敗不該讓使用者以為沒寄出
  /// 而再寄一次。
  static Future<bool> send(MailDraft draft) async {
    final password = Model.instance.getMailPassword();
    if (password.isEmpty || !draft.hasRecipients) return false;
    final account = Model.instance.getAccount();
    final from = MailAddress(null, accountToAddress(account));

    final MimeMessage message;
    try {
      message = await buildMimeMessage(draft, from);
    } catch (e, stack) {
      Log.eWithStack("mail build message failed: $e", stack);
      return false;
    }

    SmtpClient? smtp;
    try {
      smtp = SmtpClient(MailConfig.clientDomain);
      // **整段包 timeout。** `SmtpClient` 整個類別沒有任何逾時鉤子（連
      // sendCommand 都不帶），connectToServer 的 timeout 一樣只蓋握手。少了
      // 這一層，伺服器不回話時 send() 就永遠不回來，寄信頁的遮罩也永遠不收。
      await Future(() async {
        await smtp!.connectToServer(
          MailConfig.host,
          MailConfig.smtpPort,
          isSecure: true,
          timeout: MailConfig.connectTimeout,
        );
        await smtp.ehlo();
        await smtp.authenticate(account, password, AuthMechanism.login);
        // 收件者要自己給：message 裡沒有 Bcc 標頭（見 buildMimeMessage），
        // 不明給的話密件副本根本收不到信。
        await smtp.sendMessage(
          message,
          recipients: [
            for (final e in [...draft.to, ...draft.cc, ...draft.bcc])
              MailAddress(null, e),
          ],
        );
      }).timeout(MailConfig.smtpTimeout);
    } catch (e, stack) {
      Log.eWithStack("mail send failed: $e", stack);
      return false;
    } finally {
      try {
        await smtp?.quit();
      } catch (_) {
        // 連線已經沒了，沒有什麼要收的。
      }
    }

    // **備份不擋回傳。** 註解上面已經承諾「備份失敗不該讓使用者以為沒寄出」，
    // 這裡讓程式碼兌現它：信已經送出去了，備份再慢也不該把使用者留在遮罩底下。
    // 不用 unawaited()——那會讓 sendDraft 變成非決定性，而且使用者一離開頁面
    // 備份就可能沒跑完。
    await _appendToSent(message).timeout(MailConfig.appendTimeout,
        onTimeout: () {
      Log.d('mail: 寄件備份逾時，但信已經寄出去了');
    });
    return true;
  }

  /// 把寄出去的信放一份到寄件備份匣。失敗只記 log，不影響寄信結果。
  static Future<void> _appendToSent(MimeMessage message) async {
    ImapClient? client;
    try {
      client = await _openWithStoredCredentials();
      if (client == null) return;
      final box = await _findFolder(client, MailFolderRole.sent);
      if (box == null) {
        Log.d("mail: 找不到寄件備份匣，這封信不留副本");
        return;
      }
      // 沒有 UIDPLUS，APPEND 不會回新的 UID；要對回那封信只能之後再 SEARCH。
      // 目前沒有這個需求，所以不做。
      await client.appendMessage(
        message,
        // 解碼值：appendMessage 會自己編一次，理由同 moveToRole。
        targetMailboxPath: box.path,
        flags: [MessageFlags.seen],
        // **一定要明給。** appendMessage 用的是自己的方法參數，不吃
        // defaultResponseTimeout；不給就是 null，也就是永遠不逾時——整封信
        // （含附件）要再上傳一次，卡住的話寄信那一頭就永遠不回來。
        responseTimeout: MailConfig.appendTimeout,
      );
    } catch (e, stack) {
      Log.eWithStack("mail append to sent failed: $e", stack);
    } finally {
      await _quietLogout(client);
    }
  }

  /// 學號轉成完整的信箱位址。已經是完整位址就原樣回。
  static String accountToAddress(String account) =>
      account.contains('@') ? account : '$account@${MailConfig.host}';

  /// 找出回收筒的路徑。沒有 `SPECIAL-USE`，只能靠名字對（見 [mailFolderRole]）。
  /// 回 `Mailbox` 而不是路徑字串：呼叫端有時要 wire 值（SELECT）、有時要解碼
  /// 值（COPY / APPEND），只回其中一種一定會有人拿錯。
  static Future<Mailbox?> _findFolder(
      ImapClient client, MailFolderRole role) async {
    final boxes = await client.listMailboxes();
    for (final box in boxes) {
      // 角色是照**解碼後**的中文名對的（見 mailFolderRole），不能用 encodedPath。
      if (mailFolderRole(box.name) == role) return box;
    }
    return null;
  }

  /// 收尾用的 logout：連線已經斷掉時再 logout 會再拋一次，把真正的錯誤蓋掉。
  static Future<void> _quietLogout(ImapClient? client) async {
    if (client == null) return;
    try {
      await client.logout();
    } catch (_) {
      // 連線已經沒了，沒有什麼要收的。
    }
  }

  /// 取出指定 media type 的文字內容，必要時**繞過 `enough_mail` 自己解碼**。
  /// 純函式，測試直接打這裡。
  ///
  /// **為什麼不直接用 `decodeTextHtmlPart()`**：`enough_mail` 的
  /// quoted-printable 解碼是 charset-unaware 的。它把**連續的** `=XX` 湊成一組
  /// 才交給 charset codec（`quoted_printable_mail_codec.dart` 的 `decodeText`），
  /// 但 Big5 一個字是 lead(0xA1–0xF9) + trail(0x40–0x7E 或 0xA1–0xFE)，落在
  /// 0x40–0x7E 的 trail byte 是可列印 ASCII，QP **不會**編碼它。於是解碼器只拿到
  /// 孤立的 `=B7`，big5 解不了單一 byte，就吐一個替換字元，後面的 `s` 原樣留下——
  /// 「新細明體」變成「?s細明體」。實測一封真的校內信有 360 個替換字元。
  ///
  /// `decodeContentBinary()` 也救不了：`MailCodec` 的 `_binaryDecodersByName`
  /// 根本沒有 quoted-printable 這一項，它會 fallback 成把原始 QP 文字當 bytes 回傳。
  ///
  /// 所以這裡自己來：`render()` 拿原始 part 內容 → 自己做 QP → bytes → 用宣告的
  /// charset 解。只有「quoted-printable + 非 Unicode charset」這個組合才繞道，
  /// 其餘一律走 `enough_mail`，不要為了這個缺陷把整條路徑都重寫。
  static String? decodeBestTextPart(MimeMessage message, String mediaType) {
    final found = findBodyPart(message, mediaType);
    if (found == null) return null;

    final contentType = found.getHeaderContentType();
    final charset = contentType?.charset?.toLowerCase();
    final encoding =
        found.getHeaderValue('content-transfer-encoding')?.toLowerCase();
    final codec = charset == null ? null : _codecFor(charset);
    if (encoding == 'quoted-printable' && codec != null) {
      final buffer = StringBuffer();
      found.mimeData?.render(buffer, renderHeader: false);
      final raw = buffer.toString();
      if (raw.isNotEmpty) {
        return MailTextDecoder.bytes(charset, _quotedPrintableToBytes(raw));
      }
    }
    // 非 Unicode charset 的其餘編碼（base64、7bit）也要自己解：`enough_mail`
    // 走的是 `enough_convert` 的 Big5 表，而那張表少了 14 個碼位，其中包含
    // 常用的「告」。位元組自己拿得到，就不必受那個洞影響。
    if (codec != null) {
      final data = found.decodeContentBinary();
      if (data != null && data.isNotEmpty) {
        return MailTextDecoder.bytes(charset, data);
      }
    }
    return found.decodeContentText();
  }

  /// 只認我們真的會遇到的非 Unicode 編碼。認不出來回 null，讓呼叫端走
  /// `enough_mail` 的原路——那條路對 UTF-8 與 base64 都是對的。
  static Encoding? _codecFor(String charset) => switch (charset) {
        'big5' ||
        'big-5' ||
        'cp950' ||
        'ms950' =>
          const Big5Codec(allowInvalid: true),
        'gbk' || 'gb2312' || 'cp936' => const GbkCodec(allowInvalid: true),
        _ => null,
      };

  /// quoted-printable → bytes。
  ///
  /// **先拿掉軟換行再逐字掃**：Big5 的兩個 byte 可能被軟換行拆開
  /// （`=B7` 在行尾、`s` 在下一行開頭），不先接回來就會少解一個字。
  static Uint8List _quotedPrintableToBytes(String text) {
    final cleaned = text.replaceAll('=\r\n', '').replaceAll('=\n', '');
    final out = <int>[];
    for (var i = 0; i < cleaned.length; i++) {
      if (cleaned[i] == '=' && i + 2 < cleaned.length) {
        final code = int.tryParse(cleaned.substring(i + 1, i + 3), radix: 16);
        if (code != null) {
          out.add(code);
          i += 2;
          continue;
        }
      }
      out.add(cleaned.codeUnitAt(i));
    }
    return Uint8List.fromList(out);
  }

  /// 把 `cid:` 內嵌圖片換成 `data:` URI。**純函式，測試直接打這裡。**
  ///
  /// 內嵌圖片跟遠端圖片是兩回事：`cid:` 指的是**這封信自己夾帶的** part，
  /// 顯示它不會對外發任何請求，也就沒有追蹤像素的問題。不換掉的話
  /// `HtmlWidget` 認不得 `cid:` scheme，Outlook 寄來的信會整片空白。
  ///
  /// 超過 [_maxInlineImageBytes] 的單張、或累計超過 [_maxInlineTotalBytes] 的
  /// 就不換：整封信會被轉成 base64 字串留在記憶體裡，一封夾了十張高解析圖的
  /// 公告可以輕鬆吃掉幾十 MB。換不掉的維持 `cid:`，畫面上就是不顯示。
  static String inlineCidImages(MimeMessage message, String html) {
    var budget = _maxInlineTotalBytes;
    var result = html;
    for (final part in message.allPartsFlat) {
      final id = part.getHeaderValue('content-id');
      if (id == null || !part.mediaType.text.startsWith('image/')) continue;
      // Content-ID 標頭是 <foo@bar> 的形式，src 裡則是不帶角括號的 foo@bar。
      final cid = id.replaceAll('<', '').replaceAll('>', '').trim();
      if (cid.isEmpty) continue;

      final bytes = part.decodeContentBinary();
      if (bytes == null || bytes.isEmpty) continue;
      if (bytes.length > _maxInlineImageBytes || bytes.length > budget) {
        continue;
      }
      budget -= bytes.length;

      final uri = 'data:${part.mediaType.text};base64,${base64Encode(bytes)}';
      result = result.replaceAll('cid:$cid', uri);
    }
    return result;
  }

  /// 單張內嵌圖片的上限。
  static const int _maxInlineImageBytes = 2 * 1024 * 1024;

  /// 一封信所有內嵌圖片加起來的上限。
  static const int _maxInlineTotalBytes = 8 * 1024 * 1024;

  /// HTML 內文轉回可讀的純文字，給回覆／轉寄的引言用。
  /// **純函式，測試直接打這裡。**
  ///
  /// 順序有講究，寫錯就會出現實際踩過的兩個症狀：
  ///
  /// 1. **`<style>` / `<script>` / `<head>` 要連內容整段拿掉。** 只剝標籤的話
  ///    Outlook 的 CSS 會整片跑進引言，使用者按下回覆看到的第一行是
  ///    `v\:* {behavior:url(#default#VML);}`。
  /// 2. **`&amp;` 要最後解。** 先解的話 `&amp;lt;` 會被還原成 `<`，等於把
  ///    寄件者刻意跳脫過的角括號又變回標籤。
  static String htmlToPlainText(String html) {
    final text = html
        .replaceAll(
            RegExp(r'<(style|script|head)[^>]*>.*?</\1>',
                caseSensitive: false, dotAll: true),
            '')
        // MSO 的條件註解裡也是整包 CSS 與 VML。
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        // 區塊結束要補換行，否則整封信會黏成一長行。
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
            RegExp(r'</(p|div|tr|li|h[1-6]|blockquote)>', caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    return text
        // 行尾空白會讓「空行」看起來不空，下一步的收斂就抓不到。
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// 純文字內文轉成可以交給 `HtmlWidget` 的 HTML。**純函式，測試直接打這裡。**
  ///
  /// 先跳脫再換行，順序不能反：反過來的話自己插進去的 `<br>` 會被跳脫成
  /// 字面文字。
  static String plainTextToHtml(String text) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return escaped
        // 先把 CRLF 收成 LF，否則每一行會多出一個空行。
        .replaceAll('\r\n', '\n')
        // 純文字信常常夾著大段空行（簽名檔前後、引言之間）。原樣保留的話一封
        // 信會被撐得很開，捲很久才看得到下一段。三行以上收成兩行。
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll('\n', '<br>');
  }

  /// `MimeMessage` → 快取得下去的 envelope。**純函式，測試直接打這裡。**
  static MailMessageJson toMessageJson(MimeMessage message) {
    final from =
        (message.from?.isNotEmpty ?? false) ? message.from!.first : null;
    return MailMessageJson(
      uid: message.uid ?? 0,
      // **不走 `decodeSubject()`。** 那條路是 `enough_mail` 自己的 header
      // 解碼，碰不到我們補過洞的 Big5 表，而且它的 Q-encoding 對非 Unicode
      // charset 是全毀的。見 [MailTextDecoder.header]。
      subject: MailTextDecoder.header(message.getHeaderValue('subject') ?? ''),
      fromName: from?.personalName ?? "",
      fromEmail: from?.email ?? "",
      // 沒有 Date 標頭的信給 0，排序時會沉到最底下而不是拋例外。
      dateMillis: message.decodeDate()?.millisecondsSinceEpoch ?? 0,
      seen: message.isSeen,
      to: _addresses(message.to),
      cc: _addresses(message.cc),
    );
  }

  static List<String> _addresses(List<MailAddress>? list) =>
      [for (final a in list ?? const <MailAddress>[]) a.email];
}
