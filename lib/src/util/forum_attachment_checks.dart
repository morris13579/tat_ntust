import 'dart:io';

import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:sprintf/sprintf.dart';

/// 挑回來的討論區附件。回覆列、純文字編輯頁、所見即所得編輯頁與原生版共用這一份。
class ForumAttachmentChecks {
  ForumAttachmentChecks._();

  /// 逐檔本地擋三件事：太大、重名、超過數量。[existingNames] 是草稿裡已經有的檔名
  /// （編輯時含保留下來的既有附件：它們會被種進 draft 區，同名的新檔案會回
  /// `filenameexist`，那時 draft 區已經是半套的）。
  static Future<({List<File> accepted, List<String> messages})> check({
    required List<String> existingNames,
    required List<File> picked,
    required ForumAttachPolicy policy,
  }) async {
    final names = [...existingNames];
    final accepted = <File>[];
    final messages = <String>[];
    for (final file in picked) {
      final name = MoodleForumEditUtils.basename(file.path);
      final bytes = await file.length();
      if (MoodleForumEditUtils.exceedsSize(bytes, policy.maxBytes)) {
        messages.add(sprintf(R.current.forumAttachmentTooLarge,
            [name, FileUtils.formatBytes(policy.maxBytes, 1)]));
        continue;
      }
      if (MoodleForumEditUtils.duplicateFilename([...names, name]) != null) {
        messages.add(R.current.forumAttachmentDuplicateName);
        continue;
      }
      if (names.length >= policy.maxFiles) {
        messages.add(sprintf(R.current.forumAttachmentCountExceeded,
            [policy.maxFiles.toString()]));
        break;
      }
      names.add(name);
      accepted.add(file);
    }
    return (accepted: accepted, messages: messages);
  }

  /// 「最多 3 個檔案 · 單一檔案上限 10 MB」。
  static String hint(ForumAttachPolicy policy) => [
        sprintf(R.current.forumAttachmentLimit, [policy.maxFiles.toString()]),
        if (policy.maxBytes > 0)
          sprintf(R.current.forumAttachmentSizeLimit,
              [FileUtils.formatBytes(policy.maxBytes, 1)]),
      ].join(' · ');
}
