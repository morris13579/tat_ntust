import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/pages/password/password_field.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

class CheckPasswordDialog extends StatefulWidget {
  const CheckPasswordDialog({super.key});

  @override
  State<StatefulWidget> createState() => _CheckPasswordDialogState();
}

class _CheckPasswordDialogState extends State<CheckPasswordDialog> {
  final TextEditingController _originPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool passwordShow = false;
  final FocusNode _originPasswordFocus = FocusNode();
  String _originPasswordErrorMessage = "";

  @override
  void initState() {
    checkAuth();
    super.initState();
  }

  @override
  void dispose() {
    // TextEditingController 會一路持有使用者剛剛輸入的 NTUST 明文密碼，
    // 對話框關掉之後若不 dispose，它會跟著 State 一起留在記憶體裡；
    // FocusNode 沒 dispose 也會留在 focus tree 上並持續發通知。
    _originPasswordController.dispose();
    _originPasswordFocus.dispose();
    super.dispose();
  }

  void checkAuth() async {
    LocalAuthentication localAuthentication = LocalAuthentication();
    try {
      bool didAuthenticate = await localAuthentication.authenticate(
          localizedReason: R.current.checkIdentity);
      if (didAuthenticate) {
        Get.back<bool>(result: true);
      }
    } on PlatformException catch (e) {
      Log.d(e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TatDialog(
      title: R.current.checkIdentity,
      body: R.current.originPassword,
      kind: TatDialogKind.info,
      content: Form(
        key: _formKey,
        child: PasswordField(
          controller: _originPasswordController,
          focusNode: _originPasswordFocus,
          obscured: !passwordShow,
          onToggleObscured: () => setState(() => passwordShow = !passwordShow),
          hintText: R.current.password,
          validator: (value) => _validatorOriginPassword(value ?? ""),
          errorMessage: _originPasswordErrorMessage,
        ),
      ),
      secondary: TatDialogAction(
        label: R.current.cancel,
        onPressed: () => Get.back<bool>(result: false),
      ),
      primary: TatDialogAction(
        label: R.current.sure,
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Get.back<bool>(result: true);
          }
        },
      ),
    );
  }

  String? _validatorOriginPassword(String value) {
    if (value == Model.instance.getPassword()) {
      _originPasswordErrorMessage = '';
    } else {
      setState(() {
        _originPasswordErrorMessage = R.current.passwordNotSame;
      });
    }
    return _originPasswordErrorMessage.isNotEmpty
        ? _originPasswordErrorMessage
        : null;
  }
}
