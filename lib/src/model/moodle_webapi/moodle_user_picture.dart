import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_user_picture.g.dart';

/// core_user_update_picture 的回應。
///
/// `warnings` 刻意不宣告：伺服器端寫死 `'warnings' => array()`
/// （user/externallib.php），永遠是空的，宣告它只會讓人以為那裡有訊息。
@JsonSerializable()
class MoodleUpdatePictureResult {
  /// 只代表「user.picture 這個欄位有沒有變」，不等於「這次操作成功」。
  /// 上傳路徑的 false 是 Moodle 解不開這張圖；刪除路徑的 false 是本來就沒有頭貼。
  @JsonKey(defaultValue: false)
  bool success;

  /// VALUE_OPTIONAL，只有 success 為 true 才會出現。
  @JsonKey(defaultValue: '')
  String profileimageurl;

  MoodleUpdatePictureResult({
    this.success = false,
    this.profileimageurl = '',
  });

  factory MoodleUpdatePictureResult.fromJson(Map<String, dynamic> json) =>
      _$MoodleUpdatePictureResultFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleUpdatePictureResultToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// webservice/upload.php 回的陣列元素。
///
/// 成功時是 upload.php 的 `$filerecord`；失敗時是一個只有 filename /
/// errortype / error 的物件，兩種形狀同在一個 HTTP 200 陣列裡，所以只宣告
/// 兩邊的交集加上錯誤欄位。`source` 是 PHP serialize 出來的字串不是 JSON，
/// 不要試著解析；license / author / component / contextid / userid /
/// filearea 畫面用不到，不落地。
@JsonSerializable()
class MoodleDraftFile {
  @JsonKey(defaultValue: 0)
  int itemid;
  @JsonKey(defaultValue: '')
  String filename;
  @JsonKey(defaultValue: '')
  String filepath;
  @JsonKey(defaultValue: 0)
  int filesize;

  /// 非空就代表這一筆失敗了（fileoversized / filenameexist）。
  @JsonKey(defaultValue: '')
  String error;
  @JsonKey(defaultValue: '')
  String errortype;

  MoodleDraftFile({
    this.itemid = 0,
    this.filename = '',
    this.filepath = '',
    this.filesize = 0,
    this.error = '',
    this.errortype = '',
  });

  factory MoodleDraftFile.fromJson(Map<String, dynamic> json) =>
      _$MoodleDraftFileFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleDraftFileToJson(this);

  bool get isError => error.isNotEmpty;

  @override
  String toString() => jsonEncode(this);
}
