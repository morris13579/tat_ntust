import 'package:flutter_app/src/controller/mail/mail_controller.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/model/mail/mail_page.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/reset_statics.dart';

class _FakeRepo extends MailRepository {
  List<MailMessageJson> inbox = [];
  List<MailMessageJson> searchResult = [];
  int? unread;
  String? lastFolder;
  String? lastKeyword;
  bool seenSucceeds = true;
  bool trashSucceeds = true;
  int seenCalls = 0;
  MailPage? nextPage;
  int? lastBeforeUid;
  String? lastMoveTarget;
  bool moveSucceeds = true;

  @override
  Future<MailPage?> loadMore(String folderPath, int beforeUid) async {
    lastBeforeUid = beforeUid;
    return nextPage;
  }

  @override
  Future<bool> moveToFolder(int uid, String targetPath,
      {String folderPath = MailRepository.inboxPath}) async {
    lastMoveTarget = targetPath;
    return moveSucceeds;
  }

  @override
  Future<Result<List<MailMessageJson>>> getMessages(
          [String folderPath = MailRepository.inboxPath]) async =>
      Ok(inbox);

  @override
  Future<List<MailMessageJson>> cachedMessages(
          [String folderPath = MailRepository.inboxPath]) async =>
      const [];

  @override
  Future<bool> setSeen(int uid,
      {required bool seen,
      String folderPath = MailRepository.inboxPath}) async {
    seenCalls++;
    return seenSucceeds;
  }

  @override
  Future<bool> moveToTrash(int uid,
          {String folderPath = MailRepository.inboxPath}) async =>
      trashSucceeds;

  List<String>? lastSearchAllPaths;

  @override
  Future<Result<List<MailMessageJson>>> search(String keyword,
      {String folderPath = MailRepository.inboxPath,
      List<String>? allFolderPaths}) async {
    lastKeyword = keyword;
    lastFolder = folderPath;
    lastSearchAllPaths = allFolderPaths;
    return Ok(searchResult);
  }

  @override
  Future<int?> unreadCount(
          [String folderPath = MailRepository.inboxPath]) async =>
      unread;
}

MailMessageJson message(int uid, {bool seen = false}) =>
    MailMessageJson(uid: uid, subject: '主旨 $uid', seen: seen);

void main() {
  late _FakeRepo repo;
  late MailController controller;

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MailRepository.instance = repo;
    controller = MailController();
    CredentialsStore.instance.setMailPassword('mail-pw');
  });

  tearDown(() {
    controller.dispose();
    MailRepository.instance = MailRepository();
  });

  test('密碼沒設定時 needsPassword 為真', () {
    CredentialsStore.instance.setMailPassword('');
    expect(controller.needsPassword, isTrue);

    CredentialsStore.instance.setMailPassword('mail-pw');
    expect(controller.needsPassword, isFalse);
  });

  test('markSeen 就地改那一列，不重抓整批', () async {
    // 伺服器沒有 CONDSTORE，重抓等於把整批 envelope 再拉一次；只改一顆旗標
    // 不值得。
    repo.inbox = [message(1), message(2)];
    await controller.load();

    await controller.markSeen(2);

    final list = controller.messages.value!.dataOrNull!;
    expect(list.map((m) => m.uid), [1, 2], reason: '順序不能被改動');
    expect(list[0].seen, isFalse);
    expect(list[1].seen, isTrue);
  });

  test('已經是已讀就不再打伺服器', () async {
    repo.inbox = [message(1, seen: true)];
    await controller.load();

    await controller.markSeen(1);

    expect(repo.seenCalls, 0);
  });

  test('markSeen 失敗時畫面不動，留給下一次重新整理去對齊', () async {
    repo.inbox = [message(1)];
    await controller.load();
    repo.seenSucceeds = false;

    await controller.markSeen(1);

    expect(controller.messages.value!.dataOrNull!.single.seen, isFalse);
  });

  test('moveToTrash 成功就把那一列拿掉', () async {
    repo.inbox = [message(1), message(2)];
    await controller.load();

    expect(await controller.moveToTrash(1), isTrue);
    expect(controller.messages.value!.dataOrNull!.map((m) => m.uid), [2]);
  });

  test('moveToTrash 失敗時那一列要留著', () async {
    // 沒有 MOVE，刪除是 COPY→STORE→EXPUNGE 三步；失敗時信還在伺服器上，
    // 畫面先拿掉會讓使用者以為刪成功了。
    repo.inbox = [message(1), message(2)];
    await controller.load();
    repo.trashSucceeds = false;

    expect(await controller.moveToTrash(1), isFalse);
    expect(controller.messages.value!.dataOrNull!.map((m) => m.uid), [1, 2]);
  });

  test('換資料夾會清掉關鍵字', () async {
    // 留著舊關鍵字會讓人以為換資料夾沒生效——看到的還是搜尋結果。
    repo.searchResult = [message(9)];
    await controller.searchFor('公告');
    expect(controller.isSearching, isTrue);

    await controller.openFolder('寄件備份匣');

    expect(controller.isSearching, isFalse);
    expect(controller.folderPath.value, '寄件備份匣');
  });

  test('有關鍵字時走搜尋，沒有時走資料夾清單', () async {
    repo.inbox = [message(1)];
    repo.searchResult = [message(2)];

    await controller.load();
    expect(controller.messages.value!.dataOrNull!.single.uid, 1);

    await controller.searchFor('  公告  ');
    expect(repo.lastKeyword, '公告', reason: '前後空白要修掉');
    expect(controller.messages.value!.dataOrNull!.single.uid, 2);
  });

  test('搜尋會帶著目前的資料夾', () async {
    await controller.openFolder('回收筒');
    await controller.searchFor('通知');

    expect(repo.lastFolder, '回收筒');
  });

  test('標記已讀會把未讀數減一，但不會減成負的', () async {
    repo.inbox = [message(1), message(2)];
    repo.unread = 1;
    await controller.load();

    await controller.markSeen(1);
    expect(controller.unread.value, 0);

    await controller.markSeen(2);
    expect(controller.unread.value, 0, reason: '已經是 0 就不要再減');
  });

  test('拿不到未讀數時維持 null，不要顯示 0 騙人', () async {
    repo.unread = null;
    await controller.load();

    expect(controller.unread.value, isNull);
  });

  test('清單還沒載入時 markSeen 不會炸', () async {
    await controller.markSeen(1);

    expect(controller.messages.value, isNull);
    expect(repo.seenCalls, 0);
  });

  group('分頁', () {
    test('這一輪失敗就閂住：捲動不會一路重連', () async {
      // 捲到底自動載入之後，一次拖曳會發幾十個捲動事件。失敗時如果不閂住，
      // 每一個都會再開一次連線加一次 SEARCH ALL——斷線時就是無限重連。
      repo.inbox = [message(20)];
      await controller.load();

      repo.nextPage = null;
      await controller.loadMore();

      expect(controller.loadMoreFailed.value, isTrue);
      expect(controller.hasMore.value, isTrue, reason: '還有沒有更舊的信仍然未知');
    });

    test('使用者自己按下去時，閂解得開', () async {
      // 閂是給自動觸發用的；底下那一列的按鈕必須照樣打得出去。
      repo.inbox = [message(20)];
      await controller.load();
      repo.nextPage = null;
      await controller.loadMore();

      repo.nextPage =
          MailPage(messages: [message(9)], hasMore: false, uidValidity: 1);
      await controller.loadMore();

      expect(controller.loadMoreFailed.value, isFalse);
      expect(controller.messages.value!.dataOrNull!.map((m) => m.uid), [20, 9]);
    });

    test('重新整理把游標與閂一起歸零', () async {
      // getMessages 會把清單截回第一頁，游標不跟著回去的話，載到底過的資料夾
      // 重新整理完只剩 50 封，卻永遠說「沒有更舊的信了」。
      repo.inbox = [message(20)];
      await controller.load();
      repo.nextPage =
          const MailPage(messages: [], hasMore: false, uidValidity: 1);
      await controller.loadMore();
      expect(controller.hasMore.value, isFalse);

      await controller.load();

      expect(controller.hasMore.value, isTrue);
      expect(controller.loadMoreFailed.value, isFalse);
    });

    test('中途重新整理過，飛回來的那一頁就丟掉', () async {
      // 不丟的話會拿舊清單去接，剛被刪掉的信會整批復活。
      repo.inbox = [message(20), message(15)];
      await controller.load();

      repo.nextPage =
          MailPage(messages: [message(9)], hasMore: true, uidValidity: 1);
      final pending = controller.loadMore();
      repo.inbox = [message(21)];
      await controller.load();
      await pending;

      expect(controller.messages.value!.dataOrNull!.map((m) => m.uid), [21],
          reason: '那一頁是上一份清單的續集，不該接在新清單後面');
    });

    test('游標是清單裡最舊的那一封，不是頁碼', () async {
      // 序號會因為新信與 EXPUNGE 整批位移，拿它當游標第二頁會漏信或重複。
      repo.inbox = [message(20), message(15), message(11)];
      await controller.load();

      repo.nextPage =
          MailPage(messages: [message(9)], hasMore: true, uidValidity: 1);
      await controller.loadMore();

      expect(repo.lastBeforeUid, 11);
    });

    test('新的一頁接在後面，不是蓋掉', () async {
      repo.inbox = [message(20)];
      await controller.load();

      repo.nextPage =
          MailPage(messages: [message(9)], hasMore: false, uidValidity: 1);
      await controller.loadMore();

      expect(controller.messages.value?.dataOrNull?.map((m) => m.uid), [20, 9]);
    });

    test('hasMore 由伺服器那一端說了算', () async {
      repo.inbox = [message(20)];
      await controller.load();

      repo.nextPage =
          const MailPage(messages: [], hasMore: false, uidValidity: 1);
      await controller.loadMore();

      expect(controller.hasMore.value, isFalse);
    });

    test('這一輪失敗時 hasMore 不動，使用者可以再按一次', () async {
      repo.inbox = [message(20)];
      await controller.load();

      repo.nextPage = null;
      await controller.loadMore();

      expect(controller.hasMore.value, isTrue);
    });

    test('搜尋中不分頁——那會把搜尋結果和收件匣混在一起', () async {
      repo.inbox = [message(20)];
      await controller.load();
      await controller.searchFor('關鍵字');
      repo.lastBeforeUid = null;

      await controller.loadMore();

      expect(repo.lastBeforeUid, isNull);
    });
  });

  group('標記未讀', () {
    test('標回未讀時未讀數要加回去', () async {
      repo.inbox = [message(1)];
      repo.unread = 3;
      await controller.load();
      await controller.markSeen(1);
      expect(controller.unread.value, 2);

      await controller.setSeen(1, seen: false);

      expect(controller.unread.value, 3);
      expect(controller.messages.value?.dataOrNull?.single.seen, isFalse);
    });

    test('狀態沒變就不發請求', () async {
      repo.inbox = [message(1)];
      await controller.load();
      final before = repo.seenCalls;

      await controller.setSeen(1, seen: false);

      expect(repo.seenCalls, before);
    });
  });

  test('移到資料夾成功後那一列就不在清單裡了', () async {
    repo.inbox = [message(1), message(2)];
    await controller.load();

    await controller.moveToFolder(1, '&Vt5lNntS-');

    expect(repo.lastMoveTarget, '&Vt5lNntS-');
    expect(controller.messages.value?.dataOrNull?.map((m) => m.uid), [2]);
  });
}
