import 'package:json_annotation/json_annotation.dart';

part 'mail_message_json.g.dart';

/// 收件匣列表用的一封信。
///
/// 只放 envelope 抓得到的欄位，**內文不在這裡**：這個型別會被整包序列化進
/// SharedPreferences 的快取 blob，內文與附件塞進去會把那包 blob 撐爆。
@JsonSerializable()
class MailMessageJson {
  /// IMAP UID。資料夾內唯一，但只在 `UIDVALIDITY` 沒變的前提下有效。
  final int uid;

  final String subject;

  final String fromName;

  final String fromEmail;

  /// 信件日期的 epoch 毫秒。存數字而不是字串，排序才不用每次重新 parse。
  final int dateMillis;

  final bool seen;

  /// 原信的收件者與副本。**全部回覆需要它們**，而 `ENVELOPE` 本來就會一起回，
  /// 不存等於為了全部回覆再打一次網路。只存位址不存顯示名稱，那一份快取
  /// blob 已經夠肥了。
  final List<String> to;

  final List<String> cc;

  const MailMessageJson({
    required this.uid,
    this.subject = "",
    this.fromName = "",
    this.fromEmail = "",
    this.dateMillis = 0,
    this.seen = false,
    this.to = const [],
    this.cc = const [],
  });

  factory MailMessageJson.fromJson(Map<String, dynamic> json) =>
      _$MailMessageJsonFromJson(json);

  Map<String, dynamic> toJson() => _$MailMessageJsonToJson(this);

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMillis);

  /// 寄件者顯示名稱，沒有就退回位址。兩個都空的話回空字串，讓 UI 自己決定
  /// 要畫什麼，不要在這裡塞「（無寄件者）」之類的字串——那是 l10n 的事。
  String get displayFrom => fromName.isNotEmpty ? fromName : fromEmail;

  MailMessageJson copyWith({bool? seen}) => MailMessageJson(
        uid: uid,
        subject: subject,
        fromName: fromName,
        fromEmail: fromEmail,
        dateMillis: dateMillis,
        seen: seen ?? this.seen,
        to: to,
        cc: cc,
      );
}
