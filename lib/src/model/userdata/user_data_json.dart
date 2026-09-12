import 'package:json_annotation/json_annotation.dart';
import 'package:sprintf/sprintf.dart';

part 'user_data_json.g.dart';

@JsonSerializable()
class UserDataJson {
  String account;
  String password;

  /// 校內信箱（Mail2000）的密碼。
  ///
  /// **與 [password] 是兩組不同的密碼**：[password] 是校務系統的 SSO 密碼，
  /// 這一個是 IMAP / SMTP `AUTH=LOGIN` 認的那組。實測拿 SSO 密碼登 IMAP 會被
  /// 拒，所以不能共用一格。見 docs/WEBMAIL_IMAP.md 的門檻 A。
  String mailPassword;

  UserDataJson({this.account = "", this.password = "", this.mailPassword = ""});

  factory UserDataJson.fromJson(Map<String, dynamic> json) =>
      _$UserDataJsonFromJson(json);

  Map<String, dynamic> toJson() => _$UserDataJsonToJson(this);

  bool get isEmpty {
    return account.isEmpty && password.isEmpty;
  }

  /// **不印密碼。** 這個 toString 會出現在 log、錯誤回報與 Crashlytics 的
  /// 附加資料裡；帳號本身是識別用的、留著有用，密碼沒有任何除錯價值。
  @override
  String toString() {
    return sprintf(
        "account  : %s \n"
        "password : %s \n",
        [account, password.isEmpty ? "<空>" : "<已設定>"]);
  }
}
