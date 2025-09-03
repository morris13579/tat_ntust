import 'package:flutter/material.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:get/get.dart';

class R {
  static S current = S.of(Get.context!);

  static load(Locale locale) {
    S.delegate.load(locale);
  }
}
