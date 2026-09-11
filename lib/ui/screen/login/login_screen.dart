import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/components/adaptive_button.dart';
import 'package:flutter_app/ui/components/input/input_field.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/screen/login/login_controller.dart';
import 'package:get/get.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController controller;

  @override
  void initState() {
    super.initState();
    // 註冊留在 build 之外，並在這裡負責回收：controller 的 onClose 是那兩個
    // TextEditingController（其中一個裝著明文密碼）唯一的釋放點。
    controller = Get.put(LoginController());
  }

  @override
  void dispose() {
    Get.delete<LoginController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _logo(),
                const SizedBox(height: 24),
                Text(R.current.loginTitle, style: context.text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  R.current.loginDescription,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                Obx(_accountField),
                const SizedBox(height: 16),
                Obx(_passwordField),
                const SizedBox(height: 24),
                _loginButton(context),
                const SizedBox(height: 16),
                Text(
                  R.current.login_hint,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                _consentLine(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TatTokens.radiusDialog),
        child: Image.asset("assets/launcher/ios-icon.png",
            width: 64, height: 64, fit: BoxFit.cover),
      ),
    );
  }

  Widget _accountField() {
    return InputField(
      label: R.current.account,
      hint: R.current.accountHint,
      controller: controller.accountController,
      inputType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.username],
      isError: controller.accountErrMsg.value.isNotEmpty,
      errorMsg: controller.accountErrMsg.value,
    );
  }

  Widget _passwordField() {
    return InputField(
      label: R.current.password,
      hint: R.current.password,
      controller: controller.passwordController,
      // 眼睛要真的能揭露內容，就不能走 visiblePassword——InputField 把它
      // 當成「一律遮住」。
      inputType: TextInputType.text,
      obscureText: controller.passwordObscured.value,
      onToggleObscured: controller.togglePasswordObscured,
      autofillHints: const [AutofillHints.password],
      isError: controller.passwordErrMsg.value.isNotEmpty,
      errorMsg: controller.passwordErrMsg.value,
    );
  }

  Widget _loginButton(BuildContext context) {
    return SizedBox(
      height: TatTokens.heightButton,
      child: AdaptiveButton(
        onPressed: controller.onLoginEvent,
        width: double.infinity,
        backgroundColor: context.scheme.primary,
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        child: Text(
          R.current.login,
          style: context.text.titleSmall
              ?.copyWith(color: context.scheme.onPrimary),
        ),
      ),
    );
  }

  Widget _consentLine(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          R.current.continueMeansAgree,
          style: context.text.bodySmall
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: controller.onPrivacyPolicyTap,
          child: Text(
            R.current.PrivacyPolicy,
            style: context.text.bodySmall?.copyWith(
              color: context.scheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: context.scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
