import 'package:flutter/foundation.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/repository/retry.dart';
import 'package:flutter_app/src/repository/run.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';

/// App 自己的公告（Firebase Remote Config）。包成 `Result` 是為了讓公告與通知
/// 頁的兩半共用同一個 `ResultView`，不會一半 try/catch、一半 `Result`。
class AppNoticeRepository {
  AppNoticeRepository();

  static AppNoticeRepository instance = AppNoticeRepository();

  static CacheKey<List<AnnouncementInfoJson>> noticesKey() =>
      CacheKey<List<AnnouncementInfoJson>>(
        "cache_app_notice",
        "all",
        decode: (json) => (json as List)
            .map((e) =>
                AnnouncementInfoJson.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// 測試用的縫：`RemoteConfigUtils._remoteConfig` 是 `late static`，沒跑過
  /// `init()` 的測試碰到它會直接拋。
  @visibleForTesting
  Future<List<AnnouncementInfoJson>> fetchNotices() =>
      // allTime: true ＝ 只看有效期，不看已讀；看過的公告在這一頁仍然找得到。
      RemoteConfigUtils.getAnnouncement(false, true);

  /// 全部在有效期內的 App 公告。空清單是合法結果（`run()` 只把 null 當失敗）。
  ///
  /// `requires` 是空集合：App 公告不需要登入，沒登入的使用者也該看得到。
  Future<Result<List<AnnouncementInfoJson>>> getNotices() =>
      run<List<AnnouncementInfoJson>>(
        requires: const {},
        cache: noticesKey(),
        background: true,
        retry: RetryPolicy.none,
        errorMessage: R.current.getAppNoticeError,
        debugLabel: 'appNotice',
        fetch: fetchNotices,
      );
}
