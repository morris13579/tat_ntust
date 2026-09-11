import 'package:json_annotation/json_annotation.dart';

part 'moodle_message_popup_notifications.g.dart';

/// PARAM_BOOL 正常是 bool；容忍 1/0 與 "1"/"0"。
bool _boolFromJson(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

/// `message_popup_get_popup_notifications` 的回應。整包會進 `CacheStore`，
/// 所以 [toJson] 必須是 [fromJson] 的反函式。
///
/// 清單為空而 [unreadcount] 大於 0 不是「沒有新通知」：伺服器在使用者關掉
/// 站內通知時直接回空清單，未讀數照算，見 `MoodleNotificationUtils`。
@JsonSerializable(explicitToJson: true)
class MoodleNotificationList {
  @JsonKey(defaultValue: [])
  List<MoodleNotification> notifications;

  @JsonKey(defaultValue: 0)
  int unreadcount;

  MoodleNotificationList({
    this.notifications = const [],
    this.unreadcount = 0,
  });

  factory MoodleNotificationList.fromJson(Map<String, dynamic> json) =>
      _$MoodleNotificationListFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleNotificationListToJson(this);
}

/// 一則站內通知。
///
/// 刻意不建模的欄位：`useridfrom` / `useridto`（永遠是自己或不顯示的寄件者）、
/// `shortenedsubject`（伺服器截到 125 字，版面自己 ellipsis）、`deleted`
/// （伺服器寫死 false 的 BC 欄位）、`timecreatedpretty`（伺服器語系算好的
/// 「N 分鐘前」，跟 App 的語言切換打架，而且快取拿出來時早就過時）、
/// `iconurl`（站台主題圖，改用本地 icon）、`fullmessageformat`（我們是
/// 「有 HTML 就用 HTML」而不是照 format 分支）。
@JsonSerializable()
class MoodleNotification {
  /// `{notifications}.id`，也就是 `core_message_mark_notification_read` 吃的
  /// `notificationid`。
  @JsonKey(defaultValue: 0)
  int id;

  /// connector 已還原 HTML 實體。
  @JsonKey(defaultValue: '')
  String subject;

  /// smallmessage 經伺服器 format_text 後的 HTML 片段，不是 fullmessagehtml
  /// 的縮寫。
  @JsonKey(defaultValue: '')
  String text;

  @JsonKey(defaultValue: '')
  String fullmessage;

  @JsonKey(defaultValue: '')
  String fullmessagehtml;

  @JsonKey(defaultValue: '')
  String smallmessage;

  /// 可能是 null：core 的系統通知沒有可以點進去的位址。
  String? contexturl;

  /// connector 已還原 HTML 實體。
  String? contexturlname;

  /// Unix 秒。
  @JsonKey(defaultValue: 0)
  int timecreated;

  /// 未讀時伺服器回 null。樂觀更新會就地改它。
  int? timeread;

  /// 已讀與否的唯一真相（伺服器算的 `timeread ? true : false`）。
  @JsonKey(fromJson: _boolFromJson)
  bool read;

  /// `mod_assign`、`mod_forum`、`moodle`……可能是 null。
  String? component;

  String? eventtype;

  /// `json_encode()` 過的字串，可能是 null 或壞掉，解析走
  /// `MoodleNotificationUtils.customDataOf`。
  String? customdata;

  MoodleNotification({
    this.id = 0,
    this.subject = '',
    this.text = '',
    this.fullmessage = '',
    this.fullmessagehtml = '',
    this.smallmessage = '',
    this.contexturl,
    this.contexturlname,
    this.timecreated = 0,
    this.timeread,
    this.read = false,
    this.component,
    this.eventtype,
    this.customdata,
  });

  factory MoodleNotification.fromJson(Map<String, dynamic> json) =>
      _$MoodleNotificationFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleNotificationToJson(this);

  DateTime get createdTime =>
      DateTime.fromMillisecondsSinceEpoch(timecreated * 1000);
}
