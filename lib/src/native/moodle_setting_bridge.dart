import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart'
    show MoodleWebApiConnector;
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:flutter_app/src/util/moodle_setting_utils.dart';

/// 原生版的 Moodle 通知設定，照 `MoodleSettingController`：寫入是送出這一項開著的整份清單，再重抓。
class MoodleSettingBridge implements TatMoodleSettingApi {
  MoodleSettingBridge({
    Future<MoodleSettingEntity?> Function()? fetch,
    Future<bool> Function(String key, List<String> values)? write,
  })  : _fetch = fetch ?? MoodleWebApiConnector.getSettings,
        _write = write ?? MoodleWebApiConnector.toggleSetting;

  final Future<MoodleSettingEntity?> Function() _fetch;
  final Future<bool> Function(String key, List<String> values) _write;

  /// 最近一次拿到的設定。寫入要從它算出整份清單。
  MoodleSettingEntity? _last;

  static void install() => TatMoodleSettingApi.setUp(MoodleSettingBridge());

  @override
  Future<MoodleSettings?> load() async {
    try {
      _last = await _fetch();
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      _last = null;
    }
    final setting = _last;
    return setting == null ? null : _settings(setting);
  }

  @override
  Future<MoodleSettings?> toggle(
      String key, String processor, bool enabled) async {
    final setting = _last;
    if (setting == null) return null;
    final values = MoodleSettingUtils.valuesAfterToggle(
        setting.preferences.components, key, processor, enabled);
    if (values == null) return null;
    try {
      if (!await _write(key, values)) return null;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
    return load();
  }

  static MoodleSettings _settings(MoodleSettingEntity setting) =>
      MoodleSettings(
        processors: [
          for (final processor in MoodleSettingUtils.visibleProcessors(
              setting.preferences.processors))
            MoodleNotifyProcessor(
                name: processor.name, displayName: processor.displayname),
        ],
        groups: [
          for (final component in setting.preferences.components)
            MoodleNotifyGroup(
              name: component.displayname,
              settings: [
                for (final notification in component.notifications)
                  MoodleNotifySetting(
                    key: notification.preferencekey,
                    name: notification.displayname,
                    enabled: [
                      for (final p in notification.processors)
                        if (p.enabled) p.name,
                    ],
                  ),
              ],
            ),
        ],
      );
}
