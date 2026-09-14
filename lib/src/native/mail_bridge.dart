import 'dart:async';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/controller/mail/mail_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/controller/mail/mail_watch_controller.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/model/mail/mail_outbox_item.dart';
import 'package:flutter_app/src/native/bridge_results.dart';
import 'package:flutter_app/src/native/mail_memo.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/mail_folders.dart';
import 'package:flutter_app/src/util/mail_groups.dart';
import 'package:flutter_app/src/util/mail_text.dart';
import 'package:sprintf/sprintf.dart';

/// 原生版的信箱分頁。清單狀態照 `MailController`、版面上的字照 `mail_list_page.dart`，
/// 新信橫幅與寄件匣的回報照 `MainScreen`。
///
/// 清單是推過去的：`MailController` 先畫本機再打網路、搜尋時先清空再換上結果，
/// Flutter 版靠 Obx 每一步重畫一次，這裡每一步推一次，Swift 不必猜中間狀態。
class MailBridge implements TatMailApi {
  MailBridge(this._memo, {TatMailHost? host, DateTime Function()? clock})
      : _host = host ?? TatMailHost(),
        _clock = clock ?? DateTime.now;

  static void install(MailMemo memo) => TatMailApi.setUp(MailBridge(memo));

  final MailMemo _memo;
  final TatMailHost _host;
  final DateTime Function() _clock;

  MailController? _controller;
  final List<StreamSubscription<Object?>> _listening = [];
  bool _pushQueued = false;
  StreamSubscription<List<MailMessageJson>>? _arrivals;
  StreamSubscription<List<MailOutboxItem>>? _outbox;
  StreamSubscription<MailOutboxResult>? _results;

  @override
  MailStatus status() => MailStatus(
        configured: MailRepository.instance.hasMailPassword,
        address: MailConnector.accountToAddress(Model.instance.getAccount()),
      );

  @override
  Future<MailSetupResult> setup(String password) async {
    if (password.isEmpty) return MailSetupResult(ok: false);
    final outcome = await MailRepository.instance
        .verifyPassword(Model.instance.getAccount(), password);
    switch (outcome) {
      case MailAuthOutcome.ok:
        Model.instance.setMailPassword(password);
        await Model.instance.saveUserData();
        startWatch();
        return MailSetupResult(ok: true);
      case MailAuthOutcome.rejected:
        return MailSetupResult(
            ok: false, error: R.current.mailPasswordRejected);
      case MailAuthOutcome.unreachable:
        return MailSetupResult(
            ok: false, error: R.current.mailPasswordUnreachable);
    }
  }

  @override
  Future<void> open() async {
    for (final subscription in _listening) {
      unawaited(subscription.cancel());
    }
    _listening.clear();
    final c = MailController();
    _controller = c;
    _listening.addAll([
      c.messages.listen(_queuePush),
      c.results.listen(_queuePush),
      c.folders.listen(_queuePush),
      c.folderPath.listen(_queuePush),
      c.keyword.listen(_queuePush),
      c.searchAllFolders.listen(_queuePush),
      c.hasMore.listen(_queuePush),
      c.loadMoreFailed.listen(_queuePush),
    ]);
    _queuePush(null);
    await c.load();
    unawaited(c.loadFolders());
  }

  @override
  Future<void> reload() async {
    await _controller?.load();
  }

  @override
  Future<void> openFolder(String path) async {
    await _controller?.openFolder(path);
  }

  @override
  Future<void> search(String keyword, bool allFolders) async {
    final c = _controller;
    if (c == null) return;
    final trimmed = keyword.trim();
    if (trimmed == c.keyword.value) {
      await c.setSearchAllFolders(allFolders);
      return;
    }
    // 範圍跟著關鍵字一起帶進去，只連一次線。
    c.searchAllFolders.value = allFolders;
    await c.searchFor(trimmed);
  }

  @override
  Future<void> endSearch() async {
    final c = _controller;
    if (c == null) return;
    c.searchAllFolders.value = false;
    if (c.isSearching) await c.searchFor('');
  }

  @override
  Future<void> loadMore() async {
    await _controller?.loadMore();
  }

  @override
  Future<void> markSeen(String ref) async {
    final hit = _memo[ref];
    if (hit != null) {
      await _controller?.markSeen(hit.message.uid, folderPath: hit.folderPath);
    }
  }

  @override
  Future<bool> setSeen(String ref, bool seen) => _onRow(
      ref,
      (c, hit) =>
          c.setSeen(hit.message.uid, seen: seen, folderPath: hit.folderPath));

  @override
  Future<bool> moveToTrash(String ref) => _onRow(ref,
      (c, hit) => c.moveToTrash(hit.message.uid, folderPath: hit.folderPath));

  @override
  Future<bool> archive(String ref) => _onRow(ref,
      (c, hit) => c.moveToArchive(hit.message.uid, folderPath: hit.folderPath));

  @override
  Future<bool> moveToFolder(String ref, String target) => _onRow(
      ref,
      (c, hit) =>
          c.moveToFolder(hit.message.uid, target, folderPath: hit.folderPath));

  /// 列用 ref 指名，動作回到那一封自己的資料夾：跨資料夾搜尋的結果 UID 會撞。
  Future<bool> _onRow(String ref,
      Future<bool> Function(MailController c, MailRef hit) action) async {
    final c = _controller;
    final hit = _memo[ref];
    if (c == null || hit == null) return false;
    return action(c, hit);
  }

  @override
  void startWatch() {
    _arrivals ??= MailWatchController.instance.arrivals.listen(_onArrivals);
    MailWatchController.instance.start();
  }

  @override
  void stopWatch() => MailWatchController.instance.stop();

  @override
  Future<void> restoreOutbox() async {
    final outbox = MailOutboxController.instance;
    _outbox ??= outbox.items.listen((_) => _send(_host.onOutbox(_outboxRows())));
    // 回報不接在清單上：寄完信常常就切去別的分頁，那條提示不該跟著清單消失。
    _results ??=
        outbox.results.listen((result) => _send(_host.onSent(result.sent)));
    await outbox.restore();
  }

  @override
  Future<bool> recall(int id) => MailOutboxController.instance.recall(id);

  @override
  Future<void> retry(int id) => MailOutboxController.instance.retry(id);

  void _onArrivals(List<MailMessageJson> fresh) {
    if (fresh.isEmpty) return;
    const folderPath = MailRepository.inboxPath;
    final newest = fresh.first;
    _send(_host.onArrival(MailArrival(
      title: MailText.arrivalTitle(fresh),
      message: MailText.subjectOf(newest.subject),
      ref: _memo.put('$folderPath/${newest.uid}', folderPath, newest),
    )));
    // 橫幅跳出來、清單卻還是舊的會很怪。搜尋中不重抓：那會把結果換成收件匣。
    final c = _controller;
    if (c != null && !c.isSearching) unawaited(c.load());
  }

  void _queuePush(Object? _) {
    if (_pushQueued) return;
    _pushQueued = true;
    scheduleMicrotask(() {
      _pushQueued = false;
      final c = _controller;
      if (c != null) _send(_host.onList(_stateOf(c)));
    });
  }

  static void _send(Future<void> call) => unawaited(call.catchError(
      (Object e, StackTrace stack) => Log.eWithStack(e.toString(), stack)));

  List<MailOutboxRow> _outboxRows() {
    final outbox = MailOutboxController.instance;
    return [
      for (final item in outbox.items)
        MailOutboxRow(
          id: item.id,
          phase: switch (item.state) {
            MailOutboxState.waiting => MailOutboxPhase.waiting,
            MailOutboxState.sending => MailOutboxPhase.sending,
            MailOutboxState.failed => MailOutboxPhase.failed,
          },
          status: _statusOf(item, outbox.remainingSeconds(item)),
          subject: MailText.subjectOf(item.draft.subject),
          recipients: item.recipientSummary,
        ),
    ];
  }

  /// 到期了但還沒輪到時講「寄送中」，比停在「0 秒後寄出」誠實。
  static String _statusOf(MailOutboxItem item, int remaining) =>
      switch (item.state) {
        MailOutboxState.waiting => remaining <= 0
            ? R.current.mailOutboxSending
            : sprintf(R.current.mailOutboxWaiting, [remaining]),
        MailOutboxState.sending => R.current.mailOutboxSending,
        MailOutboxState.failed => R.current.mailOutboxFailed,
      };

  MailListState _stateOf(MailController c) {
    final searching = c.isSearching;
    // 搜尋中看的是結果，每一筆帶著自己的資料夾；否則是目前資料夾的清單。
    final Result<Object?>? result =
        searching ? c.results.value : c.messages.value;
    final messages = searching ? null : c.messages.value?.dataOrNull;
    final hits = searching ? c.results.value?.dataOrNull : null;
    final folderPath = c.folderPath.value;
    final folders = c.folders.value?.dataOrNull ?? const <MailFolderJson>[];
    // 整份清單共用同一個「現在」，時間欄與分組才是同一個時間點。
    final now = _clock();
    MailRow row(String ref, String folder, MailMessageJson m) => MailRow(
          ref: _memo.put(ref, folder, m),
          uid: m.uid,
          from: m.displayFrom,
          time: MailGroups.formatDate(m.date, now),
          subject: MailText.subjectOf(m.subject),
          unread: !m.seen,
        );
    return MailListState(
      folderPath: folderPath,
      folderTitle: _titleOf(folderPath, folders),
      folders: [
        for (final folder in uniqueMailFoldersByRole(folders))
          MailFolderRow(
            path: folder.path,
            label: mailFolderLabel(folder),
            count: mailFolderCount(folder),
            inbox: folder.role == MailFolderRole.inbox,
            // 目前所在的資料夾一定留著，就算它是空的：它正是打勾的那一個。
            empty: mailFolderIsEmpty(folder) && folder.path != folderPath,
          ),
      ],
      sections: messages == null
          ? const <MailSection>[]
          : [
              for (final group in MailGroups.groupByAge(messages, now))
                MailSection(
                  title: MailGroups.labelOf(group.bucket),
                  rows: [
                    for (final m in group.items)
                      row('$folderPath/${m.uid}', folderPath, m),
                  ],
                ),
            ],
      keyword: searching ? c.keyword.value : null,
      searchAll: c.searchAllFolders.value,
      results: hits == null
          ? const <MailRow>[]
          : [
              for (var i = 0; i < hits.length; i++)
                row('search/$i/${hits[i].message.uid}', hits[i].folderPath,
                    hits[i].message),
            ],
      resultCount: hits != null && hits.isNotEmpty
          ? sprintf(R.current.mailSearchResultCount, [hits.length])
          : null,
      loading: result == null,
      error: result == null ? null : BridgeResults.errorOf(result),
      notice: result == null ? null : BridgeResults.noticeOf(result),
      emptyMessage: hits != null && hits.isEmpty
          ? R.current.mailSearchEmpty
          : messages != null && messages.isEmpty
              ? R.current.mailEmpty
              : null,
      more: !c.hasMore.value
          ? MailMoreState.end
          : c.loadMoreFailed.value
              ? MailMoreState.failed
              : MailMoreState.more,
      needsSetup: switch (result) {
        Failed(:final reason) => reason is NotSignedIn,
        _ => false,
      },
    );
  }

  /// 還沒問到資料夾清單時退回「收件匣」：那是預設打開的那一個，也是唯一保證存在的。
  static String _titleOf(String path, List<MailFolderJson> folders) {
    for (final folder in folders) {
      if (folder.path == path) return mailFolderLabel(folder);
    }
    return R.current.mailFolderInbox;
  }
}
