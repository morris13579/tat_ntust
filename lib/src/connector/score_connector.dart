import 'dart:async';
import 'dart:ui';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

class ScoreConnector {
  static const host = "https://stuinfosys.ntust.edu.tw";
  static const _scoreUrl = "$host/StuScoreQueryServ/StuScoreQuery/DisplayAll";

  static String clearString(String v) {
    return v.replaceAll("\n", "").trim();
  }

  /// 成績頁的路徑特徵。**只拿來記 log**：OIDC 交握中途那一站的查詢字串裡
  /// 也有 `client_id=StuScoreQueryServ`，拿它當判準必定誤中。見 [isScorePage]。
  static const String _scorePathMarker = "StuScoreQuery";

  /// 這份 HTML 是不是**真的**成績頁。
  ///
  /// **只看網址不夠。** 未登入時的轉址鏈是 stuinfosys → stuinfosys/Home/Login
  /// → `ssoam2/connect/authorize?client_id=StuScoreQueryServ&response_mode=form_post`，
  /// 最後那一站回的是一頁自動送出的表單，而它的網址同樣含 "StuScoreQuery"。
  /// 改看頁面內容之後，中途站一律不收網，讓交握跑完再回來。
  ///
  /// 兩個條件與 [parseScoreRank] 的守衛一致：`box-content alerts` 是排版容器，
  /// `<tbody>` 把它跟同樣用這個 class 的轉址頁／錯誤頁分開。
  static bool isScorePage(String html) {
    if (!html.contains("box-content alerts")) return false;
    return html.contains("<tbody") || html.contains("<TBODY");
  }

  /// 以 HeadlessInAppWebView 取得成績頁 HTML。逾時或載入失敗回 null。
  ///
  /// 三件事都不能拿掉：20 秒逾時（外層進度框是 allowClick=false 的全螢幕
  /// 遮罩，不收網使用者就只能殺掉 App）、每個回呼開頭的 isCompleted 檢查
  /// （client-side 導向會讓 onLoadStop 觸發第二次，重複 complete 丟出的
  /// StateError 在 plugin 的 async 回呼裡外層 try 接不到）、以及 finally 的
  /// dispose（原生端以 HashMap 強持有，不 dispose 不會被回收）。
  static Future<String?> _fetchScorePage() async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_scoreUrl)),
        // 給它真實尺寸（理由同 Ssoam2HeadlessLogin）：預設近乎零的 viewport
        // 會讓推進轉址鏈的 document.form.submit() 延後執行。
        initialSize: const Size(412, 892),
        onLoadStop: (controller, url) async {
          if (completer.isCompleted) return;
          // **只在真的走到成績頁時才收網。**
          //
          // onLoadStop 在轉址鏈的每一站都會觸發，而這個 headless WebView 沒有
          // 帶任何 cookie 出門，session 失效時第一站是 SSO 的轉址頁——它剛好
          // 有 `box-content alerts` 區塊卻沒有 <tbody>。在第一站就 complete
          // 會解析出一份非 null 的空 ScoreRankJson，呼叫端當成功寫回硬碟，
          // 成績頁就被清空且沒有任何錯誤訊息。
          //
          // 判準是頁面內容不是網址（見 [isScorePage]）。不符就直接 return，
          // 讓轉址鏈繼續跑。
          final html = await controller.getHtml() ?? "";
          if (isScorePage(html)) {
            completer.complete(html);
            return;
          }
          // 被踢回 SSO 的登入表單＝沒有有效 session，等下去不會變好，
          // 直接失敗，不要讓使用者盯著遮罩等滿 20 秒。
          if (Ssoam2Login.isLoginPage(url)) {
            Log.e("score page: 被導到 ssoam2 登入頁，平台 WebView 沒有有效 session");
            completer.complete(null);
            return;
          }
          Log.d("score page: 略過中途頁 ${url?.host}${url?.path}"
              " (marker=${url?.toString().contains(_scorePathMarker)})");
        },
        onReceivedError: (controller, request, error) {
          if (completer.isCompleted) return;
          Log.e("score page load error: ${error.description}");
          completer.complete(null);
        },
      );
      await webView.run();
      return await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          Log.e("score page timeout");
          return null;
        },
      );
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    } finally {
      await webView?.dispose();
    }
  }

  static Future<ScoreRankJson?> getScoreRank() async {
    final result = await _fetchScorePage();
    if (result == null) return null;
    return parseScoreRank(result);
  }

  /// 把成績頁的 HTML 解析成 [ScoreRankJson]，看不懂就回 null。
  ///
  /// 抽成純函式是為了讓那兩道守衛（見內文）能在 CI 裡驗證——它們防的是
  /// 「解析失敗卻回傳非 null 的空結果」，那會讓呼叫端把硬碟上的成績蓋掉。
  static ScoreRankJson? parseScoreRank(String result) {
    // items 刻意在排名與成績兩段解析之間「不」重設：沒有排名表的學生
    // （例如新生）第一段解析會失敗，保留上一次的 items 正是他們仍能看到
    // 成績的原因。「順手修正」成重設，這些學生的成績會變空白且無錯誤訊息。
    List<Element> items = [];
    ScoreRankJson info = ScoreRankJson();

    try {
      final tagNode = parse(result);
      final nodes = tagNode.getElementsByClassName("box-content alerts");

      // 被導回登入頁（session 過期）時整頁沒有這個 class。少了這道 guard，
      // 函式會回傳一個「非 null 但完全空」的 ScoreRankJson，而呼叫端
      // （ScorePageController.initTask）把非 null 當成功，setScore + saveScore
      // 直接把使用者硬碟上的成績蓋成空白且沒有任何錯誤訊息。
      // 回 null 才會走到既有的 fail 流程。
      if (nodes.isEmpty) {
        Log.e("score page has no score table, probably redirected to login");
        return null;
      }
      // 第二道守衛：有 `box-content alerts` 不代表那是表格，轉址頁與錯誤頁
      // 也用這個 class 排版。判準是裡面有沒有 <tbody>——沒有的話下面的
      // `getElementsByTagName("tbody")[0]` 會丟 RangeError 被 inner catch 吞掉，
      // 同樣回傳「非 null 但完全空」的結果把硬碟蓋掉。新生（沒有排名表）走的
      // 是 nodes.length == 1 的路徑，那個區塊仍有 tbody，不會被誤傷。
      if (nodes[0].getElementsByTagName("tbody").isEmpty) {
        Log.e("score page: box-content alerts 裡沒有 tbody，不是成績表");
        return null;
      }

      //排名
      try {
        items = nodes[0]
            .getElementsByTagName("tbody")[0]
            .getElementsByTagName("tr");
        for (final node in items) {
          var i = node.getElementsByTagName("td");
          SemesterJson semester = SemesterJson(
            year: clearString(i[0].text).substring(0, 3),
            semester: clearString(i[0].text).substring(3),
          );
          RankJson rank = RankJson(
            classRank: clearString(i[1].text),
            departmentRank: clearString(i[2].text),
            averageScore: clearString(i[3].text),
            classRankYears: clearString(i[4].text),
            departmentRankYears: clearString(i[5].text),
            averageYears: clearString(i[6].text),
          );
          info.addRankBySemester(semester, rank);
        }
      } catch (e) {
        Log.d(e);
      }

      //成績
      if (nodes.length >= 2) {
        items = nodes[1]
            .getElementsByTagName("tbody")[0]
            .getElementsByTagName("tr");
      }

      for (final node in items) {
        var i = node.getElementsByTagName("td");
        SemesterJson semester = SemesterJson(
          year: clearString(i[1].text).substring(0, 3),
          semester: clearString(i[1].text).substring(3),
        );
        String score = clearString(i[5].text);
        if (["成績未到", "Grades not yet"].contains(score)) {
          score = "-";
        }
        ScoreItemJson item = ScoreItemJson(
          courseId: clearString(i[2].text),
          name: clearString(i[3].text),
          credit: clearString(i[4].text),
          score: score,
          remark: clearString(i[6].text),
          generalDimension: clearString(i[7].text),
        );
        info.addScoreBySemester(semester, item);
      }
      // 解析成功但零學期＝頁面看得懂卻沒有內容。對真的沒有成績的新生這是
      // 合法的，但它與「解析全部失敗」在型別上無法區分，而後者會蓋掉硬碟。
      // 回 null 讓呼叫端保留既有快取；新生的快取本來就是空的，不會有損失。
      if (info.info.isEmpty) {
        Log.e("score page: 解析出零個學期，不寫回快取");
        return null;
      }
      return info;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }
}
