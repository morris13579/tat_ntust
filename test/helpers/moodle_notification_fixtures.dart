import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';

/// test/fixtures/moodle_notification/ 底下的 JSON。形狀照 MOODLE_405_STABLE 的
/// message/output/popup/externallib.php，帶著所有 TAT 不建模的欄位
/// （shortenedsubject、deleted、iconurl、timecreatedpretty……），解析時必須被
/// 忽略而不是拋。
Map<String, dynamic> loadMoodleNotificationFixture(String name) => json.decode(
        File('test/fixtures/moodle_notification/$name.json').readAsStringSync())
    as Map<String, dynamic>;

/// 走 connector 的 `notificationsOf`：正式路徑上 repository 拿到（並寫進快取）
/// 的就是它的輸出，`subject` 與 `contexturlname` 已還原 HTML 實體。
MoodleNotificationList fixtureNotifications(
        [String name = 'popup_notifications']) =>
    MoodleWebApiConnector.notificationsOf(loadMoodleNotificationFixture(name))!;
