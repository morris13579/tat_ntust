import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/permissions_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

class Notifications {
  Notifications._();

  static int idCount = 0;
  static final Notifications instance = Notifications._();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// 通知被點擊時的 payload。
  ///
  /// 單一訂閱（不是 broadcast）是刻意的：從通知點擊冷啟動時，
  /// [FlutterLocalNotificationsPlugin.initialize] 的回呼可能早於
  /// [_configureSelectNotificationSubject] 掛上 listen，單一訂閱的
  /// StreamController 會把這段期間的事件緩衝住並在 listen 當下補送，
  /// broadcast 則會直接丟棄，使用者按了通知卻什麼也沒開。
  final StreamController<String> selectNotificationSubject =
      StreamController<String>();
  final String downloadChannelId = "Download";
  final String downloadChannelName = "Download";
  final String downloadChannelDescription = "Show Download Progress";
  List<int> idList = []; // 已點擊過的通知 id

  Future<void> init() async {
    // 在 main() 裡初始化時必要。
    WidgetsFlutterBinding.ensureInitialized();

    var initializationSettingsAndroid =
        const AndroidInitializationSettings('app_icon');
    // 權限不在這裡要，改由 _requestIOSPermissions 事後索取。
    var initializationSettingsIOS = const DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse payload) async {
      if (payload.payload != null) {
        selectNotificationSubject.add(payload.payload!);
      }
    });

    _requestIOSPermissions();
    await _requestAndroidPermissions();
    _configureSelectNotificationSubject();
  }

  void _requestIOSPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> _requestAndroidPermissions() async {
    await PermissionsUtils.isNotificationPermission();
  }

  void _configureSelectNotificationSubject() {
    selectNotificationSubject.stream.listen((String payload) async {
      Map parse = json.decode(payload);
      String type = parse["type"];
      int id = parse["id"];
      if (!idList.contains(id)) {
        idList.add(parse["id"]);
      }
      switch (type) {
        case "download_complete":
          if (parse.containsKey("path")) {
            String path = parse["path"];
            Log.d("open $path");
            await FileUtils.openFile(path);
          }
          break;
        case "download_fail":
          break;
        case "cloud_message_background":
          break;
        case "cloud_message":
          break;
        default:
          break;
      }
    });
  }

  Future<void> showProgressNotification(
      ReceivedNotification value, int maxProgress, int nowProgress) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        downloadChannelId, downloadChannelName,
        channelDescription: downloadChannelDescription,
        channelShowBadge: false,
        importance: Importance.max,
        priority: Priority.high,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: maxProgress,
        progress: nowProgress,
        playSound: false);
    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
        value.id, value.title, value.body, platformChannelSpecifics,
        payload: value.payload);
  }

  Future<void> showIndeterminateProgressNotification(
      ReceivedNotification value) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        downloadChannelId, downloadChannelName,
        channelDescription: downloadChannelDescription,
        channelShowBadge: false,
        importance: Importance.max,
        priority: Priority.high,
        onlyAlertOnce: true,
        showProgress: true,
        indeterminate: true,
        playSound: false);
    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        value.id, value.title, value.body, platformChannelSpecifics,
        payload: value.payload);
  }

  Future<void> showNotification(ReceivedNotification value) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        downloadChannelId, downloadChannelName,
        channelDescription: downloadChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        onlyAlertOnce: true,
        ticker: 'ticker',
        playSound: false);
    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
        value.id, value.title, value.body, platformChannelSpecifics,
        payload: value.payload);
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  int get notificationId {
    return idCount++;
  }
}

class ReceivedNotification {
  int id;
  String? _showTitle;
  String? body;
  String? payload;
  final _titleLong = 26;

  ReceivedNotification(
      {this.id = 0,
      required String? title,
      required this.body,
      required this.payload}) {
    id = Notifications.instance.notificationId;
    this.title = title;
  }

  String? get title {
    return _showTitle;
  }

  set title(String? value) {
    String newTitle = "";
    value ??= "";
    if (value.length >= _titleLong) {
      newTitle = "${value.substring(0, _titleLong)}...";
    }
    _showTitle = (value.length <= _titleLong) ? value : newTitle;
  }
}
