import 'dart:io';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/reset_statics.dart';

/// 啟動順序：`AuthSession` 必須在第一次有人問它之前就裝好。
///
/// 這件事單元測試平常碰不到，因為沒有測試會跑 `main()`。它壞掉的樣子是：
/// `getInitialRoute` 在 `runApp` 之前讀 `isSignedIn`，拿到還沒被取代的
/// `UninstalledAuthSession`，直接拋 StateError；例外被 `runZonedGuarded`
/// 吞掉，`runApp` 不執行，而 `FlutterNativeSplash.remove()` 在
/// `GetMaterialApp.onReady` 裡所以也不會跑——畫面永遠停在原生啟動圖。
/// analyze、單元測試與 APK 建置全部會是綠的。
///
/// 第一個測試直接讀原始碼比對位置。這是刻意的：真正的不變量是「安裝在
/// 第一次讀取之前」，而那是 `main()` 內的語句順序，不是任何函式的回傳值，
/// 不讀原始碼就表達不出來。有人把安裝點搬回 `onReady` 時它會紅。
void main() {
  test('AuthSession 的安裝點在 main.dart 裡排在 getInitialRoute 之前', () {
    final source = File('lib/main.dart').readAsStringSync();

    final install = source.indexOf('AuthSession.instance =');
    final read = source.indexOf('await getInitialRoute');

    expect(install, isNonNegative,
        reason: 'main.dart 應該要有唯一一處 AuthSession.instance 的指派');
    expect(read, isNonNegative, reason: 'main.dart 應該要讀 getInitialRoute');
    expect(source.indexOf('AuthSession.instance =', install + 1), -1,
        reason: '安裝點只該有一處，兩處就無法確定哪一處先跑');

    expect(install, lessThan(read),
        reason: '安裝晚於讀取的話，冷啟動會卡在原生啟動圖，而且三道 CI 門檻都不會紅');
  });

  group('getInitialRoute', () {
    setUp(() {
      resetAppStatics();
      AuthSession.instance = AppAuthSession();
    });

    test('沒有憑證時去登入頁', () async {
      expect(await getInitialRoute, 'login');
    });

    test('帳號密碼都有時直接進主畫面', () async {
      CredentialsStore.instance
        ..setAccount('B10902000')
        ..setPassword('pw');
      expect(await getInitialRoute, 'home');
    });

    test('只有帳號沒有密碼時仍然去登入頁', () async {
      CredentialsStore.instance.setAccount('B10902000');
      expect(await getInitialRoute, 'login');
    });
  });
}
