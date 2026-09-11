import 'dart:io';

import 'package:flutter_app/src/service/image_pick_service.dart';

/// [ImagePickService] 的測試替身：想回什麼就設什麼，並記下被問過哪些來源。
class FakeImagePickService implements ImagePickService {
  FakeImagePickService({this.next, this.failure});

  /// 挑到的檔案。null 代表使用者取消。
  File? next;

  /// 非 null 時改成丟這個失敗，[next] 就不看了。
  ImagePickFailureReason? failure;

  final List<ImagePickSource> calls = [];

  /// 最後一次要求的縮圖參數。頭貼一定要有值（Moodle 只吃 GIF/JPEG/PNG），
  /// 討論區附件一定要是 null（白板照片縮到 1024 就讀不出字了）。
  double? lastMaxEdge;
  int? lastQuality;

  @override
  Future<File?> pick(ImagePickSource source,
      {double? maxEdge, int? quality}) async {
    calls.add(source);
    lastMaxEdge = maxEdge;
    lastQuality = quality;
    final reason = failure;
    if (reason != null) throw ImagePickFailure(reason);
    return next;
  }
}
