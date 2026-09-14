import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/model/mail/mail_search_hit.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';

/// 信箱列表的狀態。
///
/// 只回資料、不開對話框——「密碼還沒設定」是由 [needsPassword] 讓頁面自己去
/// 決定要開哪個對話框，controller 不碰 UI。
class MailController {
  /// 目前資料夾裡的信。null 代表還在載入。
  final messages = Rxn<Result<List<MailMessageJson>>>();

  /// 搜尋結果，每一筆帶著自己的資料夾：跨資料夾之後 UID 不再唯一。null 代表還在找。
  final results = Rxn<Result<List<MailSearchHit>>>();

  final folders = Rxn<Result<List<MailFolderJson>>>();

  /// 目前看的資料夾路徑。
  final folderPath = MailRepository.inboxPath.obs;

  /// 目前的搜尋關鍵字。空字串代表沒在搜尋。
  final keyword = ''.obs;

  /// 搜尋範圍。收件匣有四千多封，找不到的時候使用者分不出是「這個資料夾沒有」
  /// 還是「整個信箱都沒有」——兩條路都要留。
  final searchAllFolders = false.obs;

  /// 未讀數。null 代表還沒拿到或拿不到——拿不到就不顯示，不要顯示 0 騙人。
  final unread = Rxn<int>();

  /// 密碼還沒設定。頁面要先開密碼對話框，不要直接載入——那只會換來一次
  /// 必定失敗的連線與一句看不懂的錯誤訊息。
  bool get needsPassword => !MailRepository.instance.hasMailPassword;

  bool get isSearching => keyword.value.isNotEmpty;

  /// 載入清單。
  ///
  /// **先畫本機、再打網路。** 先前每次進頁面都是空白轉圈等一次連線；本機有
  /// 資料時直接畫出來，網路回來再換掉。搜尋不吃這條路——搜尋結果沒有本機版本。
  Future<void> load() async {
    // 這一趟之後，還在飛的 loadMore 拿到的那一頁就不該接上去了。
    _generation++;
    if (isSearching) {
      results.value = null;
      results.value = await MailRepository.instance.search(
        keyword.value,
        folderPath: folderPath.value,
        allFolderPaths: searchAllFolders.value ? _allFolderPaths : null,
      );
      unawaited(refreshUnread());
      return;
    }

    final cached =
        await MailRepository.instance.cachedMessages(folderPath.value);
    // 沒有快取才轉圈；有的話直接畫，使用者不必看白畫面。
    messages.value = cached.isEmpty ? null : Ok(cached);
    messages.value =
        await MailRepository.instance.getMessages(folderPath.value);
    // **重抓會把清單截回第一頁**（`replaceMessages`），所以游標也要回到起點。
    // 不重設的話，載到底過的資料夾下拉重新整理完只剩 50 封，底下那一列卻還
    // 說「沒有更舊的信了」，而且自動載入從此再也不會觸發。
    hasMore.value = true;
    loadMoreFailed.value = false;
    // 未讀數不擋畫面：清單先出來，數字晚一點到也沒關係。
    unawaited(refreshUnread());
  }

  Future<void> loadFolders() async {
    final cached = await MailRepository.instance.cachedFolders();
    folders.value = cached.isEmpty ? null : Ok(cached);
    folders.value = await MailRepository.instance.getFolders();
  }

  /// 未讀數只在**這一頁**顯示。已決策不做主畫面 tab 的 badge，那會在啟動路徑
  /// 上多一次網路往返（docs/WEBMAIL_IMAP.md §9）。
  Future<void> refreshUnread() async {
    unread.value = await MailRepository.instance.unreadCount(folderPath.value);
  }

  Future<void> openFolder(String path) async {
    if (folderPath.value == path && !isSearching) return;
    folderPath.value = path;
    hasMore.value = true;
    // 換資料夾等於換一份清單，舊的關鍵字留著只會讓人以為搜尋沒生效。
    keyword.value = '';
    searchAllFolders.value = false;
    await load();
  }

  Future<void> searchFor(String value) async {
    final trimmed = value.trim();
    if (trimmed == keyword.value) return;
    keyword.value = trimmed;
    await load();
  }

  /// 換搜尋範圍。沒在搜尋時只記下來，不白跑一次連線。
  Future<void> setSearchAllFolders(bool value) async {
    if (searchAllFolders.value == value) return;
    searchAllFolders.value = value;
    if (isSearching) await load();
  }

  /// 已知的資料夾路徑。還沒問到就只有收件匣——那是唯一保證存在的一個。
  List<String> get _allFolderPaths {
    final known = folders.value?.dataOrNull;
    if (known == null || known.isEmpty) return const [MailRepository.inboxPath];
    return [for (final folder in known) folder.path];
  }

  /// 標記已讀並就地更新清單，不重抓整批。
  ///
  /// 伺服器沒有 `CONDSTORE`，重抓等於把整批 envelope 再拉一次；只改一顆旗標
  /// 不值得。失敗就不動畫面，讓下一次重新整理去對齊。
  ///
  /// [folderPath] 是這封信所在的資料夾，沒給就是正在看的那一個。
  Future<void> markSeen(int uid, {String? folderPath}) async {
    await setSeen(uid, seen: true, folderPath: folderPath);
  }

  /// 還有沒有更舊的信可以載。第一次載入之前當成「可能有」。
  final hasMore = true.obs;

  /// 正在載入下一頁。UI 靠它畫轉圈並擋住重複觸發。
  final loadingMore = false.obs;

  /// 上一次載下一頁失敗了。
  ///
  /// **捲到底自動載入一定要有這個閂。** 失敗時 [hasMore] 不動、[loadingMore]
  /// 也回到 false，下一個捲動事件（同一次拖曳裡就有幾十個）會立刻再打一次；
  /// 這台伺服器每一頁是一次連線加一次 `SEARCH ALL`，那等於斷線時無限重連。
  /// 閂上之後只有使用者自己按底下那一列才會解開。
  final loadMoreFailed = false.obs;

  /// 清單重抓過幾次。[loadMore] 拿它比對，中途被重新整理換掉的那一頁就丟掉，
  /// 不然剛刪掉的信會被接回清單裡。
  int _generation = 0;

  /// 再載一頁。**游標是目前清單裡最舊的那一封的 UID**，不是頁碼——序號會因為
  /// 新信與 EXPUNGE 整批位移。
  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore.value || isSearching) return;
    final current = messages.value?.dataOrNull;
    if (current == null || current.isEmpty) return;

    loadingMore.value = true;
    loadMoreFailed.value = false;
    final generation = _generation;
    try {
      var oldest = current.first.uid;
      for (final m in current) {
        if (m.uid < oldest) oldest = m.uid;
      }
      final page =
          await MailRepository.instance.loadMore(folderPath.value, oldest);
      // 這中間重新整理過，`current` 已經是上一份清單了。
      if (generation != _generation) return;
      if (page == null) {
        // 閂上等使用者自己再按。不閂的話下一個捲動事件就再連一次。
        loadMoreFailed.value = true;
        return;
      }
      // **空的一頁就當作到底了。** 捲到底自動載入之後，資料夾裡的信撐不滿
      // 一個畫面時清單捲不動，靠的是 metrics 通知補一次；伺服器若回了空的
      // 一頁卻還說 hasMore，那一發通知會一直重來，每一次都是一條 IMAP 連線。
      hasMore.value = page.hasMore && page.messages.isNotEmpty;
      if (page.messages.isEmpty) return;
      messages.value = Ok([...current, ...page.messages]);
    } finally {
      loadingMore.value = false;
    }
  }

  /// 標記成未讀／已讀。就地更新那一列，不重抓整批。
  ///
  /// [markSeen] 是「開信時順手標已讀」的單向版本；這一個是使用者主動切換，
  /// 所以兩個方向都要，未讀數也要跟著加回去。
  Future<bool> setSeen(int uid,
      {required bool seen, String? folderPath}) async {
    final folder = _folderOr(folderPath);
    final message = _find(uid, folder);
    if (message == null || message.seen == seen) return false;

    if (!await MailRepository.instance
        .setSeen(uid, seen: seen, folderPath: folder)) {
      return false;
    }

    _patch(uid, folder, (m) => m.copyWith(seen: seen));
    // 未讀數是正在看的那個資料夾的，別的資料夾的信不算。
    final count = unread.value;
    if (count != null && folder == this.folderPath.value) {
      unread.value = seen ? max(0, count - 1) : count + 1;
    }
    return true;
  }

  /// 搬到指定的資料夾並就地把那一列拿掉。
  Future<bool> moveToFolder(int uid, String targetPath, {String? folderPath}) {
    final folder = _folderOr(folderPath);
    return _remove(
        uid,
        folder,
        () => MailRepository.instance
            .moveToFolder(uid, targetPath, folderPath: folder));
  }

  /// 丟進回收筒並就地把那一列拿掉。回傳是否成功，訊息由頁面決定怎麼講。
  Future<bool> moveToTrash(int uid, {String? folderPath}) {
    final folder = _folderOr(folderPath);
    return _remove(uid, folder,
        () => MailRepository.instance.moveToTrash(uid, folderPath: folder));
  }

  /// 封存並就地把那一列拿掉。
  Future<bool> moveToArchive(int uid, {String? folderPath}) {
    final folder = _folderOr(folderPath);
    return _remove(uid, folder,
        () => MailRepository.instance.moveToArchive(uid, folderPath: folder));
  }

  Future<bool> _remove(
      int uid, String folder, Future<bool> Function() action) async {
    if (!await action()) return false;
    _patch(uid, folder, (_) => null);
    return true;
  }

  String _folderOr(String? path) => path ?? folderPath.value;

  /// 畫面上那份清單裡的那一封。搜尋中比對 UID 也比對資料夾：跨資料夾之後 UID 會撞。
  MailMessageJson? _find(int uid, String folder) {
    if (isSearching) {
      for (final hit in results.value?.dataOrNull ?? const <MailSearchHit>[]) {
        if (hit.message.uid == uid && hit.folderPath == folder) {
          return hit.message;
        }
      }
      return null;
    }
    if (folder != folderPath.value) return null;
    for (final message
        in messages.value?.dataOrNull ?? const <MailMessageJson>[]) {
      if (message.uid == uid) return message;
    }
    return null;
  }

  /// 就地換掉那一列，[change] 回 null 就是拿掉。
  void _patch(int uid, String folder,
      MailMessageJson? Function(MailMessageJson message) change) {
    if (isSearching) {
      final hits = results.value?.dataOrNull;
      if (hits == null) return;
      final next = <MailSearchHit>[];
      for (final hit in hits) {
        if (hit.message.uid != uid || hit.folderPath != folder) {
          next.add(hit);
          continue;
        }
        final updated = change(hit.message);
        if (updated != null) next.add(MailSearchHit(hit.folderPath, updated));
      }
      results.value = Ok(next);
      return;
    }
    final current = messages.value?.dataOrNull;
    if (current == null || folder != folderPath.value) return;
    final next = <MailMessageJson>[];
    for (final message in current) {
      if (message.uid != uid) {
        next.add(message);
        continue;
      }
      final updated = change(message);
      if (updated != null) next.add(updated);
    }
    messages.value = Ok(next);
  }

  void dispose() {
    messages.close();
    results.close();
    folders.close();
    folderPath.close();
    keyword.close();
    searchAllFolders.close();
    hasMore.close();
    loadingMore.close();
    loadMoreFailed.close();
    unread.close();
  }
}
