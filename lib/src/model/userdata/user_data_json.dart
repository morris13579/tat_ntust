import 'package:json_annotation/json_annotation.dart';
import 'package:sprintf/sprintf.dart';

part 'user_data_json.g.dart';

@JsonSerializable()
class UserDataJson {
  String account;
  String password;

  UserDataJson({this.account = "", this.password = ""});

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
