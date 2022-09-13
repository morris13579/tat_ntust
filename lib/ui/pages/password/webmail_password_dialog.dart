import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:get/get.dart';

class WebMailPasswordDialog extends StatefulWidget {
  const WebMailPasswordDialog({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _WebMailPasswordDialogState();
}

class _WebMailPasswordDialogState extends State<WebMailPasswordDialog> {
  final TextEditingController _originPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool passwordShow = false;
  final FocusNode _originPasswordFocus = FocusNode();
  String _originPasswordErrorMessage = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: Text(
          R.current.pleaseEnterWebMailPassword,
          textAlign: TextAlign.center,
        ),
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20))),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Material(
              elevation: 2,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _originPasswordController,
                      cursorColor: Colors.blue[800],
                      textInputAction: TextInputAction.done,
                      focusNode: _originPasswordFocus,
                      onEditingComplete: () {
                        _originPasswordFocus.unfocus();
                      },
                      obscureText: !passwordShow,
                      validator: (value) => _validatorOriginPassword(value!),
                      decoration: InputDecoration(
                        hintText: R.current.password,
                        errorStyle: const TextStyle(
                          height: 0,
                          fontSize: 0,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: (!passwordShow)
                        ? const Icon(EvaIcons.eyeOffOutline)
                        : const Icon(EvaIcons.eyeOutline),
                    onPressed: () {
                      setState(() {
                        passwordShow = !passwordShow;
                      });
                    },
                  )
                ],
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            if (_originPasswordErrorMessage.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _originPasswordErrorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(R.current.cancel),
          onPressed: () => Get.back<bool>(result: false),
        ),
        TextButton(
          child: Text(R.current.sure),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              Model.instance.setWebMailPassword(_originPasswordController.text);
              await Model.instance.saveUserData();
              Get.back<bool>(result: true);
            }
          },
        )
      ],
    );
  }

  String? _validatorOriginPassword(String value) {
    _originPasswordErrorMessage = "";
    if (value.isEmpty) {
      _originPasswordErrorMessage = R.current.passwordNull;
    }
    return _originPasswordErrorMessage.isEmpty
        ? null
        : _originPasswordErrorMessage;
  }
}
