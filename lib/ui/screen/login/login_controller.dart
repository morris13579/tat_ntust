import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  var isShowPassword = false.obs;
  var accountErrMsg = ''.obs;
  var passwordErrMsg = ''.obs;

  @override
  void onInit() {
    super.onInit();
    initField();
  }

  void initField() {
    accountController.text = Model.instance.getAccount();
    passwordController.text = Model.instance.getPassword();
  }

  Future<void> onLoginEvent() async {
    if(_isContentError()) {
      return;
    }
    var account = accountController.text;
    var password = passwordController.text;
    Model.instance.setAccount(account);
    Model.instance.setPassword(password);
    await Model.instance.saveUserData();
    MyToast.show(R.current.loginSave);
    RouteUtils.toMainScreen();
  }

  bool _isContentError() {
    var account = accountController.text;
    var password = passwordController.text;
    accountErrMsg.value = "";
    passwordErrMsg.value = "";

    if(account.isEmpty || account.trim().isEmpty) {
      accountErrMsg.value = R.current.accountNull;
    }

    if(password.isEmpty || password.trim().isEmpty) {
      passwordErrMsg.value = R.current.passwordNull;
    }

    return accountErrMsg.value.isNotEmpty || passwordErrMsg.value.isNotEmpty;
  }
}