import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/ui/components/adaptive_button.dart';
import 'package:flutter_app/ui/components/input/input_field.dart';
import 'package:flutter_app/ui/components/widget_size_render_object.dart';
import 'package:flutter_app/ui/screen/login/login_controller.dart';
import 'package:get/get.dart';

class LoginScreen extends GetView<LoginController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(LoginController());

    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Obx(() {
        return Scaffold(
          body: SafeArea(
              child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
              child: contentView(),
            ),
          )),
        );
      }),
    );
  }

  Widget contentView() {
    return Column(
      children: [
        const SizedBox(height: 12),
        logo(),
        const SizedBox(height: 24),
        Column(
          children: [
            Text(
              R.current.loginTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Get.theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 14),
            Text(R.current.loginDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                    height: 1.2,
                    color: Get.theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            emailField(),
            const SizedBox(height: 20),
            passwordField(),
            const SizedBox(height: 32),
            AdaptiveButton(
              onPressed: controller.onLoginEvent,
              width: double.infinity,
              backgroundColor: Get.theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(10),
              child: Text(
                R.current.login,
                style:
                    TextStyle(color: Get.theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 8),
            Text(R.current.login_hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        Get.theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    fontSize: 12))
          ],
        ),
        SizedBox(height: Get.height * 0.2),
      ],
    );
  }

  Widget logo() {
    return Container(
        clipBehavior: Clip.antiAlias,
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(999), boxShadow: [
          BoxShadow(
              offset: const Offset(1, 1),
              color: Get.theme.colorScheme.onSurface,
              blurRadius: 12)
        ]),
        child: Image.asset("assets/launcher/ios-icon.png", height: 120));
  }

  InputField emailField() {
    return InputField(
      hint: R.current.account,
      controller: controller.accountController,
      inputType: TextInputType.emailAddress,
      isError: controller.accountErrMsg.value.isNotEmpty,
      errorMsg: controller.accountErrMsg.value,
    );
  }

  InputField passwordField() {
    return InputField(
      hint: R.current.password,
      controller: controller.passwordController,
      inputType: TextInputType.visiblePassword,
      isError: controller.passwordErrMsg.value.isNotEmpty,
      errorMsg: controller.passwordErrMsg.value,
    );
  }
}
