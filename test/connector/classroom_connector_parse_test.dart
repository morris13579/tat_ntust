import 'package:flutter_app/src/connector/classroom_connector.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/model/course_table/course_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// 教室查詢頁的解析。HTML 刻意手寫成最小的一份，但**每一個怪形狀都照站台
/// 的原樣保留**：`</br>` 這個收尾標籤、每一格內嵌的那張小表格、以及分頁列
/// 那個 colspan 的儲存格。老師名字全是化名。
void main() {
  /// 站台的一格：先是一張固定尺寸的小表格（畫記號用），再來是課名與老師。
  ///
  /// [tableStyle] 整個換掉那張小表格的 style，不是接在後面——同一個屬性寫
  /// 兩次的話解析器只認第一個，記號永遠測不出來。
  String slot(
    String course,
    String teacher, {
    String tableAttrs = '',
    String tableStyle = 'height:16px;width:80px;',
  }) {
    final inner = '<table id="showinfo_grd__ctl3_Table3" border="0" '
        'style="$tableStyle"$tableAttrs><tr><td></td></tr></table>';
    final text = course.isEmpty ? '' : '\n\t\t$course</br>$teacher\n';
    return '<td nowrap="nowrap" style="font-size:10pt;">\n$inner$text</td>';
  }

  String row(String name, List<String> cells) =>
      '<tr><td>$name</td>${cells.join()}</tr>';

  String emptyRow(String name) =>
      row(name, List.generate(14, (_) => slot('', '')));

  /// 分頁列：一個跨滿版的儲存格，目前頁是 span、其餘是 LinkButton。
  String pager(int current, int pages, {int ctl = 54}) {
    final links = [
      for (var i = 1; i <= pages; i++)
        i == current
            ? '<span>$i</span>'
            : '<a href="javascript:__doPostBack(\'showinfo_grd\$_ctl$ctl'
                '\$_ctl${i - 1}\',\'\')">$i</a>'
    ].join(' ');
    return '<tr align="left"><td colspan="15">$links</td></tr>';
  }

  String header() => '<tr><td>教室</td>${[
        for (var i = 1; i <= 14; i++) '<td style="width:2.2cm;">第$i節</td>'
      ].join()}</tr>';

  String grid(String body) =>
      '<html><body><form name="Form2" method="post" '
      'action="./classroom_usecondition.aspx" id="Form2">'
      '<input type="hidden" name="__VIEWSTATE" value="VS-1" />'
      '<input type="hidden" name="__EVENTVALIDATION" value="EV-1" />'
      '<select name="DropdownCampusListID"><option value="">請選擇校區</option>'
      '<option value="HHC">華夏校區</option>'
      '<option value="HQ" selected="selected">校本部</option></select>'
      '<table id="showinfo_grd">$body</table></form></body></html>';

  group('parseGrid', () {
    test('課名與老師以 </br> 分開，不可以黏成一串', () {
      final html = grid(header() +
          row('T4-301', [
            slot('', ''),
            slot('文學作品導讀', '陳老師'),
            ...List.generate(12, (_) => slot('', '')),
          ]) +
          pager(1, 1));

      final rooms = ClassroomConnector.parseGrid(html)!;
      expect(rooms.length, 1);
      expect(rooms[0].name, 'T4-301');
      expect(rooms[0].slots.length, ClassroomUsageJson.sectionCount);
      expect(rooms[0].slots[0].isFree, isTrue);
      expect(rooms[0].slots[1].course, '文學作品導讀');
      expect(rooms[0].slots[1].teacher, '陳老師',
          reason: '黏成「文學作品導讀陳老師」就看不出哪裡是人名');
      expect(rooms[0].slots[1].isFree, isFalse);
    });

    test('內嵌小表格本來就有的尺寸樣式不是記號', () {
      final html = grid(header() + emptyRow('T4-301') + pager(1, 1));
      final rooms = ClassroomConnector.parseGrid(html)!;
      expect(rooms[0].slots.every((s) => s.marked), isFalse);
      expect(rooms[0].isFreeAllDay, isTrue);
    });

    test('底色才是記號，而且沒有課名也算被佔用', () {
      // 兩種畫法都要認得：站台的圖示說明擺明了會用顏色標「已預約」與
      // 「確定借用」，但實測二十八週一次都沒出現過，所以無從得知它用的是
      // bgcolor 還是 style。
      final marks = <String, String Function()>{
        'bgcolor': () => slot('', '', tableAttrs: ' bgcolor="Pink"'),
        'background-color': () => slot('', '',
            tableStyle: 'height:16px;width:80px;background-color:LightGreen;'),
      };
      marks.forEach((label, build) {
        final html = grid(header() +
            row('T4-301', [
              build(),
              ...List.generate(13, (_) => slot('', '')),
            ]) +
            pager(1, 1));
        final rooms = ClassroomConnector.parseGrid(html)!;
        expect(rooms[0].slots[0].marked, isTrue, reason: label);
        expect(rooms[0].slots[0].isFree, isFalse, reason: label);
        expect(rooms[0].isFreeAllDay, isFalse, reason: label);
      });
    });

    test('週末：表格在、資料列一列都沒有 → 空陣列，不是 null', () {
      // 這個分別是整個解析裡最要緊的一件事。站台在週六日真的一列都不回，
      // 而被導回登入頁或踩到 500 錯誤頁時整張表都不存在。壓成同一個值會讓
      // 「抓失敗」長得跟「今天全部教室都空著」一模一樣。
      final rooms = ClassroomConnector.parseGrid(grid(header() + pager(1, 1)));
      expect(rooms, isNotNull);
      expect(rooms, isEmpty);
    });

    test('沒有那張表格 → null', () {
      expect(ClassroomConnector.parseGrid('<html><body>請先登入</body></html>'),
          isNull);
      // 大樓代號對不上 ViewState 時站台回的是 HTTP 500 的執行階段錯誤頁，
      // 而 Dio 的 validateStatus 放行到 500，所以它會一路走到這裡。
      expect(
          ClassroomConnector.parseGrid(
              '<html><head><title>執行階段錯誤</title></head>'
              '<body><h2>伺服器發生錯誤</h2></body></html>'),
          isNull);
    });

    test('分頁列不會被當成一間教室', () {
      final html =
          grid(header() + emptyRow('T4-301') + emptyRow('T4-302') + pager(1, 2));
      final rooms = ClassroomConnector.parseGrid(html)!;
      expect(rooms.map((e) => e.name), ['T4-301', 'T4-302']);
    });
  });

  group('parsePagerTarget', () {
    test('目標是從 HTML 解出來的，不是寫死的', () {
      // 中間那個序號是資料列數算出來的，第一頁是 _ctl54、第二頁變成 _ctl42。
      final page1 = grid(header() + emptyRow('T4-301') + pager(1, 2, ctl: 54));
      final page2 = grid(header() + emptyRow('TR-209') + pager(2, 2, ctl: 42));

      final next = ClassroomConnector.parsePagerTarget(page1, 2)!;
      expect(next.target, 'showinfo_grd\$_ctl54\$_ctl1');
      expect(next.argument, '');

      final back = ClassroomConnector.parsePagerTarget(page2, 1)!;
      expect(back.target, 'showinfo_grd\$_ctl42\$_ctl0');
    });

    test('沒有下一頁就回 null，翻頁迴圈才停得下來', () {
      final page2 = grid(header() + emptyRow('TR-209') + pager(2, 2, ctl: 42));
      expect(ClassroomConnector.parsePagerTarget(page2, 3), isNull);
      final single = grid(header() + emptyRow('T4-301') + pager(1, 1));
      expect(ClassroomConnector.parsePagerTarget(single, 2), isNull);
    });

    test('目前這一頁是 span 不是連結，不會被自己撈到', () {
      final page1 = grid(header() + emptyRow('T4-301') + pager(1, 2));
      expect(ClassroomConnector.parsePagerTarget(page1, 1), isNull);
    });
  });

  group('formFields', () {
    test('ViewState 那一票隱藏欄位會被帶下去', () {
      final fields =
          ClassroomConnector.formFields(grid(header() + pager(1, 1)));
      expect(fields['__VIEWSTATE'], 'VS-1');
      expect(fields['__EVENTVALIDATION'], 'EV-1');
    });

    test('下拉送的是被選起來的那一個', () {
      final fields =
          ClassroomConnector.formFields(grid(header() + pager(1, 1)));
      expect(fields['DropdownCampusListID'], 'HQ');
    });

    test('沒有人被選起來時送第一個，跟瀏覽器一樣', () {
      const html = '<html><body><form>'
          '<select name="DropDownBuildingListID">'
          '<option value="">請選擇大樓</option>'
          '<option value="T4">第四教學大樓</option></select></form></body></html>';
      expect(ClassroomConnector.formFields(html)['DropDownBuildingListID'], '');
    });

    test('送出鈕與沒勾的 checkbox 不會被送出', () {
      const html = '<html><body><form>'
          '<input type="hidden" name="__VIEWSTATE" value="VS" />'
          '<input type="submit" name="Button2" value="我要借用教室" />'
          '<input type="checkbox" name="opt1" value="1" />'
          '<input type="checkbox" name="opt2" value="1" checked />'
          '</form></body></html>';
      final fields = ClassroomConnector.formFields(html);
      expect(fields.containsKey('Button2'), isFalse);
      expect(fields.containsKey('opt1'), isFalse);
      expect(fields['opt2'], '1');
    });
  });

  group('parseOptions', () {
    test('「請選擇…」那一項不算選項', () {
      final options = ClassroomConnector.parseOptions(
          grid(header() + pager(1, 1)), 'DropdownCampusListID');
      expect(options.map((e) => e.code), ['HHC', 'HQ']);
      expect(options.map((e) => e.name), ['華夏校區', '校本部']);
    });

    test('找不到那個下拉就回空清單', () {
      expect(ClassroomConnector.parseOptions('<html></html>', 'Nope'), isEmpty);
    });
  });

  group('parseFormPost（OIDC 的 response_mode=form_post）', () {
    test('授權碼那張表單認得出來', () {
      const html = '<!doctype html><html><body>'
          '<form name="form" method="post" '
          'action="https://cour01.ntust.edu.tw/classroom_user/signin-oidc">'
          '<input type="hidden" name="code" value="AUTH-CODE" />'
          '<input type="hidden" name="state" value="STATE" />'
          '<input type="hidden" name="iss" value="https://ssoam2.ntust.edu.tw/" />'
          '</form><script>document.form.submit();</script></body></html>';
      final bridge = ClassroomConnector.parseFormPost(html)!;
      expect(bridge.action,
          'https://cour01.ntust.edu.tw/classroom_user/signin-oidc');
      expect(bridge.fields['code'], 'AUTH-CODE');
      expect(bridge.fields['state'], 'STATE');
      expect(bridge.fields['iss'], 'https://ssoam2.ntust.edu.tw/');
    });

    test('ssoam2 的登入表單不算交握成功', () {
      // 沒有這個判準的話，SSO 過期會被當成交握完成，接著每一次查詢都在解析
      // 一張登入頁。登入表單一樣有 action，也一樣有一堆 input。
      const html = '<html><body><form action="/" method="POST">'
          '<input type="hidden" name="__RequestVerificationToken" value="T" />'
          '<input type="text" name="Username" />'
          '<input type="password" name="Password" />'
          '</form></body></html>';
      expect(ClassroomConnector.parseFormPost(html), isNull);
    });
  });

  group('dayArgument', () {
    test('ASP.NET Calendar 要的是距離 2000-01-01 幾天', () {
      // 站台當天回的就是這個值，對照 docs/EMPTY_CLASSROOM.md。
      expect(ClassroomConnector.dayArgument(DateTime(2026, 9, 11)), '9750');
      expect(ClassroomConnector.dayArgument(DateTime(2026, 10, 1)), '9770');
      expect(ClassroomConnector.dayArgument(DateTime(2000, 1, 1)), '0');
    });

    test('日光節約時間不會讓它差一天', () {
      // 用本地時間相減的話，跨過時制轉換的那幾天會少算或多算一天，
      // 查出來的是隔壁那一天的課表而且沒有任何錯誤訊息。
      for (var day = 1; day <= 28; day++) {
        final date = DateTime(2026, 3, day);
        final next = DateTime(2026, 3, day).add(const Duration(days: 1));
        final a = int.parse(ClassroomConnector.dayArgument(date));
        final b = int.parse(ClassroomConnector.dayArgument(next));
        expect(b - a, 1, reason: '2026-03-$day');
      }
    });
  });

  group('節次對位', () {
    test('站台的「第 N 節」就是 SectionNumber.values[N - 1]', () {
      // 驗證方式見 docs/EMPTY_CLASSROOM.md：把 querycourse 的 ClassRoomNo ×
      // Node 攤平之後與站台的表格對拚 3360 格，佔用與否完全一致。
      expect(ClassroomUsageJson.sectionAt(0), SectionNumber.t_1);
      expect(ClassroomUsageJson.sectionAt(3), SectionNumber.t_4);
      // 第五節是中午 12:20–13:10，內部代號 t_N。這一格錯位的話，下午每一節
      // 都會整排位移一格。
      expect(ClassroomUsageJson.sectionAt(4), SectionNumber.t_N);
      expect(ClassroomUsageJson.sectionAt(5), SectionNumber.t_5);
      expect(ClassroomUsageJson.sectionAt(9), SectionNumber.t_9);
      expect(ClassroomUsageJson.sectionAt(10), SectionNumber.t_A);
      expect(ClassroomUsageJson.sectionAt(13), SectionNumber.t_D);
    });

    test('欄位數與去掉 t_UnKnown 的 SectionNumber 一樣長', () {
      expect(ClassroomUsageJson.sectionCount, SectionNumber.values.length - 1);
    });
  });

  group('ClassroomRowJson', () {
    test('大樓代號取自教室編號的第一段', () {
      const row = ClassroomRowJson(name: 'T4-301', slots: []);
      expect(row.buildingCode, 'T4');
      expect(const ClassroomRowJson(name: 'IB-304', slots: []).buildingCode,
          'IB');
    });

    test('沒有分隔線時回整個名稱，不回空字串', () {
      // 呼叫端會拿它當分組的鍵，空字串會讓那些教室全部擠進同一組。
      expect(const ClassroomRowJson(name: 'E1306', slots: []).buildingCode,
          'E1306');
      expect(const ClassroomRowJson(name: '-305', slots: []).buildingCode,
          '-305');
    });
  });
}
