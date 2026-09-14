import 'dart:io';
import 'dart:isolate';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/native/bridge_results.dart';
import 'package:flutter_app/src/native/mail_memo.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/html_colors.dart';
import 'package:flutter_app/src/util/mail_text.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';

/// 原生版的信件內頁，照 `mail_detail_page.dart`。
class MailMessageBridge implements TatMailMessageApi {
  MailMessageBridge(this._memo);

  static void install(MailMemo memo) =>
      TatMailMessageApi.setUp(MailMessageBridge(memo));

  final MailMemo _memo;

  /// 超過這麼長的內文換一個 isolate 標顏色：公告常夾著幾 MB 的內嵌圖片，
  /// 在這條 isolate 上解析的話其他呼叫都要跟著等。
  static const int _isolateThreshold = 100000;

  @override
  MailHeader? header(String ref) {
    final message = _memo[ref]?.message;
    if (message == null) return null;
    final own = MailConnector.accountToAddress(Model.instance.getAccount())
        .toLowerCase();
    MailAddressLine line(String address) => MailAddressLine(
        address: address, mine: address.trim().toLowerCase() == own);
    final recipients = message.to.length + message.cc.length;
    return MailHeader(
      subject: MailText.subjectOf(message.subject),
      from: message.displayFrom,
      fromEmail: message.fromEmail.isNotEmpty &&
              message.fromEmail != message.displayFrom
          ? message.fromEmail
          : null,
      date: DateFormat('yyyy/MM/dd HH:mm').format(message.date),
      recipientCount: recipients == 0
          ? null
          : sprintf(R.current.mailRecipientCount, [recipients]),
      to: [for (final address in message.to) line(address)],
      cc: [for (final address in message.cc) line(address)],
    );
  }

  @override
  Future<MailBody> body(String ref) async {
    final hit = _memo[ref];
    if (hit == null) return _failed(R.current.mailBodyLoadFailed);
    final result = await MailRepository.instance
        .getContent(hit.message.uid, folderPath: hit.folderPath);
    final content = result.dataOrNull;
    if (content == null) {
      return _failed(
          BridgeResults.errorOf(result) ?? R.current.mailBodyLoadFailed);
    }
    _memo.rememberContent(ref, content);
    final html = content.html;
    return MailBody(
      html: html.length < _isolateThreshold
          ? HtmlColors.markNeutral(html)
          : await Isolate.run(() => HtmlColors.markNeutral(html)),
      attachments: [
        for (final attachment in content.attachments)
          MailAttachmentRow(
            fetchId: attachment.fetchId,
            name: attachment.name,
            meta: MailText.attachmentMeta(attachment),
          ),
      ],
      remoteImages: MailText.hasRemoteImages(html),
    );
  }

  static MailBody _failed(String message) =>
      MailBody(attachments: const [], remoteImages: false, error: message);

  @override
  Future<bool> saveAttachment(
      String ref, String fetchId, String destination) async {
    final hit = _memo[ref];
    if (hit == null) return false;
    final bytes = await MailRepository.instance.fetchAttachment(
        hit.message.uid, fetchId,
        folderPath: hit.folderPath);
    if (bytes == null) return false;
    try {
      await File(destination).writeAsBytes(bytes);
      return true;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return false;
    }
  }

  @override
  Future<void> markSeen(String ref) async {
    final hit = _memo[ref];
    if (hit == null) return;
    await MailRepository.instance
        .setSeen(hit.message.uid, seen: true, folderPath: hit.folderPath);
  }

  @override
  Future<bool> move(String ref, bool archive) async {
    final hit = _memo[ref];
    if (hit == null) return false;
    return archive
        ? MailRepository.instance
            .moveToArchive(hit.message.uid, folderPath: hit.folderPath)
        : MailRepository.instance
            .moveToTrash(hit.message.uid, folderPath: hit.folderPath);
  }
}
