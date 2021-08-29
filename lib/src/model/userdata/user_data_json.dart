import 'package:flutter_app/src/model/json_init.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sprintf/sprintf.dart';

part 'user_data_json.g.dart';

@JsonSerializable()
class UserDataJson {
  String account;
  String password;

  UserDataJson({this.account, this.password}) {
    this.account = JsonInit.stringInit(this.account);
    this.password = JsonInit.stringInit(this.password);
  }

  factory UserDataJson.fromJson(Map<String, dynamic> json) =>
      _$UserDataJsonFromJson(json);

  Map<String, dynamic> toJson() => _$UserDataJsonToJson(this);

  bool get isEmpty {
    return account.isEmpty && password.isEmpty;
  }

  @override
  String toString() {
    return sprintf(
        "account  : %s \n"
        "password : %s \n",
        [account, password]);
  }
}
