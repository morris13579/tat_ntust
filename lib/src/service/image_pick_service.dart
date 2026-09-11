import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// 要從哪裡挑圖。
enum ImagePickSource { gallery, camera }

/// 挑圖失敗的原因。使用者按取消不是失敗（回 null），只有這幾種才是。
enum ImagePickFailureReason { cameraDenied, galleryDenied, unavailable }

/// 挑圖失敗。取消請回 null，不要丟這個。
class ImagePickFailure implements Exception {
  const ImagePickFailure(this.reason);

  final ImagePickFailureReason reason;

  @override
  String toString() => 'ImagePickFailure($reason)';
}

/// 頭貼的縮圖參數。Moodle 的 process_new_icon 只吃 GIF/JPEG/PNG，而且是用
/// getimagesize() 嗅內容不是看副檔名；Android 的 resizer 只有在指定了
/// maxWidth/maxHeight 或 imageQuality<100 時才會重新編碼成 JPEG/PNG，不指定
/// 就原封不動把 HEIC/WebP 丟上去——伺服器只會回一個沒有理由的 success:false。
/// 所以這兩個值是正確性需求，不是最佳化。
///
/// 1024 而不是 512：Moodle 的 f3 是置中裁切後的 512x512，長邊剛好給 512
/// 會讓它往上放大。
const double kAvatarImageMaxEdge = 1024;
const int kAvatarImageQuality = 90;

/// 挑一張圖。抽成介面加靜態 instance（同 [InteractiveLoginGateway] 的做法）
/// 是為了測試不必碰平台通道。
abstract class ImagePickService {
  static ImagePickService instance = PlatformImagePickService();

  /// 使用者取消時回 null。權限被拒、相機不可用時丟 [ImagePickFailure]。
  ///
  /// [maxEdge] 與 [quality] 都是 null ＝原圖原封不動送出來。**討論區附件走這
  /// 一條**：一張白板照片被縮到長邊 1024 就讀不出字了，而附件沒有頭貼那層
  /// 格式限制。頭貼要傳 [kAvatarImageMaxEdge] / [kAvatarImageQuality]。
  Future<File?> pick(ImagePickSource source, {double? maxEdge, int? quality});
}

/// 走 image_picker 的正式實作。
class PlatformImagePickService implements ImagePickService {
  PlatformImagePickService();

  bool _configured = false;

  /// Android 13+ 切到系統相片挑選器：那條路完全不需要執行期權限，而
  /// AndroidManifest 用 `tools:node="remove"` 拿掉了 READ_MEDIA_IMAGES。
  void _configure() {
    if (_configured) return;
    _configured = true;
    final platform = ImagePickerPlatform.instance;
    if (platform is ImagePickerAndroid) {
      platform.useAndroidPhotoPicker = true;
    }
  }

  @override
  Future<File?> pick(ImagePickSource source,
      {double? maxEdge, int? quality}) async {
    _configure();
    try {
      final picked = await ImagePicker().pickImage(
        source: source == ImagePickSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: maxEdge,
        maxHeight: maxEdge,
        imageQuality: quality,
        // 不要 EXIF：那裡面有 GPS，沒有理由送上學校伺服器。
        requestFullMetadata: false,
      );
      if (picked == null) return null;
      return File(picked.path);
    } on PlatformException catch (e) {
      throw ImagePickFailure(pickFailureReasonOf(e.code));
    }
  }

  /// image_picker 的 PlatformException code 換成失敗原因。權限那幾個 code 都
  /// 在這裡列全了，所以認不得的一律是「這條路現在走不通」——`no_available_camera`
  /// （沒有相機 App）或 `already_active` 都不是權限問題，把使用者送去系統設定
  /// 找一個不存在的開關比不說更糟。
  static ImagePickFailureReason pickFailureReasonOf(String code) =>
      switch (code) {
        'camera_access_denied' ||
        'camera_access_restricted' =>
          ImagePickFailureReason.cameraDenied,
        'photo_access_denied' ||
        'photo_access_restricted' =>
          ImagePickFailureReason.galleryDenied,
        _ => ImagePickFailureReason.unavailable,
      };
}

/// 測試與 headless 環境用的空實作：一律當成使用者取消。
class NoopImagePickService implements ImagePickService {
  const NoopImagePickService();

  @override
  Future<File?> pick(ImagePickSource source,
          {double? maxEdge, int? quality}) async =>
      null;
}
