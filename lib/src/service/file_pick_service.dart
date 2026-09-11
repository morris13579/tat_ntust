import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show PlatformException;

/// 挑檔案失敗的原因。使用者按取消不是失敗（回空清單），只有這兩種才是。
enum FilePickFailureReason { denied, unavailable }

/// 挑檔案失敗。取消請回空清單，不要丟這個。
class FilePickFailure implements Exception {
  const FilePickFailure(this.reason);

  final FilePickFailureReason reason;

  @override
  String toString() => 'FilePickFailure($reason)';
}

/// 挑任意檔案。抽成介面加靜態 instance，理由同 ImagePickService：
/// 測試不必碰平台通道。
abstract class FilePickService {
  static FilePickService instance = PlatformFilePickService();

  /// 使用者取消時回空清單；權限被拒、挑選器叫不起來時丟 [FilePickFailure]。
  /// [extensions] 只吃副檔名（不含點），空清單代表不限。
  Future<List<File>> pick({
    required int limit,
    List<String> extensions = const [],
  });
}

/// 走 file_picker 的正式實作。
class PlatformFilePickService implements FilePickService {
  PlatformFilePickService();

  @override
  Future<List<File>> pick({
    required int limit,
    List<String> extensions = const [],
  }) async {
    if (limit <= 0) return const [];
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: limit > 1,
        // 不要 withData：交作業的檔案可能很大，讀進記憶體只為了再寫出去。
        withData: false,
        type: extensions.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: extensions.isEmpty ? null : extensions,
      );
      if (result == null) return const [];
      return [
        for (final f in result.files)
          if (f.path != null) File(f.path!),
      ].take(limit).toList();
    } on PlatformException catch (e) {
      throw FilePickFailure(pickFailureReasonOf(e.code));
    }
  }

  /// file_picker 的 PlatformException code 換成失敗原因。
  ///
  /// 11.x 自己丟的碼（`no_activity`、`already_active`、`unknown_path`、
  /// `invalid_format_type`、`multiple_request`、`file_picker_error`）全部不是
  /// 權限問題——SAF 與 UIDocumentPicker 都不需要儲存權限。留著那三個 `denied`
  /// 只是為了跨版本；認不得的一律是「這條路現在走不通」，同
  /// PlatformImagePickService.pickFailureReasonOf 的態度：把使用者送去系統設定
  /// 找一個不存在的開關比不說更糟。
  static FilePickFailureReason pickFailureReasonOf(String code) =>
      switch (code) {
        'read_external_storage_denied' ||
        'photo_access_denied' ||
        'permission_denied' =>
          FilePickFailureReason.denied,
        _ => FilePickFailureReason.unavailable,
      };
}

/// 測試與 headless 環境用的空實作：一律當成使用者取消。
class NoopFilePickService implements FilePickService {
  const NoopFilePickService();

  @override
  Future<List<File>> pick({
    required int limit,
    List<String> extensions = const [],
  }) async =>
      const [];
}
