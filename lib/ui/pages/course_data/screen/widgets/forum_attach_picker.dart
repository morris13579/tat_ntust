import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/file_pick_service.dart';
import 'package:flutter_app/src/service/image_pick_service.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// 附件的三個來源。
enum ForumAttachSource { camera, gallery, files }

/// 挑一個討論區附件：先問來源，再走對應的挑選器。
///
/// **為什麼不能只留檔案挑選器**：iOS 上 `FileType.any` 是
/// UIDocumentPickerViewController，而相機膠卷不是「檔案」的 provider——剛拍
/// 的白板照片在那裡看不到，使用者得先離開 App 把它匯出到「檔案」再回來。
/// 相機更是完全沒有入口。
///
/// 使用者取消（沒選來源、或在挑選器裡按取消）一律回空清單，不是失敗；失敗
/// 由這裡吐訊息，呼叫端只拿得到檔案。
Future<List<File>> pickForumAttachments(
  BuildContext context, {
  required int remaining,
}) async {
  if (remaining <= 0) return const [];
  final source = await showForumAttachSourceSheet(context);
  if (source == null || !context.mounted) return const [];
  return switch (source) {
    ForumAttachSource.camera => _pickImage(ImagePickSource.camera),
    ForumAttachSource.gallery => _pickImage(ImagePickSource.gallery),
    ForumAttachSource.files => _pickFiles(remaining),
  };
}

/// 來源選單。回 null 代表使用者取消。形狀照 `avatar_action_sheet.dart`——
/// 那已經是這個 App 的既有語彙。
Future<ForumAttachSource?> showForumAttachSourceSheet(BuildContext context) {
  return showModalBottomSheet<ForumAttachSource>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const _ForumAttachSourceSheet(),
  );
}

Future<List<File>> _pickImage(ImagePickSource source) async {
  try {
    // 刻意不給 maxEdge / quality：附件沒有頭貼那層格式限制，而白板照片被縮到
    // 長邊 1024 就讀不出字了。
    final file = await ImagePickService.instance.pick(source);
    return file == null ? const [] : [file];
  } on ImagePickFailure catch (e) {
    TaskUiDelegate.instance.toast(switch (e.reason) {
      ImagePickFailureReason.cameraDenied => R.current.avatarCameraDenied,
      ImagePickFailureReason.galleryDenied => R.current.avatarGalleryDenied,
      ImagePickFailureReason.unavailable => R.current.avatarPickerUnavailable,
    });
    return const [];
  }
}

Future<List<File>> _pickFiles(int remaining) async {
  try {
    return await FilePickService.instance.pick(limit: remaining);
  } on FilePickFailure catch (e) {
    TaskUiDelegate.instance.toast(switch (e.reason) {
      FilePickFailureReason.denied => R.current.assignFilePickerDenied,
      FilePickFailureReason.unavailable =>
        R.current.assignFilePickerUnavailable,
    });
    return const [];
  }
}

class _ForumAttachSourceSheet extends StatelessWidget {
  const _ForumAttachSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 可捲：modal sheet 的高度上限是螢幕的 9/16，字級放大就會超出去。
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionSubLabel(R.current.forumAddAttachment),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: Text(R.current.forumAttachFromCamera),
              onTap: () => Navigator.pop(context, ForumAttachSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.images),
              title: Text(R.current.forumAttachFromGallery),
              onTap: () => Navigator.pop(context, ForumAttachSource.gallery),
            ),
            ListTile(
              leading: const Icon(LucideIcons.folder),
              title: Text(R.current.forumAttachFromFiles),
              onTap: () => Navigator.pop(context, ForumAttachSource.files),
            ),
            const SectionDivider(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(R.current.cancel),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
