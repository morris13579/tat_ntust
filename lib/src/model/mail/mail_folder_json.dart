import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mail_folder_json.g.dart';

/// 伺服器上的一個資料夾。
@JsonSerializable()
class MailFolderJson {
  /// IMAP 的完整路徑，`SELECT` 用這個而不是 [name]。
  final String path;

  /// 伺服器回的原始名稱，可能是中文（Mail2000 原生）也可能是英文
  /// （其他郵件軟體建的）。認不出角色時畫面上就顯示它。
  final String name;

  /// 沒有 `SPECIAL-USE`，角色是照名字對出來的，見 [mailFolderRole]。
  final MailFolderRole role;

  /// 資料夾裡的信件總數與未讀數，來自 IMAP 的 `STATUS`。
  ///
  /// -1 代表沒問到——`STATUS` 是一個資料夾一次往返，任何一個失敗都不該讓整份
  /// 清單掛掉，所以問不到就留 -1，畫面上不顯示數字而不是顯示 0 騙人。
  final int messageCount;

  final int unreadCount;

  const MailFolderJson({
    required this.path,
    required this.name,
    this.role = MailFolderRole.other,
    this.messageCount = -1,
    this.unreadCount = -1,
  });

  bool get hasCount => messageCount >= 0;

  factory MailFolderJson.fromJson(Map<String, dynamic> json) =>
      _$MailFolderJsonFromJson(json);

  Map<String, dynamic> toJson() => _$MailFolderJsonToJson(this);
}
