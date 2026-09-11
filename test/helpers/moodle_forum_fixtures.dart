import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_draft_area.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_access_information.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forums_by_courses.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';

/// test/fixtures/moodle_forum/ 底下的 JSON。形狀照 MOODLE_405_STABLE 的
/// mod/forum/externallib.php 與 post / stored_file exporter，帶著所有 TAT
/// 不建模的欄位（capabilities、urls、ratinginfo……），解析時必須被忽略而不是拋。
Map<String, dynamic> loadMoodleForumFixture(String name) => json.decode(
        File('test/fixtures/moodle_forum/$name.json').readAsStringSync())
    as Map<String, dynamic>;

/// `get_forums_by_courses` 回的是陣列本身，不是物件。
List<dynamic> loadMoodleForumListFixture(String name) => json.decode(
        File('test/fixtures/moodle_forum/$name.json').readAsStringSync())
    as List<dynamic>;

/// 走 connector 的公開純函式而不是直接 fromJson：正式路徑上 repository 拿到
/// （並寫進快取）的就是它們的輸出。
List<MoodleForum> fixtureForums([String name = 'get_forums_by_courses']) =>
    MoodleWebApiConnector.forumsOf(loadMoodleForumListFixture(name))!;

/// `name` 已還原 HTML 實體。
MoodleModForumGetForumDiscussions fixtureDiscussions() =>
    MoodleWebApiConnector.announcementsOf(
        loadMoodleForumFixture('get_forum_discussions'))!;

/// `subject` 已還原實體，`message` 的 `@@PLUGINFILE@@` 已換成真網址。
List<MoodleForumPost> fixturePosts([String name = 'get_discussion_posts']) =>
    MoodleWebApiConnector.discussionPostsOf(loadMoodleForumFixture(name))!;

/// 原始 fromJson，沒有經過 connector 的還原。給模型的解析契約用。
MoodleModForumGetDiscussionPosts rawFixturePosts(
        [String name = 'get_discussion_posts']) =>
    MoodleModForumGetDiscussionPosts.fromJson(loadMoodleForumFixture(name));

/// `core_course_get_contents` 的討論區清單，給名稱比對那條退路用。
List<MoodleCoreCourseGetContents> fixtureCourseContents() =>
    loadMoodleForumListFixture('course_contents_forum')
        .map((e) =>
            MoodleCoreCourseGetContents.fromJson(Map<String, dynamic>.from(e)))
        .toList();

/// `get_forum_access_information` 的 36 個 `can*`。**故意不含 caneditownpost**
/// ——access.php 沒有那個 capability。
MoodleForumAccess fixtureForumAccess(
        [String name = 'get_forum_access_information']) =>
    MoodleWebApiConnector.accessOf(loadMoodleForumFixture(name))!;

/// `prepare_draft_area_for_post`。`files[]` 的網址欄位是 **fileurl**
/// （external_files），不是貼文附件的 `url`。
MoodleForumDraftArea fixtureDraftArea(
        [String name = 'prepare_draft_area_for_post']) =>
    MoodleWebApiConnector.draftAreaOf(loadMoodleForumFixture(name))!;

/// `get_discussion_post`。回的是**原文**，沒有經過 `_normalizePost`。
ForumPostEdit fixturePostForEdit([String name = 'get_discussion_post']) =>
    MoodleWebApiConnector.postForEditOf(loadMoodleForumFixture(name))!;
