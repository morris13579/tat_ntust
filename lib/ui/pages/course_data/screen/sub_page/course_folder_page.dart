import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/moodle_folder_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/service/file_download.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 資料夾模組的某一層。Moodle 只回檔案，子資料夾是從 `filepath` 推出來的，
/// 見 [MoodleFolderUtils]。
class CourseFolderPage extends StatelessWidget {
  const CourseFolderPage(
    this.courseInfo,
    this.modules, {
    this.path = MoodleFolderUtils.rootPath,
    super.key,
  });

  final CourseInfoJson courseInfo;
  final Modules modules;

  /// 目前所在的子路徑，頭尾都有 '/'。進子資料夾是把自己再推一次，
  /// 所以系統返回鍵天生就會回到上一層。
  final String path;

  List<String> get _segments => MoodleFolderUtils.segments(path);

  String get _title => _segments.isEmpty ? modules.name : _segments.last;

  String get _breadcrumb => [modules.name, ..._segments].join(' / ');

  @override
  Widget build(BuildContext context) {
    final listing = MoodleFolderUtils.listing(modules.contents, path: path);
    return Scaffold(
      appBar: baseAppbar(title: _title),
      body: listing.isEmpty
          ? EmptyState(
              icon: LucideIconsThin.folder,
              message: R.current.folderEmpty,
            )
          : _tree(context, listing),
    );
  }

  /// 一層可能有上百個檔案，所以列留在 sliver 裡逐列建構。一列一塊、彼此
  /// 差 2px（[UIUtils.getBorderRadius]），與 App 其他清單同一套。
  Widget _tree(BuildContext context, MoodleFolderListing listing) {
    final total = listing.folders.length + listing.files.length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(title: _breadcrumb, first: true),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
          sliver: SliverList.builder(
            itemCount: total,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
              child: Material(
                color: context.tokens.card,
                borderRadius: UIUtils.getBorderRadius(index, total),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _rowAt(context, listing, index),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 先子資料夾、再檔案。
  Widget _rowAt(BuildContext context, MoodleFolderListing listing, int index) {
    if (index < listing.folders.length) {
      return _folderTile(context, listing.folders[index]);
    }
    return _fileTile(context, listing.files[index - listing.folders.length]);
  }

  Widget _fileTile(BuildContext context, Contents c) {
    return MoodleFileTile(
      filename: c.filename,
      mimetype: c.mimetype,
      subtitle: _fileSubtitle(c),
      onTap: () => unawaited(FileDownload.download(
        context,
        MoodleWebApiConnector.fileUrlWithToken(c.fileurl),
        courseInfo.main.course.name,
        name: c.filename,
      )),
    );
  }

  Widget _folderTile(BuildContext context, MoodleSubFolder folder) {
    final scheme = Theme.of(context).colorScheme;
    return MoodleFileTile(
      filename: folder.name,
      subtitle: sprintf(R.current.folderFileCount, [folder.fileCount]),
      leading: Icon(LucideIconsThin.folder, size: 20, color: scheme.primary),
      trailing: Icon(LucideIcons.chevronRight,
          size: 17, color: scheme.onSurfaceVariant),
      // GetX 拿 widget 型別當路由名，同一頁再推一次會被 preventDuplicates
      // 當成重複而靜默不推，子資料夾就點不進去。
      onTap: () => unawaited(Get.to(
        () => CourseFolderPage(courseInfo, modules, path: folder.path),
        preventDuplicates: false,
      )),
    );
  }

  /// 「PDF · 2.4 MB · 3/1/2025 10:00」。副檔名排在最前面，和檔案分頁的
  /// 檔案列同一個順序。全部都沒有時回 null，那一列就維持單行。
  String? _fileSubtitle(Contents c) {
    final extension = FileIconUtils.extensionOf(c.filename)?.toUpperCase();
    final parts = [
      if (extension != null && extension.isNotEmpty) extension,
      if (c.filesize > 0) FileUtils.formatBytes(c.filesize, 1),
      if (c.timemodified > 0) _formatTime(c.timemodified),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _formatTime(int unix) => DateFormat.yMd()
      .add_jm()
      .format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));
}
