import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';

/// Moodle 通知設定的規則。App 的 Moodle 設定頁與原生版共用。
class MoodleSettingUtils {
  MoodleSettingUtils._();

  /// 設定頁的分頁：通知方式，照顯示名稱排。
  ///
  /// 行動裝置（airnotifier）那一頁不顯示：它管的是 Moodle 官方 App 的推播，
  /// 在這個 App 裡打開也收不到，只會讓人以為設定沒生效。
  static List<MoodleSettingPreferencesProcessors> visibleProcessors(
          List<MoodleSettingPreferencesProcessors> processors) =>
      processors.where((e) => e.name != 'airnotifier').toList()
        ..sort((a, b) => a.displayname.compareTo(b.displayname));

  /// 開關 [key] 這一項的 [processor] 之後要送出去的整份清單：伺服器吃的是「這一項
  /// 開著哪些方式」，不是單一開關。找不到這一項回 null。
  static List<String>? valuesAfterToggle(
    List<MoodleSettingPreferencesComponents> components,
    String key,
    String processor,
    bool enabled,
  ) {
    for (final component in components) {
      for (final notification in component.notifications) {
        if (notification.preferencekey != key) continue;
        final values = [
          for (final p in notification.processors)
            if (p.enabled) p.name,
        ];
        if (enabled) {
          values.add(processor);
        } else {
          values.remove(processor);
        }
        return values;
      }
    }
    return null;
  }
}
