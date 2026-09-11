import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/version/store_update.dart';
import 'package:sprintf/sprintf.dart';
import 'package:upgrader/upgrader.dart';

/// 啟動時的商店更新提示，包在整個 App 外面（GetMaterialApp.builder）。
///
/// Android 交給 Play 的 in-app update：Play 自己跳提示、背景下載，這裡不畫東西。
/// iOS 沒有這種機制，由 upgrader 查 App Store 版本後跳對話框連到商店頁面。
/// 兩邊都只是提示，可以按稍後，沒有強制更新。
class UpdatePrompt extends StatefulWidget {
  const UpdatePrompt({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// 對話框開在這個 navigator 上：這個 widget 在 router 之上，自己的 context
  /// 上面沒有 navigator。
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends State<UpdatePrompt> {
  /// 只建一次：UpgradeAlert 每拿到一顆新的 Upgrader 就會再查一次商店。
  late final Upgrader _upgrader = Upgrader(
    durationUntilAlertAgain: const Duration(days: 1),
    debugLogging: kDebugMode,
    messages: UpdateMessages(() => _upgrader.state),
  );

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      unawaited(StoreUpdate.offer());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return widget.child;
    }
    return UpgradeAlert(
      upgrader: _upgrader,
      navigatorKey: widget.navigatorKey,
      dialogStyle: UpgradeDialogStyle.cupertino,
      child: widget.child,
    );
  }
}

/// App Store 對話框的文案。版本號要等商店回答後才有，所以透過 closure 讀 state。
class UpdateMessages extends UpgraderMessages {
  UpdateMessages(this._state);

  final UpgraderState Function() _state;

  @override
  String get title => R.current.updateTitle;

  @override
  String get body {
    final state = _state();
    return sprintf(R.current.updateBody, [
      state.versionInfo?.installedVersion?.toString() ??
          state.packageInfo?.version ??
          "",
      state.versionInfo?.appStoreVersion?.toString() ?? "",
    ]);
  }

  @override
  String get prompt => R.current.updatePrompt;

  @override
  String get releaseNotes => R.current.updateReleaseNotes;

  @override
  String get buttonTitleUpdate => R.current.update;

  @override
  String get buttonTitleLater => R.current.updateLater;

  @override
  String get buttonTitleIgnore => R.current.updateIgnore;
}
