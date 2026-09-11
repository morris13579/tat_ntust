import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:path_provider/path_provider.dart';

/// 學校行事曆的 `.ics` 檔。
///
/// **刻意不走 `run()`**，三件事都不合身：行事曆是公開端點不需登入、快取是
/// 磁碟上的 `.ics` 檔而不是 `CacheKey` 那種 JSON blob、抓取途中要彈學期選單
/// 而 `run()` 的 `fetch` 是純粹的取值函式。
class CalendarRepository {
  CalendarRepository();

  static CalendarRepository instance = CalendarRepository();

  /// 取得本機的 `.ics` 路徑，必要時先下載。
  ///
  /// 檔案已經存在且 [forceUpdate] 為 false 時完全不碰網路——行事曆一學期只
  /// 變幾次，而這個頁面每次進入都會呼叫。
  Future<Result<String>> getCalendarFile({bool forceUpdate = false}) async {
    final directory = await getApplicationSupportDirectory();
    final savePath = "${directory.path}/calendar.ics";

    if (!forceUpdate && await File(savePath).exists()) {
      return Ok(savePath);
    }

    // 進度框只蓋在真的在等網路的那兩段，中間問使用者要哪個學期時不蓋——
    // 不然選單已經開在上面了，底下還浮著一個「下載中」。
    var progress =
        TaskUiDelegate.instance.beginProgress(R.current.prepareDownload);
    try {
      final Map<String, String>? semesters;
      try {
        semesters = await NTUSTConnector.getCalendarUrl();
      } finally {
        progress.dismiss();
      }
      if (semesters == null || semesters.isEmpty) {
        return _fallback(savePath, R.current.downloadError);
      }

      final chosen = await TaskUiDelegate.instance
          .chooseOne(R.current.selectSemester, semesters);
      // 取消就不下載。以前這裡 fallback 成 semesters.values.first，使用者點掉
      // 選單就會拿到一份他沒選過的行事曆。
      //
      // 取消不是失敗：手上已經有檔案就原封不動回去，不要吐「取得最新資料
      // 失敗」——使用者只是改變主意，畫面上的行事曆仍然是好的。
      if (chosen == null) {
        if (await File(savePath).exists()) return Ok(savePath);
        return Failed(FetchFailed(R.current.calendarNoSemesterSelected));
      }

      progress = TaskUiDelegate.instance.beginProgress(R.current.downloading);

      // 先寫暫存檔並驗過內容才覆蓋正式檔。dio 的 validateStatus 放行到 500，
      // 404 或登入頁的 body 會被原封不動寫成 calendar.ics，而上面的閘門只看
      // 檔案存不存在、不驗內容也沒有 TTL——壞檔會永久留在磁碟上。
      final tempPath = "$savePath.download";
      await DioConnector.instance.download(chosen, (_) => tempPath);
      final tempFile = File(tempPath);
      final head =
          await tempFile.openRead(0, 200).transform(utf8.decoder).join();
      if (!head.contains("BEGIN:VCALENDAR")) {
        await tempFile.delete();
        throw Exception("downloaded file is not an ics");
      }
      await tempFile.rename(savePath);
      return Ok(savePath);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return _fallback(savePath, R.current.downloadError);
    } finally {
      progress.dismiss();
    }
  }

  /// 下載失敗時，磁碟上還有舊檔就當 [Stale]：斷網時使用者看到的是上一次
  /// 下載的行事曆，而不是空白。
  Future<Result<String>> _fallback(String savePath, String message) async {
    if (await File(savePath).exists()) {
      TaskUiDelegate.instance.toast(R.current.loadingCache);
      return Stale(savePath, FetchFailed(message));
    }
    return Failed(FetchFailed(message));
  }
}
