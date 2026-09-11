import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:get/get.dart';

/// 討論串頁（公告與一般討論區共用）的狀態；由頁面的 State 建立與 [dispose]。
class CourseForumThreadController {
  CourseForumThreadController({
    required this.discussionId,
    this.courseId = '',
    this.forumId = 0,
  });

  final int discussionId;

  /// 附件政策要從 `get_forums_by_courses` 拿 forum record，那一支吃的是課號。
  final String courseId;

  /// forum instance id。**只有附件政策要用它**；0（舊快取）時附件入口收起來，
  /// 回覆／編輯／刪除照常——那三件事都不需要 forum record。
  final int forumId;

  final posts = Rxn<Result<List<MoodleForumPost>>>();

  /// 不快取：過期的「你可以附檔」比沒有答案更糟。null ＝還沒問到 ⇒ 不給。
  final attachPolicy = Rxn<ForumAttachPolicy>();

  ForumAttachPolicy get policy =>
      attachPolicy.value ?? const ForumAttachPolicy.off();

  /// 問不到就是「不給附件」——不知道在附件上等於不給。
  Future<void> loadAttachPolicy() async {
    if (forumId <= 0 || courseId.isEmpty) {
      attachPolicy.value = const ForumAttachPolicy.off();
      return;
    }
    final result = await MoodleRepository.instance
        .getForumAttachPolicy(courseId: courseId, forumId: forumId);
    attachPolicy.value = result.dataOrNull ?? const ForumAttachPolicy.off();
  }

  /// 手上這份資料是不是「這一趟真的抓到的」。
  ///
  /// 編輯與刪除的入口只在這裡為真時才畫：`capabilities.edit` / `delete` 是
  /// **抓取當下**算出來的快照，而編輯窗長度（`$CFG->maxeditingtime`）沒有任何
  /// web service 讀得到——`Stale`（快取／離線／送出後重抓失敗）時那兩顆按鈕
  /// 就開始說謊。回覆維持現行行為，不受這條限制。
  bool get fresh => posts.value is Ok<List<MoodleForumPost>>;

  /// 重新載入。**已經在畫面上的貼文不會被丟掉**：剛送出的那一則已經併進
  /// `posts` 了，這一趟失敗時退回 `Stale` 而不是 `Failed`，使用者才不會看到
  /// 自己的回覆消失、或整頁變成錯誤畫面——那則回覆確實送出去了。
  ///
  /// [keepVisible] 是送出後那一趟重抓用的：清成 null 會讓整串（含剛送出的
  /// 那一則）在一趟來回之間變成轉圈再長回來，同樣是「回覆消失」。進頁面的
  /// 第一次載入與使用者自己按的重試維持預設，那裡的轉圈就是回饋本身。
  Future<void> loadPosts({bool keepVisible = false}) async {
    final previous = posts.value?.dataOrNull;
    if (!keepVisible || previous == null) posts.value = null;
    final result =
        await MoodleRepository.instance.getDiscussionPosts(discussionId);
    posts.value = switch (result) {
      Failed<List<MoodleForumPost>>(:final reason) when previous != null =>
        Stale<List<MoodleForumPost>>(previous, reason),
      _ => result,
    };
  }

  Future<Result<ForumReplyOutcome>> reply({
    required int postId,
    required String subject,
    required String text,
    List<File> attachments = const [],
    ForumAttachPolicy policy = const ForumAttachPolicy.off(),
    void Function(ForumTransferProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) =>
      MoodleRepository.instance.postReply(
        postId: postId,
        subject: subject,
        text: text,
        attachments: attachments,
        policy: policy,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

  /// [inlineHtml] 非 null 時走所見即所得那條路（[text] 不再是純文字）；
  /// [inlineFiles] 是那篇貼文的 `messageinlinefiles`。
  Future<Result<ForumEditOutcome>> editPost({
    required int postId,
    required String subject,
    required String text,
    required int rawFormat,
    required List<MoodleForumFile> keepAttachments,
    required List<File> newAttachments,
    required bool hadAttachments,
    String? inlineHtml,
    List<MoodleForumFile> inlineFiles = const [],
    ForumAttachPolicy policy = const ForumAttachPolicy.off(),
    void Function(ForumTransferProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) =>
      MoodleRepository.instance.editPost(
        postId: postId,
        subject: subject,
        text: text,
        rawFormat: rawFormat,
        keepAttachments: keepAttachments,
        newAttachments: newAttachments,
        hadAttachments: hadAttachments,
        inlineHtml: inlineHtml,
        inlineFiles: inlineFiles,
        policy: policy,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

  Future<Result<bool>> deletePost(
          {required int postId, required bool isTopicPost}) =>
      MoodleRepository.instance.deletePost(
        postId: postId,
        isTopicPost: isTopicPost,
        discussionId: discussionId,
      );

  /// 按下編輯時的那一趟：拿新鮮的 `capabilities.edit` 與**原文**。
  Future<ForumPostEdit?> loadPostForEdit(int postId) =>
      MoodleRepository.instance.fetchPostForEdit(postId);

  /// 把剛送出的回覆併進畫面與快取。`run()` 只在 fetch 成功那一刻寫快取，而
  /// 寫入路徑沒有 `cache:`，少了這一步離線重開會看不到自己剛發的那一則。
  Future<void> appendPost(MoodleForumPost added) async {
    final merged =
        MoodleForumUtils.mergePost(posts.value?.dataOrNull ?? const [], added);
    posts.value = Ok<List<MoodleForumPost>>(merged);
    await MoodleRepository.instance.saveDiscussionPosts(discussionId, merged);
  }

  /// 編輯成功後把更新過的那一篇併回本機與快取（`mergePost` 同 id 就地取代）。
  /// 理由同 [appendPost]：少了這一步離線重開會看到編輯前的內容。
  Future<void> replacePost(MoodleForumPost updated) => appendPost(updated);

  /// 刪除成功後把那一列從本機與快取拿掉。
  ///
  /// **不是樂觀移除**：只在伺服器已經回報成功之後才呼叫。Moodle 對有子貼文的
  /// 貼文是換成墓碑（`isdeleted`）而不是真的刪除，所以呼叫端接著仍要重抓一次
  /// 讓伺服器說了算。
  Future<void> removePost(int postId) async {
    final current = posts.value?.dataOrNull;
    if (current == null) return;
    final remaining = [
      for (final p in current)
        if (p.id != postId) p,
    ];
    posts.value = Ok<List<MoodleForumPost>>(remaining);
    await MoodleRepository.instance
        .saveDiscussionPosts(discussionId, remaining);
  }

  void dispose() {
    posts.close();
    attachPolicy.close();
  }
}
