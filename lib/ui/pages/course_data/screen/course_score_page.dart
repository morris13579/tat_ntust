import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart'
    show MoodleWebApiConnector;
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/pages/photo_view.dart';
import 'package:flutter_app/ui/service/file_download.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

import '../../../../src/R.dart';

class CourseScorePage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  /// 三個（或兩個）分頁共用的狀態。頁面在進入時就把所有請求發完，
  /// 所以每個分頁只負責畫自己那一份。
  final CourseDataController controller;

  const CourseScorePage(
    this.courseInfo, {
    required this.controller,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseScorePageState();
}

class _CourseScorePageState extends State<CourseScorePage>
    with AutomaticKeepAliveClientMixin {
  /// null 代表還在載入。
  ///
  /// 請求不能寫進 build()，否則每一次 rebuild（切主題、切語言、鍵盤彈出、上層
  /// setState）都會重新發一次請求。狀態住在 controller 而不是這個 State：
  /// 三個分頁的請求要在進入頁面時一起發出去，而 PageView 只 mount 當前那一個。
  Rxn<Result<MoodleUserGradesEntity>> get _state => widget.controller.score;

  /// 展開了老師回饋的那幾列（key 是 grade item 的 id）。
  final Set<int> _expanded = {};

  // 沒有 initState 觸發請求：由頁面在進入時一次發完三個（或兩個），
  // 見 CourseDataController.loadAll / CourseDetailController.loadAll。

  Future<void> _load() => widget.controller.loadScore();

  @override
  Widget build(BuildContext context) {
    super.build(context); //如果使用AutomaticKeepAliveClientMixin需要呼叫
    return ResultView<MoodleUserGradesEntity>(
      state: _state,
      onRetry: _load,
      errorBuilder: (message) => ErrorPage(errorMsg: message),
      builder: buildTree,
    );
  }

  /// 成績清單。一列就是一個 [MoodleGradeItemEntity]。
  ///
  /// **刻意攤平、不做階層**：grade_items 沒有資料夾標題列，類別只是一列
  /// `itemtype == 'category'` 的類別總分，階層得靠 categoryid 自己重建，而類別
  /// 名稱伺服器根本沒送。與其猜，不如攤平，只保留與語系無關的強調：課程總分
  /// 粗體、類別總分半粗。
  Widget buildTree(MoodleUserGradesEntity scoreData) {
    // 不能用「itemname 是不是空的」當過濾條件：課程總分與類別總分那兩類列，
    // 伺服器送的 itemname 就是 null（Moodle 網頁版是前端自己補字），照名字濾
    // 會讓課程總分整列消失。
    final items = scoreData.gradeItems
        .where((item) => item.hasDisplayableContent)
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _buildGradeItem(items[index], index, items.length),
    );
  }

  /// 這一列要顯示的標題。
  ///
  /// 伺服器對課程總分與類別總分不送 itemname，那兩類要由 App 自己補字。判斷一律
  /// 用 itemType，不要比對中文字串——「課程總分」那幾個字是 Moodle 依**使用者的
  /// Moodle 介面語言**產生的，與 App 語系無關，比字串在英文介面下會靜靜失效。
  String _titleOf(MoodleGradeItemEntity item) {
    final name = item.itemName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (item.isCourseTotal) return R.current.courseTotal;
    if (item.isCategoryTotal) return R.current.categoryTotal;
    return "";
  }

  /// 一列成績。分數靠右、細節收在標題底下那一行——十幾列疊起來時，眼睛只需要
  /// 掃右邊那一欄。老師回饋是唯一會展開的東西，其餘四個值全在同一行講完。
  Widget _buildGradeItem(MoodleGradeItemEntity item, int index, int length) {
    final scheme = context.scheme;
    final text = context.text;
    final hasFeedback = _hasFeedback(item.feedback);
    final expanded = _expanded.contains(item.id);
    final emphasised = item.isCourseTotal || item.isCategoryTotal;
    // 三階：課程總分粗體、類別總分半粗、其餘一般。判斷一律用 itemType，
    // 不要比對中文字串——理由見 [_titleOf]。
    final weight = item.isCourseTotal
        ? FontWeight.bold
        : (item.isCategoryTotal ? FontWeight.w600 : FontWeight.w500);

    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
      child: Material(
        color: context.tokens.card,
        borderRadius: UIUtils.getBorderRadius(index, length),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // 沒有回饋的列不吃點擊：沒有事情可做的列不該假裝可以按。
          onTap: hasFeedback ? () => _toggle(item.id) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分數對的是標題加副標整塊的中線。靠上的話，有副標的列分數會
                // 黏在標題那一行，兩者一比就是沒對齊。
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleOf(item),
                            style: text.titleMedium?.copyWith(
                                color: scheme.onSurface, fontWeight: weight),
                          ),
                          if (_metaOf(item, hasFeedback).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _metaOf(item, hasFeedback),
                              style: AppTypography.tabular(
                                  (text.bodySmall ?? const TextStyle())
                                      .copyWith(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.45)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _score(item, emphasised),
                  ],
                ),
                if (hasFeedback && expanded) ...[
                  const SizedBox(height: 12),
                  _feedback(item),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggle(int id) => setState(() {
        if (!_expanded.remove(id)) _expanded.add(id);
      });

  /// 分數欄。沒有分數時印「尚未評分」而不是留白：留白看起來像畫面壞了。
  Widget _score(MoodleGradeItemEntity item, bool emphasised) {
    final scheme = context.scheme;
    final text = context.text;
    final grade = _plain(item.gradeFormatted);
    if (!_hasContent(grade)) {
      return Text(
        R.current.assignNotGraded,
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Text(
      grade,
      style: AppTypography.tabular(
          (emphasised ? text.titleMedium : text.titleLarge)!.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
        height: 1.2,
      )),
    );
  }

  /// 標題底下那一行：百分比、權量、全距，最後在有回饋時補一個「回饋」，
  /// 那是這一列可以點開的唯一提示——沒有這一個字的話，十幾列長得一模一樣，
  /// 看不出哪一列按下去會有東西。
  String _metaOf(MoodleGradeItemEntity item, bool hasFeedback) {
    final parts = [
      if (_hasContent(item.percentageFormatted))
        _plain(item.percentageFormatted),
      if (_hasContent(item.weightFormatted))
        "${R.current.weight} ${_plain(item.weightFormatted)}",
      if (_hasContent(item.rangeFormatted))
        "${R.current.fullRange} ${_plain(item.rangeFormatted)}",
      if (hasFeedback) R.current.gradeFeedbackTag,
    ];
    return parts.join(" · ");
  }

  /// 展開後的老師回饋：小標題、右邊的「收起」、回饋本文，附件由
  /// [_html] 在遇到 pluginfile 連結時就地換成檔案列。
  ///
  /// 收合用文字連結而不是箭頭圖示：一個裸箭頭在一段文字上方講不清楚它收的是
  /// 哪一塊。連結走 InkWell + Row 而不是 TextButton——主題給按鈕的 44 高與
  /// 左右各 16 的內距會把這一行推離小標題。
  Widget _feedback(MoodleGradeItemEntity item) {
    final scheme = context.scheme;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                R.current.assignFeedback,
                style:
                    text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            InkWell(
              onTap: () => _toggle(item.id),
              borderRadius: BorderRadius.circular(TatTokens.radiusButton),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  R.current.collapse,
                  style: text.labelLarge?.copyWith(color: scheme.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _html(item.feedback),
      ],
    );
  }

  /// Moodle 對「沒有值」送的是空字串或整串 `&nbsp;`（解碼邊界還原之後是
  /// U+00A0），兩種都要當成空。
  ///
  /// 還有第三種：未評分的項目 `gradeformatted`／`percentageformatted` 送的是
  /// 一個破折號。照字串長度算的話分數欄會印一個裸的「-」、副標第一段也會是
  /// 「-」，都是看起來像壞掉的畫面。整串只有破折號才算空——全距的 `0–100`
  /// 也含破折號，但它有數字。
  static bool _hasContent(String? content) {
    final plain = _plain(content);
    return plain.isNotEmpty && !_onlyDashes.hasMatch(plain);
  }

  static final RegExp _onlyDashes = RegExp(r"^[-\u2010-\u2015\s]+$");

  /// 這一列有沒有老師回饋。
  ///
  /// 不能拿 [_hasContent] 來問：`feedback` 是 HTML，Moodle 對「沒有回饋」
  /// 也可能送一個 `<div class="no-overflow"></div>` 這樣的空殼。照字串長度算
  /// 的話每一列都會掛上「回饋」，等於這個提示不存在，也等於每一列都點得開、
  /// 點開卻是空的。
  static bool _hasFeedback(String? content) {
    final html = content ?? "";
    if (html.trim().isEmpty) return false;
    // 只有圖片或附件、一個字都沒有的回饋照樣算數。
    if (_mediaTag.hasMatch(html)) return true;
    return _hasContent(html.replaceAll(_anyTag, " "));
  }

  static final RegExp _anyTag = RegExp(r"<[^>]*>");
  static final RegExp _mediaTag =
      RegExp(r"<\s*(img|a|video|audio|iframe)\b", caseSensitive: false);

  /// `*formatted` 是純文字（HTML 實體已在 `MoodleRepository.normalizeScore`
  /// 還原），只是伺服器會用不換行空格當單位的間隔（`85.00\u00a0%`），
  /// 排版上要當成普通空白。
  static String _plain(String? content) => (content ?? "")
      .replaceAll("\u00a0", " ")
      .replaceAll("&nbsp;", " ")
      .trim();

  /// 回饋仍然走 HtmlWidget：`feedback` 是 HTML（feedbackformat 是 Moodle 的
  /// format id），而且可能含 `<img>`，點下去要能開 PhotoView。
  ///
  /// 老師夾帶的檔案在這一支 WS 裡沒有自己的欄位，它就是回饋 HTML 裡一個指向
  /// pluginfile 的 `<a>`。所以附件不另外開一區，而是在原地把那個連結換成
  /// 檔案列——順序、位置都還是老師寫的那一個。
  Widget _html(String content) {
    return HtmlWidget(content, textStyle: context.text.bodyLarge,
        customWidgetBuilder: (element) {
      if (element.localName == 'a') {
        final url = element.attributes["href"] ?? "";
        if (!_isMoodleFileUrl(url)) return null;
        final name = _fileNameOf(element.text, url);
        return MoodleFileTile(
          filename: name,
          onTap: () => unawaited(FileDownload.download(
            context,
            MoodleWebApiConnector.fileUrlWithToken(url),
            widget.courseInfo.main.course.name,
            name: name,
          )),
        );
      }
      if (element.localName == 'img') {
        var url = element.attributes["src"] ?? "";
        return FutureBuilder<Uint8List?>(
            future: DioConnector.instance.getData(ConnectorParameter(url)),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: GestureDetector(
                      onTap: () {
                        Get.to(PhotoView(imageData: snapshot.data!));
                      },
                      child: Image.memory(snapshot.data!)),
                );
              }
              // 少了這個分支，下載失敗會永遠停在轉圈。
              if (snapshot.hasError ||
                  snapshot.connectionState == ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(LucideIcons.imageOff),
                );
              }
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: LoadingPage(
                  isLoading: true,
                  isShowBackground: false,
                ),
              );
            });
      }
      return null;
    });
  }

  /// 只認 Moodle 自己的檔案路徑。老師在回饋裡貼的一般網址要留在文字裡當連結，
  /// 換成一列「下載」會騙人：那個網址後面不一定是檔案。
  static bool _isMoodleFileUrl(String url) =>
      url.contains("/pluginfile.php/") || url.contains("/tokenpluginfile.php/");

  /// 連結文字就是老師看到的檔名；空的時候退回網址最後一段。
  static String _fileNameOf(String linkText, String url) {
    final label = linkText.trim();
    if (label.isNotEmpty) return label;
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    for (final segment in segments.reversed) {
      if (segment.isNotEmpty) return segment;
    }
    return url;
  }

  @override
  bool get wantKeepAlive => true;
}
