import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  var accountErrMsg = ''.obs;
  var passwordErrMsg = ''.obs;
  var passwordObscured = true.obs;

  @override
  void onInit() {
    super.onInit();
    initField();
  }

  @override
  void onClose() {
    // passwordController 一路持有臺科大的明文密碼，畫面收掉時要跟著放掉。
    accountController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void initField() {
    accountController.text = Model.instance.getAccount();
    passwordController.text = Model.instance.getPassword();
  }

  void togglePasswordObscured() {
    passwordObscured.value = !passwordObscured.value;
  }

  /// 同意條款那一行的唯一入口，也是隱私權條款在 App 裡唯一的入口之一。
  Future<void> onPrivacyPolicyTap() => RouteUtils.toPrivacyPolicyPage();

  Future<void> onLoginEvent() async {
    if (_isContentError()) {
      return;
    }
    var account = accountController.text;
    var password = passwordController.text;
    Model.instance.setAccount(account);
    Model.instance.setPassword(password);
    await Model.instance.saveUserData();
    TatToast.show(R.current.loginSave);
    unawaited(RouteUtils.toMainScreen());
  }

  bool _isContentError() {
    var account = accountController.text;
    var password = passwordController.text;
    accountErrMsg.value = "";
    passwordErrMsg.value = "";

    if (account.isEmpty || account.trim().isEmpty) {
      accountErrMsg.value = R.current.accountNull;
    }

    if (password.isEmpty || password.trim().isEmpty) {
      passwordErrMsg.value = R.current.passwordNull;
    }

    return accountErrMsg.value.isNotEmpty || passwordErrMsg.value.isNotEmpty;
  }
}
