import 'dart:io';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/mail_config.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/native/mail_memo.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/mail_address.dart';
import 'package:flutter_app/src/util/mail_text.dart';
import 'package:flutter_app/src/util/rich_editor_bridge_utils.dart';

/// 原生版的寫信頁，照 `mail_compose_page.dart` 與 `mail_recipient_field.dart`。
class MailComposeBridge implements TatMailComposeApi {
  MailComposeBridge(this._memo);

  static void install(MailMemo memo) =>
      TatMailComposeApi.setUp(MailComposeBridge(memo));

  final MailMemo _memo;

  /// 這一次帶進編輯器的內容。**編輯器還沒接上時拿不到內容不是空內容**，
  /// 寄出時退回它，不然回信的引言會整段不見。
  String _initialHtml = '';

  /// 一次最多挑幾個檔，照 `FilePickService.pick(limit: 5)`。
  static const int pickLimit = 5;

  @override
  MailComposeStart start(MailComposeKind kind, String ref) {
    final message = kind == MailComposeKind.blank ? null : _memo[ref]?.message;
    final html = _memo.contentOf(ref)?.html ?? '';
    final quoted =
        html.isEmpty ? '' : MailText.quote(MailConnector.htmlToPlainText(html));
    _initialHtml = message == null
        ? ''
        : '<p></p>${MailConnector.plainTextToHtml('\n\n$quoted')}';
    return MailComposeStart(
      to: _recipients(switch (kind) {
        _ when message == null => const [],
        MailComposeKind.forward => const [],
        _ => MailText.replyRecipients(
            message,
            all: kind == MailComposeKind.replyAll,
            ownAddress:
                MailConnector.accountToAddress(Model.instance.getAccount()),
          ),
      }),
      subject: message == null
          ? ''
          : MailText.prefixed(
              kind == MailComposeKind.forward ? 'Fwd: ' : 'Re: ',
              message.subject),
      editorScript: RichEditorBridgeUtils.buildSetContentCall(_initialHtml) +
          RichEditorBridgeUtils.buildPlaceholderCall(R.current.mailBodyHint),
      pickLimit: pickLimit,
    );
  }

  /// 重複的位址不再加一次：同一個人寄兩份的結果是伺服器退信。
  @override
  List<MailRecipient> addRecipients(List<String> existing, String raw) {
    final next = [...existing];
    for (final address in parseMailAddresses(raw)) {
      if (next.any((a) => a.toLowerCase() == address.toLowerCase())) continue;
      next.add(address);
    }
    return _recipients(next);
  }

  static List<MailRecipient> _recipients(List<String> addresses) => [
        for (final address in addresses)
          MailRecipient(address: address, valid: looksLikeMailAddress(address)),
      ];

  @override
  Future<List<MailContactRow>> suggest(String query, List<String> taken) async {
    final hits = await MailRepository.instance.suggestContacts(query);
    final chosen = {for (final address in taken) address.toLowerCase()};
    return [
      for (final contact in hits)
        if (!chosen.contains(contact.email.toLowerCase()))
          MailContactRow(email: contact.email, label: contact.label),
    ];
  }

  /// 用原始檔案大小的總和去擋，理由見 [MailConfig.maxAttachmentBytes]。
  @override
  Future<MailAttachCheck> checkAttachments(
      List<String> existing, List<String> picked) async {
    try {
      var total = 0;
      for (final path in [...existing, ...picked]) {
        total += await File(path).length();
      }
      if (total > MailConfig.maxAttachmentBytes) {
        return MailAttachCheck(
            accepted: const [], error: R.current.mailAttachTooLarge);
      }
      return MailAttachCheck(accepted: picked);
    } on FileSystemException catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return MailAttachCheck(
          accepted: const [], error: R.current.mailActionFailed);
    }
  }

  @override
  Future<MailSendResult> send(MailSendRequest request) async {
    final to = [...request.to, ...parseMailAddresses(request.pendingTo)];
    final cc = [...request.cc, ...parseMailAddresses(request.pendingCc)];
    final bcc = [...request.bcc, ...parseMailAddresses(request.pendingBcc)];
    if (to.isEmpty) {
      return MailSendResult(
          error: R.current.mailRecipientRequired, holdSeconds: 0);
    }
    if (![...to, ...cc, ...bcc].every(looksLikeMailAddress)) {
      return MailSendResult(
          error: R.current.mailInvalidRecipient, holdSeconds: 0);
    }
    final id = await MailOutboxController.instance.enqueue(MailDraft(
      to: to,
      cc: cc,
      bcc: bcc,
      subject: request.subject,
      body: request.html ?? _initialHtml,
      attachments: [for (final path in request.attachments) File(path)],
    ));
    if (id == null) {
      return MailSendResult(error: R.current.mailSendFailed, holdSeconds: 0);
    }
    return MailSendResult(
        queuedId: id,
        holdSeconds: MailOutboxController.holdWindow.inSeconds);
  }
}
