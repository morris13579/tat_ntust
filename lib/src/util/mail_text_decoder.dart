import 'dart:convert';

import 'package:enough_convert/enough_convert.dart';
import 'package:flutter/foundation.dart';

/// 信件文字的解碼。**純函式，測試直接打這裡。**
///
/// 存在的理由是兩個上游缺陷，兩個都只在中文信上發作：
///
/// 1. `enough_convert` 1.6.0 的 Big5 **解碼表少了 14 個碼位**，全部回 U+FFFD。
///    其中 `A7 69`（告）是常用字——校內公告的主旨幾乎都有「公告」兩個字。
///    見 [big5Patch]。
/// 2. `enough_mail` 的 **header Q-encoding 對非 Unicode charset 是全毀的**：
///    它把每個 `=XX` 先當成一個 latin1 字元再拼成字串，等於在 charset 解碼
///    之前就把位元組轉成了字元，Big5 的雙位元組序列整個對不回去。這和
///    docs/WEBMAIL_IMAP.md §5 記的內文 quoted-printable 缺陷是同一類。
///
/// 所以主旨與內文都不再走 `enough_mail` 的解碼，改走這裡。
class MailTextDecoder {
  MailTextDecoder._();

  /// `enough_convert` 的 Big5 表漏掉的碼位，key 是 `lead << 8 | trail`。
  ///
  /// 拿 Python 的 big5 codec 當權威來源，掃過全部 13,710 個合法雙位元組序列
  /// 對照出來的：其餘 13,696 個 `enough_convert` 解得完全正確，只有這 14 個
  /// 回 U+FFFD。它們是 Big5 標準與 ETen 擴充之間那批有爭議的符號，加上一個
  /// 落單的「告」。
  ///
  /// **不要拿 `Big5Codec` 的 encoder 產測試輸入。** 它不是解碼的忠實反函式：
  /// Big5 有一批字對應到兩個碼位（`／` 同時是 A1 FE 與 A2 41），編碼時只會挑
  /// 其中一個，而不在表裡的字直接變成 `?`。13,710 個碼位裡有 289 個轉一圈
  /// 回不到原本的位元組。要產位元組請用權威來源（Python 的 big5 codec）。
  @visibleForTesting
  static const Map<int, String> big5Patch = {
    0xA150: '·',
    0xA1B1: '§',
    0xA1D1: '×',
    0xA1D2: '÷',
    0xA1D3: '±',
    0xA1FE: '／',
    0xA240: '＼',
    0xA244: '¥',
    0xA246: '¢',
    0xA247: '£',
    0xA258: '°',
    0xA2CC: '十',
    0xA2CE: '卅',
    0xA769: '告',
  };

  static const _big5 = Big5Codec(allowInvalid: true);
  static const _gbk = GbkCodec(allowInvalid: true);

  /// Big5 的 lead byte 範圍。
  static const int _leadMin = 0xA1;
  static const int _leadMax = 0xF9;

  /// 補過洞的 Big5 解碼。
  ///
  /// 逐一掃過位元組，只有落在 [big5Patch] 的那 14 個序列自己吐字元，其餘原封
  /// 不動交給 `Big5Codec`——這裡不是要重寫一套 Big5，只是補洞。
  static String big5(List<int> bytes) {
    final out = StringBuffer();
    final pending = <int>[];

    void flush() {
      if (pending.isEmpty) return;
      out.write(_big5.decode(pending));
      pending.clear();
    }

    var i = 0;
    while (i < bytes.length) {
      final lead = bytes[i];
      if (i + 1 < bytes.length && lead >= _leadMin && lead <= _leadMax) {
        final patched = big5Patch[(lead << 8) | bytes[i + 1]];
        if (patched != null) {
          flush();
          out.write(patched);
        } else {
          // **兩個位元組要一起吃掉。** 只前進一格的話，下一輪會把 trail byte
          // 當成 lead 重新判斷——Big5 的 trail 範圍（0xA1–0xFE）和 lead 範圍
          // 是重疊的，那樣會從一個字的中間開始重新斷詞。
          pending
            ..add(lead)
            ..add(bytes[i + 1]);
        }
        i += 2;
        continue;
      }
      pending.add(lead);
      i++;
    }
    flush();
    return out.toString();
  }

  /// 依 charset 把位元組解成字串。認不得的 charset 當成 UTF-8 盡力解——那是
  /// 現在最常見的預設，而且 `allowMalformed` 保證不會丟例外。
  static String bytes(String? charset, List<int> data) {
    switch (charset?.toLowerCase().trim()) {
      case 'big5':
      case 'big-5':
      case 'big5-eten':
      case 'cp950':
      case 'ms950':
        return big5(data);
      case 'gbk':
      case 'gb2312':
      case 'gb_2312-80':
      case 'cp936':
        return _gbk.decode(data);
      case 'iso-8859-1':
      case 'latin1':
      case 'windows-1252':
      case 'us-ascii':
      case 'ascii':
        return latin1.decode(data, allowInvalid: true);
      default:
        return utf8.decode(data, allowMalformed: true);
    }
  }

  /// RFC 2047 的 encoded-word。`=?charset?B?...?=` 與 `=?charset?Q?...?=`。
  static final RegExp _encodedWord =
      RegExp(r'=\?([^?\s]+)\?([BbQq])\?([^?]*)\?=');

  /// 解一整個標頭值（主旨、顯示名稱）。
  ///
  /// 兩件事是天真的實作會做錯的：
  ///
  /// 1. **相鄰的 encoded-word 要先把位元組接起來再解。** 一個 Big5 字是兩個
  ///    位元組，而折行時它可能被切在兩段中間（真實信件裡就有，見
  ///    `test/fixtures/mail/big5_subject.eml`）。逐段解會在接縫處吐替換字元。
  /// 2. **相鄰 encoded-word 之間的空白要吃掉**（RFC 2047 §6.2）——那是折行留
  ///    下來的，不是內容。只有 encoded-word 與**普通文字**之間的空白要留著。
  static String header(String raw) {
    if (raw.isEmpty) return raw;
    if (!raw.contains('=?')) return raw;

    final out = StringBuffer();
    // 累積中的同一組：同一個 charset 的連續 encoded-word。
    String? runCharset;
    final runBytes = <int>[];

    void flushRun() {
      if (runCharset == null) return;
      out.write(bytes(runCharset, runBytes));
      runCharset = null;
      runBytes.clear();
    }

    var cursor = 0;
    for (final match in _encodedWord.allMatches(raw)) {
      final between = raw.substring(cursor, match.start);
      final charset = match.group(1)!;
      final encoding = match.group(2)!.toUpperCase();
      final payload = match.group(3)!;

      // 折行留下的空白：前一段也是 encoded-word 時整段丟掉。
      final foldOnly = between.trim().isEmpty && runCharset != null;
      if (!foldOnly) {
        flushRun();
        out.write(between);
      }

      final decoded = encoding == 'B' ? _base64(payload) : _qEncoded(payload);
      if (decoded == null) {
        // 解不開就原樣留著，總比吞掉一段主旨好。
        flushRun();
        out.write(match.group(0));
        cursor = match.end;
        continue;
      }
      if (runCharset != null &&
          runCharset!.toLowerCase() != charset.toLowerCase()) {
        flushRun();
      }
      runCharset = charset;
      runBytes.addAll(decoded);
      cursor = match.end;
    }

    flushRun();
    out.write(raw.substring(cursor));
    return out.toString();
  }

  /// base64 payload → 位元組。解不開回 null。
  ///
  /// 補回被省略的 `=` padding：實測有信件的 encoded-word 沒有補齊。
  static List<int>? _base64(String payload) {
    final cleaned = payload.replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return const [];
    final padded = cleaned.padRight((cleaned.length + 3) ~/ 4 * 4, '=');
    try {
      return base64.decode(padded);
    } catch (_) {
      return null;
    }
  }

  /// Q-encoding payload → 位元組。
  ///
  /// **一定要出位元組而不是字串。** `enough_mail` 的缺陷正是在這一步就把
  /// `=XX` 變成 latin1 字元，等 charset codec 拿到時雙位元組序列已經散掉了。
  static List<int> _qEncoded(String payload) {
    final out = <int>[];
    for (var i = 0; i < payload.length; i++) {
      final ch = payload[i];
      if (ch == '_') {
        out.add(0x20); // Q-encoding 的底線就是空白。
        continue;
      }
      if (ch == '=' && i + 2 < payload.length) {
        final hex = payload.substring(i + 1, i + 3);
        final value = int.tryParse(hex, radix: 16);
        if (value != null) {
          out.add(value);
          i += 2;
          continue;
        }
      }
      // 沒有被編碼的字元本來就是 ASCII，直接取碼位。
      out.addAll(utf8.encode(ch));
    }
    return out;
  }
}
