import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'dart:io';

import 'package:flutter_app/src/model/mail/mail_contact.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/model/mail/mail_outbox_item.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:sqflite/sqflite.dart';

/// 信件的本機快取。
///
/// **為什麼是 SQLite 而不是 `CacheKey`**：`CacheStore` 底下是 SharedPreferences
/// 的單一 JSON blob，每次讀寫都要把整包序列化一遍。信件是會長大的東西——一個
/// 資料夾放幾百封，加上多個資料夾，那包 blob 每次開頁都要整份解一次。改成一張
/// 表之後，讀某個資料夾就只讀那個資料夾，改一封信的已讀旗標也只寫那一列。
///
/// 抽成介面加靜態 `instance` 的理由同 [SecureStore]：sqflite 要平台通道，
/// 測試不該碰它。
abstract class MailStore {
  static MailStore instance = SqfliteMailStore();

  /// 某個資料夾的信，日期新到舊。
  Future<List<MailMessageJson>> readMessages(String folderPath);

  /// 整批換掉某個資料夾的信。
  ///
  /// 是「換掉」不是「合併」：伺服器沒有 `CONDSTORE`，我們拿不到差異，只能以
  /// 這次抓回來的那一批為準。合併的話伺服器端已刪除的信會永遠留在本機。
  Future<void> replaceMessages(
      String folderPath, List<MailMessageJson> messages);

  /// 往資料夾裡「加」信，不動既有的那些。給第二頁以後用。
  ///
  /// 和 [replaceMessages] 是兩種語意，不要混用：第一頁用 replace（以伺服器
  /// 那一批為準，已刪除的信才會從本機消失），之後的頁用這一個（第二頁不該
  /// 把第一頁刪掉）。
  Future<void> appendMessages(
      String folderPath, List<MailMessageJson> messages);

  /// 這個資料夾快取當下的 `UIDVALIDITY`。沒存過回 null。
  Future<int?> readUidValidity(String folderPath);

  /// 記下 `UIDVALIDITY`。變了就代表伺服器把 UID 全部作廢了，呼叫端要把這個
  /// 資料夾的快取整個丟掉——那是唯一能防「顯示到別封信」的機制。
  Future<void> writeUidValidity(String folderPath, int uidValidity);

  /// 只改一封信的已讀旗標。標記已讀不該讓整批重寫。
  Future<void> updateSeen(String folderPath, int uid, {required bool seen});

  Future<void> deleteMessage(String folderPath, int uid);

  Future<List<MailFolderJson>> readFolders();

  Future<void> replaceFolders(List<MailFolderJson> folders);

  /// 記下這些人出現過。已經有的那筆只更新名字與時間，`sentCount` 是累加的。
  ///
  /// 同一個位址寫第二次不該變成兩列，所以實作用 UPSERT 而不是 INSERT。
  Future<void> rememberContacts(List<MailContact> contacts);

  /// 收件者欄的自動完成。`query` 比對位址與顯示名稱，不分大小寫。
  ///
  /// 排序是「寄過幾次」優先，再看最後出現的時間——寄過的人比只寄信來過的人
  /// 更可能是這次要找的對象。
  Future<List<MailContact>> searchContacts(String query, {int limit = 6});

  /// 把一封信排進寄件匣，回新的 id。
  Future<int> enqueueOutbox(MailDraft draft);

  /// 寄件匣裡全部的信，排進來的順序。
  Future<List<MailOutboxItem>> readOutbox();

  /// 改一封的狀態。`attempts` 與 `lastError` 沒給就不動。
  Future<void> updateOutbox(int id, MailOutboxState state,
      {int? attempts, String? lastError});

  /// 從寄件匣移掉。寄成功與使用者收回走的是同一條路。
  Future<void> deleteOutbox(int id);

  /// 登出時清空。漏掉這一步，換帳號之後 B 會看到 A 的信。
  Future<void> clear();
}

class SqfliteMailStore extends MailStore {
  SqfliteMailStore();

  static const _dbName = 'mail.db';
  static const _messages = 'messages';
  static const _folders = 'folders';
  static const _folderState = 'folder_state';
  static const _contacts = 'contacts';
  static const _outbox = 'outbox';

  Database? _db;

  /// 每次改動 schema 都要加一。這是純快取，升版一律砍掉重建——沒有任何一列
  /// 是唯一來源，重抓的代價是一次連線。忘了加的話既有安裝會停在舊 schema，
  /// 新欄位的 INSERT 會整批失敗而且只留下一行 log。
  /// 3：資料夾的 `path` 從「解碼後的中文」改成 wire 上的 modified UTF-7
  /// （見 MailConnector.fetchFolders）。舊快取裡的中文 path 拿去 SELECT 一定
  /// 失敗，升版直接丟掉重抓。
  ///
  /// 4：多一張 `folder_state` 記 `UIDVALIDITY`。分頁之後本機快取會跨 session
  /// 累積，而 UID 只在 `UIDVALIDITY` 沒變的前提下有效——不存它，伺服器重建
  /// 資料夾之後我們會拿舊 UID 去顯示完全不同的信。
  ///
  /// 5：多一張 `contacts` 給收件者欄的自動完成。
  ///
  /// 6：多一張 `outbox`。**這一張不是純快取**——裡面是還沒寄出去的信，升版
  /// 砍掉會把使用者寫好的信弄不見。目前 5→6 只是新增，沒有破壞性變更；真要
  /// 改它的 schema 時必須改成逐版遷移而不是 DROP。
  static const int _version = 6;

  Future<Database> get _database async => _db ??= await openDatabase(
        _dbName,
        version: _version,
        onUpgrade: (db, from, to) async {
          await db.execute('DROP TABLE IF EXISTS $_messages');
          await db.execute('DROP TABLE IF EXISTS $_folders');
          await db.execute('DROP TABLE IF EXISTS $_folderState');
          await db.execute('DROP TABLE IF EXISTS $_contacts');
          // outbox 刻意不 DROP：見 [_version] 的註解。
          await _createSchema(db);
        },
        onCreate: (db, version) => _createSchema(db),
      );

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
            CREATE TABLE $_folderState (
              folder_path TEXT PRIMARY KEY,
              uid_validity INTEGER NOT NULL
            )
          ''');
    // folder_path + uid 才是主鍵：UID 只在資料夾內唯一。
    await db.execute('''
            CREATE TABLE $_messages (
              folder_path TEXT NOT NULL,
              uid INTEGER NOT NULL,
              subject TEXT NOT NULL DEFAULT '',
              from_name TEXT NOT NULL DEFAULT '',
              from_email TEXT NOT NULL DEFAULT '',
              date_millis INTEGER NOT NULL DEFAULT 0,
              seen INTEGER NOT NULL DEFAULT 0,
              to_addrs TEXT NOT NULL DEFAULT '',
              cc_addrs TEXT NOT NULL DEFAULT '',
              PRIMARY KEY (folder_path, uid)
            )
          ''');
    // 每次開頁都是「某個資料夾、依日期新到舊」，這個索引直接對上。
    await db.execute('CREATE INDEX idx_messages_folder_date ON $_messages '
        '(folder_path, date_millis DESC)');
    // email 當主鍵：寫進來之前一律 toLowerCase，同一個人用 `Prof@` 和 `prof@`
    // 寄信不該變成兩筆。這張表只有幾百列，除了主鍵不需要別的索引。
    await db.execute('''
            CREATE TABLE $_contacts (
              email TEXT PRIMARY KEY,
              name TEXT NOT NULL DEFAULT '',
              last_seen_millis INTEGER NOT NULL DEFAULT 0,
              sent_count INTEGER NOT NULL DEFAULT 0
            )
          ''');
    await db.execute('''
            CREATE TABLE IF NOT EXISTS $_outbox (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              to_addrs TEXT NOT NULL DEFAULT '',
              cc_addrs TEXT NOT NULL DEFAULT '',
              bcc_addrs TEXT NOT NULL DEFAULT '',
              subject TEXT NOT NULL DEFAULT '',
              body TEXT NOT NULL DEFAULT '',
              attachments TEXT NOT NULL DEFAULT '',
              in_reply_to_uid INTEGER,
              state INTEGER NOT NULL DEFAULT 0,
              created_millis INTEGER NOT NULL DEFAULT 0,
              attempts INTEGER NOT NULL DEFAULT 0,
              last_error TEXT NOT NULL DEFAULT ''
            )
          ''');
    await db.execute('''
            CREATE TABLE $_folders (
              path TEXT PRIMARY KEY,
              name TEXT NOT NULL DEFAULT '',
              role INTEGER NOT NULL DEFAULT 0,
              sort_index INTEGER NOT NULL DEFAULT 0,
              message_count INTEGER NOT NULL DEFAULT -1,
              unread_count INTEGER NOT NULL DEFAULT -1
            )
          ''');
  }

  /// 位址清單存成用 `\n` 隔開的字串。
  ///
  /// 不另外開一張表：這兩欄只有「全部回覆」會讀，從來不用來查詢，拆表換來的
  /// 是每次讀信都多一次 join。分隔符用 `\n` 而不是逗號——位址本身不會有換行，
  /// 顯示名稱裡的逗號卻很常見。
  static String _joinAddresses(List<String> list) => list.join('\n');

  static List<String> _splitAddresses(String raw) =>
      raw.isEmpty ? const [] : raw.split('\n');

  Map<String, Object?> _toRow(String folderPath, MailMessageJson m) => {
        'folder_path': folderPath,
        'uid': m.uid,
        'subject': m.subject,
        'from_name': m.fromName,
        'from_email': m.fromEmail,
        'date_millis': m.dateMillis,
        'seen': m.seen ? 1 : 0,
        'to_addrs': _joinAddresses(m.to),
        'cc_addrs': _joinAddresses(m.cc),
      };

  MailMessageJson _fromRow(Map<String, Object?> row) => MailMessageJson(
        uid: row['uid'] as int,
        subject: row['subject'] as String? ?? '',
        fromName: row['from_name'] as String? ?? '',
        fromEmail: row['from_email'] as String? ?? '',
        dateMillis: row['date_millis'] as int? ?? 0,
        seen: (row['seen'] as int? ?? 0) == 1,
        to: _splitAddresses(row['to_addrs'] as String? ?? ''),
        cc: _splitAddresses(row['cc_addrs'] as String? ?? ''),
      );

  @override
  Future<List<MailMessageJson>> readMessages(String folderPath) async {
    try {
      final db = await _database;
      final rows = await db.query(_messages,
          where: 'folder_path = ?',
          whereArgs: [folderPath],
          orderBy: 'date_millis DESC');
      return rows.map(_fromRow).toList();
    } catch (e, stack) {
      // 快取讀不到不是致命的，照樣可以打網路。
      Log.eWithStack('mail store readMessages failed: $e', stack);
      return const [];
    }
  }

  @override
  Future<void> replaceMessages(
      String folderPath, List<MailMessageJson> messages) async {
    try {
      final db = await _database;
      // 刪除與寫入必須是同一個交易：中途失敗留下半份清單，比沒有快取更糟。
      await db.transaction((txn) async {
        await txn.delete(_messages,
            where: 'folder_path = ?', whereArgs: [folderPath]);
        final batch = txn.batch();
        for (final message in messages) {
          batch.insert(_messages, _toRow(folderPath, message),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
    } catch (e, stack) {
      Log.eWithStack('mail store replaceMessages failed: $e', stack);
    }
  }

  @override
  Future<void> appendMessages(
      String folderPath, List<MailMessageJson> messages) async {
    try {
      final db = await _database;
      final batch = db.batch();
      for (final message in messages) {
        batch.insert(_messages, _toRow(folderPath, message),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e, stack) {
      Log.eWithStack('mail store appendMessages failed: $e', stack);
    }
  }

  @override
  Future<int?> readUidValidity(String folderPath) async {
    try {
      final db = await _database;
      final rows = await db.query(_folderState,
          columns: ['uid_validity'],
          where: 'folder_path = ?',
          whereArgs: [folderPath],
          limit: 1);
      if (rows.isEmpty) return null;
      return rows.first['uid_validity'] as int?;
    } catch (e, stack) {
      Log.eWithStack('mail store readUidValidity failed: $e', stack);
      return null;
    }
  }

  @override
  Future<void> writeUidValidity(String folderPath, int uidValidity) async {
    try {
      final db = await _database;
      await db.insert(_folderState,
          {'folder_path': folderPath, 'uid_validity': uidValidity},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, stack) {
      Log.eWithStack('mail store writeUidValidity failed: $e', stack);
    }
  }

  @override
  Future<void> updateSeen(String folderPath, int uid,
      {required bool seen}) async {
    try {
      final db = await _database;
      await db.update(_messages, {'seen': seen ? 1 : 0},
          where: 'folder_path = ? AND uid = ?', whereArgs: [folderPath, uid]);
    } catch (e, stack) {
      Log.eWithStack('mail store updateSeen failed: $e', stack);
    }
  }

  @override
  Future<void> deleteMessage(String folderPath, int uid) async {
    try {
      final db = await _database;
      await db.delete(_messages,
          where: 'folder_path = ? AND uid = ?', whereArgs: [folderPath, uid]);
    } catch (e, stack) {
      Log.eWithStack('mail store deleteMessage failed: $e', stack);
    }
  }

  @override
  Future<List<MailFolderJson>> readFolders() async {
    try {
      final db = await _database;
      final rows = await db.query(_folders, orderBy: 'sort_index ASC');
      return [
        for (final row in rows)
          MailFolderJson(
            path: row['path'] as String,
            name: row['name'] as String? ?? '',
            role: MailFolderRole.values[row['role'] as int? ?? 0],
            messageCount: row['message_count'] as int? ?? -1,
            unreadCount: row['unread_count'] as int? ?? -1,
          ),
      ];
    } catch (e, stack) {
      Log.eWithStack('mail store readFolders failed: $e', stack);
      return const [];
    }
  }

  @override
  Future<void> replaceFolders(List<MailFolderJson> folders) async {
    try {
      final db = await _database;
      await db.transaction((txn) async {
        await txn.delete(_folders);
        final batch = txn.batch();
        for (var i = 0; i < folders.length; i++) {
          batch.insert(
              _folders,
              {
                'path': folders[i].path,
                'name': folders[i].name,
                'role': folders[i].role.index,
                'sort_index': i,
                'message_count': folders[i].messageCount,
                'unread_count': folders[i].unreadCount,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
    } catch (e, stack) {
      Log.eWithStack('mail store replaceFolders failed: $e', stack);
    }
  }

  @override
  Future<void> rememberContacts(List<MailContact> contacts) async {
    if (contacts.isEmpty) return;
    try {
      final db = await _database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final c in contacts) {
          final email = c.email.trim().toLowerCase();
          if (email.isEmpty) continue;
          // UPSERT 而不是 REPLACE：REPLACE 會把既有那列整個換掉，寄過幾次的
          // 計數就歸零了。名字只在新的那份非空時才蓋過去——很多系統信沒有
          // 顯示名稱，拿它去覆蓋已經存好的名字是退步。
          batch.rawInsert(
            'INSERT INTO $_contacts (email, name, last_seen_millis, sent_count) '
            'VALUES (?, ?, ?, ?) '
            'ON CONFLICT(email) DO UPDATE SET '
            '  name = CASE WHEN excluded.name != \'\' THEN excluded.name '
            '              ELSE $_contacts.name END, '
            '  last_seen_millis = MAX($_contacts.last_seen_millis, excluded.last_seen_millis), '
            '  sent_count = $_contacts.sent_count + excluded.sent_count',
            [email, c.name, c.lastSeenMillis, c.sentCount],
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e, stack) {
      Log.eWithStack('mail store rememberContacts failed: $e', stack);
    }
  }

  @override
  Future<List<MailContact>> searchContacts(String query,
      {int limit = 6}) async {
    try {
      final db = await _database;
      final like = '%${query.trim().toLowerCase()}%';
      final rows = await db.rawQuery(
        'SELECT * FROM $_contacts '
        'WHERE LOWER(email) LIKE ? OR LOWER(name) LIKE ? '
        'ORDER BY sent_count DESC, last_seen_millis DESC '
        'LIMIT ?',
        [like, like, limit],
      );
      return rows
          .map((r) => MailContact(
                email: r['email'] as String,
                name: r['name'] as String? ?? '',
                lastSeenMillis: r['last_seen_millis'] as int? ?? 0,
                sentCount: r['sent_count'] as int? ?? 0,
              ))
          .toList();
    } catch (e, stack) {
      Log.eWithStack('mail store searchContacts failed: $e', stack);
      return const [];
    }
  }

  @override
  Future<int> enqueueOutbox(MailDraft draft) async {
    try {
      final db = await _database;
      return await db.insert(_outbox, {
        'to_addrs': _joinAddresses(draft.to),
        'cc_addrs': _joinAddresses(draft.cc),
        'bcc_addrs': _joinAddresses(draft.bcc),
        'subject': draft.subject,
        'body': draft.body,
        // 附件存路徑而不是內容。使用者在寄出前把檔案刪掉就會寄失敗，那一列
        // 會留著講原因——把幾十 MB 的附件複製進 SQLite 的代價大得多。
        'attachments':
            _joinAddresses(draft.attachments.map((f) => f.path).toList()),
        'in_reply_to_uid': draft.inReplyToUid,
        'state': MailOutboxState.waiting.index,
        'created_millis': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, stack) {
      Log.eWithStack('mail store enqueueOutbox failed: $e', stack);
      return -1;
    }
  }

  @override
  Future<List<MailOutboxItem>> readOutbox() async {
    try {
      final db = await _database;
      final rows = await db.query(_outbox, orderBy: 'id ASC');
      return rows.map(_outboxFromRow).toList();
    } catch (e, stack) {
      Log.eWithStack('mail store readOutbox failed: $e', stack);
      return const [];
    }
  }

  @override
  Future<void> updateOutbox(int id, MailOutboxState state,
      {int? attempts, String? lastError}) async {
    try {
      final db = await _database;
      await db.update(
        _outbox,
        {
          'state': state.index,
          if (attempts != null) 'attempts': attempts,
          if (lastError != null) 'last_error': lastError,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e, stack) {
      Log.eWithStack('mail store updateOutbox failed: $e', stack);
    }
  }

  @override
  Future<void> deleteOutbox(int id) async {
    try {
      final db = await _database;
      await db.delete(_outbox, where: 'id = ?', whereArgs: [id]);
    } catch (e, stack) {
      Log.eWithStack('mail store deleteOutbox failed: $e', stack);
    }
  }

  static MailOutboxItem _outboxFromRow(Map<String, Object?> row) =>
      MailOutboxItem(
        id: row['id'] as int,
        draft: MailDraft(
          to: _splitAddresses(row['to_addrs'] as String? ?? ''),
          cc: _splitAddresses(row['cc_addrs'] as String? ?? ''),
          bcc: _splitAddresses(row['bcc_addrs'] as String? ?? ''),
          subject: row['subject'] as String? ?? '',
          body: row['body'] as String? ?? '',
          attachments: _splitAddresses(row['attachments'] as String? ?? '')
              .map(File.new)
              .toList(),
          inReplyToUid: row['in_reply_to_uid'] as int?,
        ),
        state: MailOutboxState.values[(row['state'] as int? ?? 0)
            .clamp(0, MailOutboxState.values.length - 1)],
        createdMillis: row['created_millis'] as int? ?? 0,
        attempts: row['attempts'] as int? ?? 0,
        lastError: row['last_error'] as String? ?? '',
      );

  @override
  Future<void> clear() async {
    try {
      final db = await _database;
      await db.delete(_messages);
      await db.delete(_folders);
      await db.delete(_folderState);
      // 通訊紀錄也要清。留著等於換帳號之後 B 打兩個字就跳出 A 的聯絡人。
      await db.delete(_contacts);
      // 還沒寄出去的信也一樣：那是上一個帳號的人要寄的，換帳號之後繼續寄
      // 等於用 B 的身分寄 A 寫的信。
      await db.delete(_outbox);
    } catch (e, stack) {
      Log.eWithStack('mail store clear failed: $e', stack);
    }
  }
}

/// 測試用。不碰平台通道。
class InMemoryMailStore extends MailStore {
  final Map<String, List<MailMessageJson>> messages = {};
  List<MailFolderJson> folders = [];

  @override
  Future<List<MailMessageJson>> readMessages(String folderPath) async =>
      List.of(messages[folderPath] ?? const []);

  @override
  Future<void> replaceMessages(
          String folderPath, List<MailMessageJson> list) async =>
      messages[folderPath] = List.of(list);

  final Map<String, int> uidValidity = {};

  @override
  Future<void> appendMessages(
      String folderPath, List<MailMessageJson> list) async {
    final existing = messages.putIfAbsent(folderPath, () => []);
    for (final m in list) {
      final i = existing.indexWhere((e) => e.uid == m.uid);
      if (i >= 0) {
        existing[i] = m;
      } else {
        existing.add(m);
      }
    }
  }

  @override
  Future<int?> readUidValidity(String folderPath) async =>
      uidValidity[folderPath];

  @override
  Future<void> writeUidValidity(String folderPath, int value) async =>
      uidValidity[folderPath] = value;

  @override
  Future<void> updateSeen(String folderPath, int uid,
      {required bool seen}) async {
    final list = messages[folderPath];
    if (list == null) return;
    final i = list.indexWhere((m) => m.uid == uid);
    if (i >= 0) list[i] = list[i].copyWith(seen: seen);
  }

  @override
  Future<void> deleteMessage(String folderPath, int uid) async =>
      messages[folderPath]?.removeWhere((m) => m.uid == uid);

  @override
  Future<List<MailFolderJson>> readFolders() async => List.of(folders);

  @override
  Future<void> replaceFolders(List<MailFolderJson> list) async =>
      folders = List.of(list);

  final Map<int, MailOutboxItem> outbox = {};
  int _nextOutboxId = 1;

  @override
  Future<int> enqueueOutbox(MailDraft draft) async {
    final id = _nextOutboxId++;
    outbox[id] = MailOutboxItem(
      id: id,
      draft: draft,
      state: MailOutboxState.waiting,
      createdMillis: DateTime.now().millisecondsSinceEpoch,
    );
    return id;
  }

  @override
  Future<List<MailOutboxItem>> readOutbox() async =>
      outbox.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  @override
  Future<void> updateOutbox(int id, MailOutboxState state,
      {int? attempts, String? lastError}) async {
    final item = outbox[id];
    if (item == null) return;
    outbox[id] =
        item.copyWith(state: state, attempts: attempts, lastError: lastError);
  }

  @override
  Future<void> deleteOutbox(int id) async => outbox.remove(id);

  @override
  Future<void> clear() async {
    messages.clear();
    folders = [];
    uidValidity.clear();
    contacts.clear();
    outbox.clear();
  }

  final Map<String, MailContact> contacts = {};

  @override
  Future<void> rememberContacts(List<MailContact> list) async {
    for (final c in list) {
      final email = c.email.trim().toLowerCase();
      if (email.isEmpty) continue;
      final old = contacts[email];
      contacts[email] = MailContact(
        email: email,
        name: c.name.isNotEmpty ? c.name : (old?.name ?? ''),
        lastSeenMillis: old == null
            ? c.lastSeenMillis
            : (c.lastSeenMillis > old.lastSeenMillis
                ? c.lastSeenMillis
                : old.lastSeenMillis),
        sentCount: (old?.sentCount ?? 0) + c.sentCount,
      );
    }
  }

  @override
  Future<List<MailContact>> searchContacts(String query,
      {int limit = 6}) async {
    final needle = query.trim().toLowerCase();
    final hits = contacts.values
        .where((c) =>
            c.email.toLowerCase().contains(needle) ||
            c.name.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) {
        final bySent = b.sentCount.compareTo(a.sentCount);
        return bySent != 0
            ? bySent
            : b.lastSeenMillis.compareTo(a.lastSeenMillis);
      });
    return hits.take(limit).toList();
  }
}
