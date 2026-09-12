import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/model/classroom/classroom_option.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

/// 教室借用系統（`cour01`）的查詢頁。
///
/// 三件事各自都有會咬人的地方，依序寫在下面：OIDC 交握、WebForms 的 postback
/// 順序、以及那張 DataGrid 的解析。整體的來龍去脈在 docs/EMPTY_CLASSROOM.md。
class ClassroomConnector {
  static const String host = "https://cour01.ntust.edu.tw";
  static const String _base = "$host/classroom_user";

  /// 查詢頁。**不要改成從 `Index.aspx` 進**：這一頁自己就會踢出 OIDC 交握
  /// （302 到 `SSO_login.aspx` 再到 ssoam2），少繞一趟。
  static const String queryUrl = "$_base/classroom_usecondition.aspx";

  /// ASP.NET Calendar 的 postback 參數是「距離 2000-01-01 幾天」。
  static final DateTime _calendarEpoch = DateTime.utc(2000, 1, 1);

  static const String _campusSelect = "DropdownCampusListID";
  static const String _buildingSelect = "DropDownBuildingListID";
  static const String _calendarId = "date_cal";
  static const String _gridId = "showinfo_grd";

  /// 分頁最多翻幾次。校本部 88 間教室分兩頁，留這個數字純粹是不要讓
  /// 解析失敗變成無窮迴圈。
  static const int _maxPages = 20;

  /// 上一次交握之後那張「已經選好校區」的頁面，`campusCode` → HTML。
  ///
  /// ASP.NET 的 ViewState 在同一個 session 裡可以重複送（實測連續五次不同
  /// 大樓、不同日期都正常），所以把它留著，之後每次查詢只要一個 postback。
  /// 壞掉的後果是良性的：站台會回一頁沒有 grid 的東西，[getUsage] 會清掉
  /// 這份記憶再從頭走一次。
  static final Map<String, String> _campusPage = {};

  /// 轉址鏈最多走幾站。實測是三站（cour01 → SSO_login → ssoam2），
  /// 留點餘裕，但不能無上限——轉址迴圈會變成掛住的請求。
  static const int _maxRedirects = 8;

  /// 自己一站一站走完轉址鏈，回最後那一站的內容。
  ///
  /// **不可以改回讓 Dio 自動跟轉址。** Dio 的自動轉址底下是 dart:io 的
  /// `HttpClient`，而攔截器只在最外層那一次請求跑一遍——`CookieManager`
  /// 因此完全不參與中途的每一站：
  ///
  /// - 往 ssoam2 那一站不會被帶上 `AuthServer`，站台於是把已經登入的人
  ///   當成訪客，送回登入頁。看起來與「SSO 過期」一模一樣。
  /// - `SSO_login.aspx` 回的 `OpenIdConnect.nonce.*` 不會被存下來，而
  ///   `signin-oidc` 要靠它驗授權碼。就算前一項僥倖過了，交握還是會失敗。
  ///
  /// 自己走的話每一站都是一次獨立的 Dio 請求，攔截器每一站都會跑。
  static Future<Response> _follow(
    String url, {
    Map<String, String>? data,
    String? referer,
  }) async {
    var target = url;
    var body = data;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final parameter = ConnectorParameter(target,
          data: body, referer: referer, followRedirects: false);
      final response = body == null
          ? await Connector.getDataByGetResponse(parameter)
          : await Connector.getDataByPostResponse(parameter);

      final location = response.headers.value("location");
      final status = response.statusCode ?? 0;
      if (location == null || status < 300 || status > 399) return response;

      target = Uri.parse(target).resolve(location).toString();
      // 302 / 303 之後瀏覽器改用 GET 且不帶 body；307 / 308 才照原樣重送。
      if (status != 307 && status != 308) body = null;
    }
    throw Exception("classroom: 轉址超過 $_maxRedirects 站");
  }

  /// 交握 + 取得查詢頁。回 null 代表 SSO 沒過。
  ///
  /// 站台走的是 OIDC 而且 `response_mode=form_post`：ssoam2 不是用 302 把
  /// 授權碼送回來，而是回一頁**帶著自動送出表單的 HTML**。跟著 302 跟不到
  /// 終點，那張表單一定要自己再 POST 一次——這就是 ARCHITECTURE.md 說選課
  /// 系統「交握不會完成」的那一段，補的就是這裡。
  static Future<String?> _openQueryPage() async {
    var html = (await _follow(queryUrl)).toString();
    if (_isQueryPage(html)) return html;

    final bridge = parseFormPost(html);
    if (bridge == null) {
      // 沒有授權碼表單，代表 ssoam2 把我們留在登入頁。這裡不自己重登：
      // `run()` 的重試迴圈會 invalidate 之後再跑一輪。
      Log.d("[classroom] 沒拿到授權碼表單，SSO 應該已經過期");
      return null;
    }

    final posted =
        await _follow(bridge.action, data: bridge.fields, referer: queryUrl);
    html = posted.toString();
    // signin-oidc 的 302 會回到當初踢出交握的那一頁，多半已經就是查詢頁；
    // 不是的話再要一次。
    if (_isQueryPage(html)) return html;
    html = (await _follow(queryUrl)).toString();
    return _isQueryPage(html) ? html : null;
  }

  /// 校區與各自底下的大樓。
  ///
  /// 大樓清單是站台在「選了校區」的那次 postback 才生出來的，所以一個校區
  /// 要一次 postback。順便把那張頁面留進 [_campusPage]。
  static Future<List<ClassroomCampusJson>?> getCampuses() async {
    try {
      final page = await _openQueryPage();
      if (page == null) return null;

      final campuses = <ClassroomCampusJson>[];
      for (final campus in parseOptions(page, _campusSelect)) {
        final selected = await _postBack(page, _campusSelect,
            values: {_campusSelect: campus.code});
        if (!_isQueryPage(selected)) {
          Log.e("[classroom] 選校區 ${campus.code} 之後回的不是查詢頁");
          return null;
        }
        _campusPage[campus.code] = selected;
        campuses.add(ClassroomCampusJson(
          code: campus.code,
          name: campus.name,
          buildings: parseOptions(selected, _buildingSelect),
        ));
      }
      return campuses.isEmpty ? null : campuses;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  /// 某一天、某個校區（[buildingCode] 為 null 就是整個校區）的教室使用情形。
  ///
  /// **postback 的順序不能省。** 初始頁面的大樓下拉是空的，直接送一個大樓
  /// 代號進去會被 `__EVENTVALIDATION` 擋下來——而站台回的是 **HTTP 500 的
  /// 執行階段錯誤頁**，不是空結果。Dio 的 `validateStatus` 放行到 500，所以
  /// 那一頁會安安靜靜地變成「解析不出 grid」。要先選校區讓它把大樓選項畫出來，
  /// 之後校區、大樓與日期才能在**同一個** postback 裡一起送。
  static Future<ClassroomUsageJson?> getUsage({
    required String campusCode,
    required DateTime date,
    String? buildingCode,
  }) async {
    try {
      final usage = await _fetchUsage(campusCode, date, buildingCode);
      if (usage != null) return usage;

      // 留著的 ViewState 可能已經不能用了，丟掉重來一次。沒有留著的話就是
      // 真的失敗，不必再跑第二趟。
      if (_campusPage.remove(campusCode) == null) return null;
      Log.d("[classroom] ViewState 失效，重新交握一次");
      return _fetchUsage(campusCode, date, buildingCode);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<ClassroomUsageJson?> _fetchUsage(
      String campusCode, DateTime date, String? buildingCode) async {
    var page = _campusPage[campusCode];
    if (page == null) {
      final opened = await _openQueryPage();
      if (opened == null) return null;
      page = await _postBack(opened, _campusSelect,
          values: {_campusSelect: campusCode});
      if (!_isQueryPage(page)) return null;
      _campusPage[campusCode] = page;
    }

    // 日曆、校區、大樓一次送完。事件是日曆，另外兩個是隨表單一起帶過去的值。
    final values = {_campusSelect: campusCode};
    if (buildingCode != null) values[_buildingSelect] = buildingCode;
    var html = await _postBack(page, _calendarId,
        argument: dayArgument(date), values: values);

    final rooms = <ClassroomRowJson>[];
    for (var pageIndex = 1; pageIndex <= _maxPages; pageIndex++) {
      final parsed = parseGrid(html);
      if (parsed == null) return null;
      rooms.addAll(parsed);

      final next = parsePagerTarget(html, pageIndex + 1);
      if (next == null) break;
      html = await _postBack(html, next.target, argument: next.argument);
    }

    return ClassroomUsageJson(
      campusCode: campusCode,
      buildingCode: buildingCode,
      date: DateTime(date.year, date.month, date.day),
      rooms: rooms,
      fetchedAt: DateTime.now(),
    );
  }

  /// 送一次 `__doPostBack`。[values] 覆寫表單上原本的值。
  static Future<String> _postBack(
    String html,
    String target, {
    String argument = '',
    Map<String, String> values = const {},
  }) async {
    final fields = formFields(html)
      ..addAll(values)
      ..['__EVENTTARGET'] = target
      ..['__EVENTARGUMENT'] = argument;
    final response = await _follow(queryUrl, data: fields, referer: queryUrl);
    return response.toString();
  }

  /// 這一份 HTML 是不是查詢頁本身。判準是校區下拉在不在。
  static bool _isQueryPage(String html) => html.contains(_campusSelect);

  /// ASP.NET Calendar 的 postback 參數：距離 2000-01-01 幾天。
  ///
  /// 用 UTC 相減，不然跨日光節約時間的時區會少算或多算一天。
  @visibleForTesting
  static String dayArgument(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    return utc.difference(_calendarEpoch).inDays.toString();
  }

  /// OIDC 的 `response_mode=form_post` 橋接頁。不是那一頁就回 null。
  @visibleForTesting
  static FormPost? parseFormPost(String html) {
    for (final form in parse(html).getElementsByTagName("form")) {
      final action = form.attributes["action"];
      if (action == null || action.isEmpty) continue;
      final fields = <String, String>{};
      for (final input in form.getElementsByTagName("input")) {
        final name = input.attributes["name"];
        if (name != null) fields[name] = input.attributes["value"] ?? '';
      }
      // 授權碼在才算數。ssoam2 的登入表單也有 action 與一堆 input，
      // 少了這個條件會把「請重新登入」當成交握成功。
      if (fields.containsKey("code") || fields.containsKey("id_token")) {
        return FormPost(action, fields);
      }
    }
    return null;
  }

  /// 表單會送出的所有欄位，[__VIEWSTATE] 那一票隱藏欄位就是靠這個帶下去的。
  @visibleForTesting
  static Map<String, String> formFields(String html) {
    final fields = <String, String>{};
    final form = parse(html).querySelector("form");
    if (form == null) return fields;

    for (final input in form.getElementsByTagName("input")) {
      final name = input.attributes["name"];
      if (name == null) continue;
      final type = (input.attributes["type"] ?? "text").toLowerCase();
      if (type == "submit" || type == "button" || type == "image") continue;
      // 沒有勾的 checkbox / radio 本來就不會被送出。
      if ((type == "checkbox" || type == "radio") &&
          !input.attributes.containsKey("checked")) {
        continue;
      }
      fields[name] = input.attributes["value"] ?? '';
    }

    for (final select in form.getElementsByTagName("select")) {
      final name = select.attributes["name"];
      if (name == null) continue;
      final options = select.getElementsByTagName("option");
      final chosen = options.cast<Element?>().firstWhere(
          (o) => o!.attributes.containsKey("selected"),
          orElse: () => options.isEmpty ? null : options.first);
      fields[name] = chosen?.attributes["value"] ?? '';
    }
    return fields;
  }

  /// 下拉選單的選項，去掉「請選擇…」那一個（value 是空字串）。
  @visibleForTesting
  static List<ClassroomOptionJson> parseOptions(String html, String name) {
    final select = parse(html).querySelector('select[name="$name"]');
    if (select == null) return const [];
    final options = <ClassroomOptionJson>[];
    for (final option in select.getElementsByTagName("option")) {
      final code = option.attributes["value"] ?? '';
      if (code.isEmpty) continue;
      options.add(
          ClassroomOptionJson(code: code, name: option.text.trim()));
    }
    return options;
  }

  /// 那張 DataGrid。**找不到 grid 回 null，找得到但沒有資料列回空陣列**——
  /// 兩者完全不同：週六日站台真的一列都不回（正常），而被導回登入頁或踩到
  /// 500 錯誤頁時整張表都不存在（失敗）。壓成同一個值會讓失敗看起來像是
  /// 「今天全部教室都空著」。
  @visibleForTesting
  static List<ClassroomRowJson>? parseGrid(String html) {
    final grid = parse(html).getElementById(_gridId);
    if (grid == null) return null;

    final rows = _directRows(grid);
    if (rows.isEmpty) return null;

    final result = <ClassroomRowJson>[];
    // 第一列是表頭，最後一列是分頁列，中間才是教室。
    for (final row in rows.skip(1)) {
      final cells = row.children.where((e) => e.localName == "td").toList();
      // 分頁列是一個 colspan 的儲存格，欄數對不上就不是資料列。
      if (cells.length != ClassroomUsageJson.sectionCount + 1) continue;
      final name = cells.first.text.trim();
      if (name.isEmpty) continue;
      result.add(ClassroomRowJson(
        name: name,
        slots: cells.skip(1).map(_parseSlot).toList(),
      ));
    }
    return result;
  }

  /// 一格。文字是課名加老師；內嵌的那張小表格是站台畫記號的地方。
  static ClassroomSlotJson _parseSlot(Element cell) {
    // 只走 td 的**直屬**節點：內嵌的小表格要跳過，不然它的空白會被當成
    // 課名的一部分；`<br>` 則是課名與老師之間的分隔線，要留成換行。
    final lines = <String>[''];
    for (final node in cell.nodes) {
      if (node is Text) {
        lines[lines.length - 1] += node.text;
      } else if (node is Element && node.localName == 'br') {
        lines.add('');
      }
    }
    final parts = lines
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    var marked = false;
    for (final node in cell.querySelectorAll("table, table td")) {
      final style = node.attributes["style"] ?? '';
      // 那張小表格本來就帶 `height:16px;width:80px`，尺寸不是記號，
      // 只有底色才是。
      if (node.attributes.containsKey("bgcolor") ||
          style.contains("background")) {
        marked = true;
        Log.d("[classroom] 格子有記號："
            "bgcolor=${node.attributes["bgcolor"]} style=$style");
        break;
      }
    }

    return ClassroomSlotJson(
      course: parts.isEmpty ? '' : parts.first,
      teacher: parts.length < 2 ? '' : parts.skip(1).join(' '),
      marked: marked,
    );
  }

  /// 分頁列上第 [page] 頁的 postback 目標，沒有那一頁就回 null。
  ///
  /// **目標不可以寫死。** 它長成 `showinfo_grd$_ctl54$_ctl1`，中間那個序號
  /// 是資料列數算出來的，翻到第二頁就變成 `_ctl42`。
  @visibleForTesting
  static PostBackTarget? parsePagerTarget(String html, int page) {
    final grid = parse(html).getElementById(_gridId);
    if (grid == null) return null;
    final rows = _directRows(grid);
    if (rows.isEmpty) return null;

    for (final link in rows.last.getElementsByTagName("a")) {
      if (link.text.trim() != page.toString()) continue;
      final match = RegExp(r"__doPostBack\('([^']*)','([^']*)'\)")
          .firstMatch(link.attributes["href"] ?? '');
      if (match != null) {
        return PostBackTarget(match.group(1)!, match.group(2)!);
      }
    }
    return null;
  }

  /// 表格的直屬 `tr`。HTML5 的解析器會自己補一層 `tbody`，所以不能直接讀
  /// `table.children`；也不能用 `querySelectorAll("tr")`，那會把每一格裡
  /// 內嵌小表格的列一起撈進來。
  static List<Element> _directRows(Element table) {
    final rows = <Element>[];
    for (final child in table.children) {
      if (child.localName == "tr") {
        rows.add(child);
      } else if (child.localName == "tbody" ||
          child.localName == "thead" ||
          child.localName == "tfoot") {
        rows.addAll(child.children.where((e) => e.localName == "tr"));
      }
    }
    return rows;
  }

  /// 丟掉留著的 ViewState。登出時要清，它是上一位使用者那個 cour01 session
  /// 上的頁面狀態。
  static void clearCachedPages() => _campusPage.clear();
}

/// 一張要自己再送一次的表單。
@visibleForTesting
class FormPost {
  const FormPost(this.action, this.fields);

  final String action;
  final Map<String, String> fields;
}

/// `__doPostBack(target, argument)`。
@visibleForTesting
class PostBackTarget {
  const PostBackTarget(this.target, this.argument);

  final String target;
  final String argument;
}
