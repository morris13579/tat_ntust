// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `TAT`
  String get app_name {
    return Intl.message(
      'TAT',
      name: 'app_name',
      desc: '',
      args: [],
    );
  }

  /// `Loading data error, some wrong data will be cleared`
  String get loadDataFail {
    return Intl.message(
      'Loading data error, some wrong data will be cleared',
      name: 'loadDataFail',
      desc: '',
      args: [],
    );
  }

  /// `Agree`
  String get agree {
    return Intl.message(
      'Agree',
      name: 'agree',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get save {
    return Intl.message(
      'Save',
      name: 'save',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get error {
    return Intl.message(
      'Error',
      name: 'error',
      desc: '',
      args: [],
    );
  }

  /// `success`
  String get success {
    return Intl.message(
      'success',
      name: 'success',
      desc: '',
      args: [],
    );
  }

  /// `Warning`
  String get warning {
    return Intl.message(
      'Warning',
      name: 'warning',
      desc: '',
      args: [],
    );
  }

  /// `Sure`
  String get sure {
    return Intl.message(
      'Sure',
      name: 'sure',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message(
      'Cancel',
      name: 'cancel',
      desc: '',
      args: [],
    );
  }

  /// `Update`
  String get update {
    return Intl.message(
      'Update',
      name: 'update',
      desc: '',
      args: [],
    );
  }

  /// `Settings`
  String get setting {
    return Intl.message(
      'Settings',
      name: 'setting',
      desc: '',
      args: [],
    );
  }

  /// `Restart`
  String get restart {
    return Intl.message(
      'Restart',
      name: 'restart',
      desc: '',
      args: [],
    );
  }

  /// `Loading...`
  String get loading {
    return Intl.message(
      'Loading...',
      name: 'loading',
      desc: '',
      args: [],
    );
  }

  /// `noAppToOpen`
  String get noAppToOpen {
    return Intl.message(
      'noAppToOpen',
      name: 'noAppToOpen',
      desc: '',
      args: [],
    );
  }

  /// `Please connect to network`
  String get pleaseConnectToNetwork {
    return Intl.message(
      'Please connect to network',
      name: 'pleaseConnectToNetwork',
      desc: '',
      args: [],
    );
  }

  /// `load cache`
  String get loadingCache {
    return Intl.message(
      'load cache',
      name: 'loadingCache',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get login {
    return Intl.message(
      'Login',
      name: 'login',
      desc: '',
      args: [],
    );
  }

  /// `Account password has been saved`
  String get loginSave {
    return Intl.message(
      'Account password has been saved',
      name: 'loginSave',
      desc: '',
      args: [],
    );
  }

  /// `Please enter your account`
  String get accountNull {
    return Intl.message(
      'Please enter your account',
      name: 'accountNull',
      desc: '',
      args: [],
    );
  }

  /// `Please enter the password`
  String get passwordNull {
    return Intl.message(
      'Please enter the password',
      name: 'passwordNull',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get password {
    return Intl.message(
      'Password',
      name: 'password',
      desc: '',
      args: [],
    );
  }

  /// `Account`
  String get account {
    return Intl.message(
      'Account',
      name: 'account',
      desc: '',
      args: [],
    );
  }

  /// `Calendar`
  String get calendar {
    return Intl.message(
      'Calendar',
      name: 'calendar',
      desc: '',
      args: [],
    );
  }

  /// `An error occurred`
  String get alertError {
    return Intl.message(
      'An error occurred',
      name: 'alertError',
      desc: '',
      args: [],
    );
  }

  /// ` Download error`
  String get downloadError {
    return Intl.message(
      ' Download error',
      name: 'downloadError',
      desc: '',
      args: [],
    );
  }

  /// `Download...`
  String get downloading {
    return Intl.message(
      'Download...',
      name: 'downloading',
      desc: '',
      args: [],
    );
  }

  /// `Download complete`
  String get downloadComplete {
    return Intl.message(
      'Download complete',
      name: 'downloadComplete',
      desc: '',
      args: [],
    );
  }

  /// `Prepare download...`
  String get prepareDownload {
    return Intl.message(
      'Prepare download...',
      name: 'prepareDownload',
      desc: '',
      args: [],
    );
  }

  /// `APP will close`
  String get appWillClose {
    return Intl.message(
      'APP will close',
      name: 'appWillClose',
      desc: '',
      args: [],
    );
  }

  /// `isFocusUpdate`
  String get isFocusUpdate {
    return Intl.message(
      'isFocusUpdate',
      name: 'isFocusUpdate',
      desc: '',
      args: [],
    );
  }

  /// `login NTUST`
  String get loginNTUST {
    return Intl.message(
      'login NTUST',
      name: 'loginNTUST',
      desc: '',
      args: [],
    );
  }

  /// `Network error`
  String get networkError {
    return Intl.message(
      'Network error',
      name: 'networkError',
      desc: '',
      args: [],
    );
  }

  /// `Need validate captcha`
  String get needValidateCaptcha {
    return Intl.message(
      'Need validate captcha',
      name: 'needValidateCaptcha',
      desc: '',
      args: [],
    );
  }

  /// `An unknown error occurred`
  String get unknownError {
    return Intl.message(
      'An unknown error occurred',
      name: 'unknownError',
      desc: '',
      args: [],
    );
  }

  /// `Account password error`
  String get accountPasswordError {
    return Intl.message(
      'Account password error',
      name: 'accountPasswordError',
      desc: '',
      args: [],
    );
  }

  /// `Get schedule...`
  String get getCourse {
    return Intl.message(
      'Get schedule...',
      name: 'getCourse',
      desc: '',
      args: [],
    );
  }

  /// `Getting schedule error`
  String get getCourseError {
    return Intl.message(
      'Getting schedule error',
      name: 'getCourseError',
      desc: '',
      args: [],
    );
  }

  /// `Login course system...`
  String get loginCourse {
    return Intl.message(
      'Login course system...',
      name: 'loginCourse',
      desc: '',
      args: [],
    );
  }

  /// `Login course system error`
  String get loginCourseError {
    return Intl.message(
      'Login course system error',
      name: 'loginCourseError',
      desc: '',
      args: [],
    );
  }

  /// `Get semester list...`
  String get getCourseSemester {
    return Intl.message(
      'Get semester list...',
      name: 'getCourseSemester',
      desc: '',
      args: [],
    );
  }

  /// `Getting semester list error`
  String get getCourseSemesterError {
    return Intl.message(
      'Getting semester list error',
      name: 'getCourseSemesterError',
      desc: '',
      args: [],
    );
  }

  /// `Reading course materials...`
  String get getCourseDetail {
    return Intl.message(
      'Reading course materials...',
      name: 'getCourseDetail',
      desc: '',
      args: [],
    );
  }

  /// `Course data reading error`
  String get getCourseDetailError {
    return Intl.message(
      'Course data reading error',
      name: 'getCourseDetailError',
      desc: '',
      args: [],
    );
  }

  /// `Credit`
  String get credit {
    return Intl.message(
      'Credit',
      name: 'credit',
      desc: '',
      args: [],
    );
  }

  /// `Login Moodle...`
  String get loginMoodle {
    return Intl.message(
      'Login Moodle...',
      name: 'loginMoodle',
      desc: '',
      args: [],
    );
  }

  /// `Login Moodle error`
  String get loginMoodleError {
    return Intl.message(
      'Login Moodle error',
      name: 'loginMoodleError',
      desc: '',
      args: [],
    );
  }

  /// `Login Moodle...`
  String get loginMoodleWebApi {
    return Intl.message(
      'Login Moodle...',
      name: 'loginMoodleWebApi',
      desc: '',
      args: [],
    );
  }

  /// `Login Moodle error\nIf errors continue to occur, please try to disable Moodle WebAPI in the settings`
  String get loginMoodleWebApiError {
    return Intl.message(
      'Login Moodle error\nIf errors continue to occur, please try to disable Moodle WebAPI in the settings',
      name: 'loginMoodleWebApiError',
      desc: '',
      args: [],
    );
  }

  /// `Get Moodle members...`
  String get getMoodleMembers {
    return Intl.message(
      'Get Moodle members...',
      name: 'getMoodleMembers',
      desc: '',
      args: [],
    );
  }

  /// `Get Moodle members error`
  String get getMoodleMembersError {
    return Intl.message(
      'Get Moodle members error',
      name: 'getMoodleMembersError',
      desc: '',
      args: [],
    );
  }

  /// `Get course directory...`
  String get getMoodleCourseDirectory {
    return Intl.message(
      'Get course directory...',
      name: 'getMoodleCourseDirectory',
      desc: '',
      args: [],
    );
  }

  /// `Get course directory error`
  String get getMoodleCourseDirectoryError {
    return Intl.message(
      'Get course directory error',
      name: 'getMoodleCourseDirectoryError',
      desc: '',
      args: [],
    );
  }

  /// `get course info...`
  String get getMoodleCourseInfo {
    return Intl.message(
      'get course info...',
      name: 'getMoodleCourseInfo',
      desc: '',
      args: [],
    );
  }

  /// `get course info error`
  String get getMoodleCourseInfoError {
    return Intl.message(
      'get course info error',
      name: 'getMoodleCourseInfoError',
      desc: '',
      args: [],
    );
  }

  /// `get course announcement...`
  String get getMoodleCourseAnnouncement {
    return Intl.message(
      'get course announcement...',
      name: 'getMoodleCourseAnnouncement',
      desc: '',
      args: [],
    );
  }

  /// `get course announcement error`
  String get getMoodleCourseAnnouncementError {
    return Intl.message(
      'get course announcement error',
      name: 'getMoodleCourseAnnouncementError',
      desc: '',
      args: [],
    );
  }

  /// `get score...`
  String get getMoodleScore {
    return Intl.message(
      'get score...',
      name: 'getMoodleScore',
      desc: '',
      args: [],
    );
  }

  /// `get score error`
  String get getMoodleScoreError {
    return Intl.message(
      'get score error',
      name: 'getMoodleScoreError',
      desc: '',
      args: [],
    );
  }

  /// `get score...`
  String get getScore {
    return Intl.message(
      'get score...',
      name: 'getScore',
      desc: '',
      args: [],
    );
  }

  /// `get score error`
  String get getScoreError {
    return Intl.message(
      'get score error',
      name: 'getScoreError',
      desc: '',
      args: [],
    );
  }

  /// `get moodle course folder detail...`
  String get getMoodleCourseFolderDetail {
    return Intl.message(
      'get moodle course folder detail...',
      name: 'getMoodleCourseFolderDetail',
      desc: '',
      args: [],
    );
  }

  /// `get moodle course folder error`
  String get getMoodleCourseFolderDetailError {
    return Intl.message(
      'get moodle course folder error',
      name: 'getMoodleCourseFolderDetailError',
      desc: '',
      args: [],
    );
  }

  /// `check moodle support...`
  String get checkMoodleSupport {
    return Intl.message(
      'check moodle support...',
      name: 'checkMoodleSupport',
      desc: '',
      args: [],
    );
  }

  /// `test moodle api...`
  String get testMoodleApi {
    return Intl.message(
      'test moodle api...',
      name: 'testMoodleApi',
      desc: '',
      args: [],
    );
  }

  /// `Download All`
  String get downloadAll {
    return Intl.message(
      'Download All',
      name: 'downloadAll',
      desc: '',
      args: [],
    );
  }

  /// `MON`
  String get Monday {
    return Intl.message(
      'MON',
      name: 'Monday',
      desc: '',
      args: [],
    );
  }

  /// `TUE`
  String get Tuesday {
    return Intl.message(
      'TUE',
      name: 'Tuesday',
      desc: '',
      args: [],
    );
  }

  /// `WED`
  String get Wednesday {
    return Intl.message(
      'WED',
      name: 'Wednesday',
      desc: '',
      args: [],
    );
  }

  /// `THU`
  String get Thursday {
    return Intl.message(
      'THU',
      name: 'Thursday',
      desc: '',
      args: [],
    );
  }

  /// `FRI`
  String get Friday {
    return Intl.message(
      'FRI',
      name: 'Friday',
      desc: '',
      args: [],
    );
  }

  /// `SAT`
  String get Saturday {
    return Intl.message(
      'SAT',
      name: 'Saturday',
      desc: '',
      args: [],
    );
  }

  /// `SUN`
  String get Sunday {
    return Intl.message(
      'SUN',
      name: 'Sunday',
      desc: '',
      args: [],
    );
  }

  /// ``
  String get UnKnown {
    return Intl.message(
      '',
      name: 'UnKnown',
      desc: '',
      args: [],
    );
  }

  /// `Course`
  String get titleCourse {
    return Intl.message(
      'Course',
      name: 'titleCourse',
      desc: '',
      args: [],
    );
  }

  /// `Refresh`
  String get refresh {
    return Intl.message(
      'Refresh',
      name: 'refresh',
      desc: '',
      args: [],
    );
  }

  /// `Please enter student number`
  String get pleaseEnterStudentId {
    return Intl.message(
      'Please enter student number',
      name: 'pleaseEnterStudentId',
      desc: '',
      args: [],
    );
  }

  /// `Course number`
  String get courseId {
    return Intl.message(
      'Course number',
      name: 'courseId',
      desc: '',
      args: [],
    );
  }

  /// `Time`
  String get time {
    return Intl.message(
      'Time',
      name: 'time',
      desc: '',
      args: [],
    );
  }

  /// `Instructor`
  String get instructor {
    return Intl.message(
      'Instructor',
      name: 'instructor',
      desc: '',
      args: [],
    );
  }

  /// `Location`
  String get location {
    return Intl.message(
      'Location',
      name: 'location',
      desc: '',
      args: [],
    );
  }

  /// `Course Title`
  String get courseName {
    return Intl.message(
      'Course Title',
      name: 'courseName',
      desc: '',
      args: [],
    );
  }

  /// `Start class`
  String get startClass {
    return Intl.message(
      'Start class',
      name: 'startClass',
      desc: '',
      args: [],
    );
  }

  /// `Classroom`
  String get classroom {
    return Intl.message(
      'Classroom',
      name: 'classroom',
      desc: '',
      args: [],
    );
  }

  /// `Details`
  String get details {
    return Intl.message(
      'Details',
      name: 'details',
      desc: '',
      args: [],
    );
  }

  /// ` not support`
  String get noSupport {
    return Intl.message(
      ' not support',
      name: 'noSupport',
      desc: '',
      args: [],
    );
  }

  /// `No any favorite`
  String get noAnyFavorite {
    return Intl.message(
      'No any favorite',
      name: 'noAnyFavorite',
      desc: '',
      args: [],
    );
  }

  /// `Setting complete`
  String get settingComplete {
    return Intl.message(
      'Setting complete',
      name: 'settingComplete',
      desc: '',
      args: [],
    );
  }

  /// `Setup is complete, please add the weight again`
  String get settingCompleteWithError {
    return Intl.message(
      'Setup is complete, please add the weight again',
      name: 'settingCompleteWithError',
      desc: '',
      args: [],
    );
  }

  /// `Load favorite`
  String get loadFavorite {
    return Intl.message(
      'Load favorite',
      name: 'loadFavorite',
      desc: '',
      args: [],
    );
  }

  /// `Set as android weight`
  String get setAsAndroidWeight {
    return Intl.message(
      'Set as android weight',
      name: 'setAsAndroidWeight',
      desc: '',
      args: [],
    );
  }

  /// `Select semester`
  String get selectSemester {
    return Intl.message(
      'Select semester',
      name: 'selectSemester',
      desc: '',
      args: [],
    );
  }

  /// `Import course`
  String get importCourse {
    return Intl.message(
      'Import course',
      name: 'importCourse',
      desc: '',
      args: [],
    );
  }

  /// `Remarks`
  String get note {
    return Intl.message(
      'Remarks',
      name: 'note',
      desc: '',
      args: [],
    );
  }

  /// `Search`
  String get search {
    return Intl.message(
      'Search',
      name: 'search',
      desc: '',
      args: [],
    );
  }

  /// `Search credit`
  String get searchCredit {
    return Intl.message(
      'Search credit',
      name: 'searchCredit',
      desc: '',
      args: [],
    );
  }

  /// `Moodle`
  String get courseData {
    return Intl.message(
      'Moodle',
      name: 'courseData',
      desc: '',
      args: [],
    );
  }

  /// `The currently selected semester is %s, please be sure to select the correct one or it may cause an error`
  String get selectSemesterWarning {
    return Intl.message(
      'The currently selected semester is %s, please be sure to select the correct one or it may cause an error',
      name: 'selectSemesterWarning',
      desc: '',
      args: [],
    );
  }

  /// `Course`
  String get course {
    return Intl.message(
      'Course',
      name: 'course',
      desc: '',
      args: [],
    );
  }

  /// `Semester`
  String get semester {
    return Intl.message(
      'Semester',
      name: 'semester',
      desc: '',
      args: [],
    );
  }

  /// `Course times`
  String get courseTimes {
    return Intl.message(
      'Course times',
      name: 'courseTimes',
      desc: '',
      args: [],
    );
  }

  /// `Practical times`
  String get practicalTimes {
    return Intl.message(
      'Practical times',
      name: 'practicalTimes',
      desc: '',
      args: [],
    );
  }

  /// `Require option`
  String get requireOption {
    return Intl.message(
      'Require option',
      name: 'requireOption',
      desc: '',
      args: [],
    );
  }

  /// `Classroom no`
  String get classRoomNo {
    return Intl.message(
      'Classroom no',
      name: 'classRoomNo',
      desc: '',
      args: [],
    );
  }

  /// `Core ability`
  String get coreAbility {
    return Intl.message(
      'Core ability',
      name: 'coreAbility',
      desc: '',
      args: [],
    );
  }

  /// `course URL`
  String get courseURL {
    return Intl.message(
      'course URL',
      name: 'courseURL',
      desc: '',
      args: [],
    );
  }

  /// `Course object`
  String get courseObject {
    return Intl.message(
      'Course object',
      name: 'courseObject',
      desc: '',
      args: [],
    );
  }

  /// `Course content`
  String get courseContent {
    return Intl.message(
      'Course content',
      name: 'courseContent',
      desc: '',
      args: [],
    );
  }

  /// `Course textbook`
  String get courseTextbook {
    return Intl.message(
      'Course textbook',
      name: 'courseTextbook',
      desc: '',
      args: [],
    );
  }

  /// `Course Refbook`
  String get courseRefbook {
    return Intl.message(
      'Course Refbook',
      name: 'courseRefbook',
      desc: '',
      args: [],
    );
  }

  /// `Course note`
  String get courseNote {
    return Intl.message(
      'Course note',
      name: 'courseNote',
      desc: '',
      args: [],
    );
  }

  /// `Course grading`
  String get courseGrading {
    return Intl.message(
      'Course grading',
      name: 'courseGrading',
      desc: '',
      args: [],
    );
  }

  /// `Course remark`
  String get courseRemark {
    return Intl.message(
      'Course remark',
      name: 'courseRemark',
      desc: '',
      args: [],
    );
  }

  /// `選課總人數(本校/系統學校)`
  String get choosePeople {
    return Intl.message(
      '選課總人數(本校/系統學校)',
      name: 'choosePeople',
      desc: '',
      args: [],
    );
  }

  /// `選課人數上限`
  String get chooseUpBoundary {
    return Intl.message(
      '選課人數上限',
      name: 'chooseUpBoundary',
      desc: '',
      args: [],
    );
  }

  /// `本校初選人數上限(限舊生)：%s\n本校加退選人數上限/新生第一學期初選人數上限：%s\n系統校際選課人數上限：%s`
  String get choosePeopleString {
    return Intl.message(
      '本校初選人數上限(限舊生)：%s\n本校加退選人數上限/新生第一學期初選人數上限：%s\n系統校際選課人數上限：%s',
      name: 'choosePeopleString',
      desc: '',
      args: [],
    );
  }

  /// `member`
  String get member {
    return Intl.message(
      'member',
      name: 'member',
      desc: '',
      args: [],
    );
  }

  /// `Total member: `
  String get totalMember {
    return Intl.message(
      'Total member: ',
      name: 'totalMember',
      desc: '',
      args: [],
    );
  }

  /// `un support this class`
  String get unSupportThisClass {
    return Intl.message(
      'un support this class',
      name: 'unSupportThisClass',
      desc: '',
      args: [],
    );
  }

  /// `Sort by`
  String get sortBy {
    return Intl.message(
      'Sort by',
      name: 'sortBy',
      desc: '',
      args: [],
    );
  }

  /// `Create New folder`
  String get createNewFolder {
    return Intl.message(
      'Create New folder',
      name: 'createNewFolder',
      desc: '',
      args: [],
    );
  }

  /// `Create Folder`
  String get createFolder {
    return Intl.message(
      'Create Folder',
      name: 'createFolder',
      desc: '',
      args: [],
    );
  }

  /// `There's nothing here`
  String get nothingHere {
    return Intl.message(
      'There\'s nothing here',
      name: 'nothingHere',
      desc: '',
      args: [],
    );
  }

  /// `Cannot write to this Storage device!`
  String get cannotWrite {
    return Intl.message(
      'Cannot write to this Storage device!',
      name: 'cannotWrite',
      desc: '',
      args: [],
    );
  }

  /// `A Folder with that name already exists!`
  String get folderNameAlreadyExists {
    return Intl.message(
      'A Folder with that name already exists!',
      name: 'folderNameAlreadyExists',
      desc: '',
      args: [],
    );
  }

  /// `A File with that name already exists!`
  String get fileNameAlreadyExists {
    return Intl.message(
      'A File with that name already exists!',
      name: 'fileNameAlreadyExists',
      desc: '',
      args: [],
    );
  }

  /// `Rename item`
  String get renameItem {
    return Intl.message(
      'Rename item',
      name: 'renameItem',
      desc: '',
      args: [],
    );
  }

  /// `Rename`
  String get rename {
    return Intl.message(
      'Rename',
      name: 'rename',
      desc: '',
      args: [],
    );
  }

  /// `Notification`
  String get titleNotification {
    return Intl.message(
      'Notification',
      name: 'titleNotification',
      desc: '',
      args: [],
    );
  }

  /// `Delete`
  String get delete {
    return Intl.message(
      'Delete',
      name: 'delete',
      desc: '',
      args: [],
    );
  }

  /// `download`
  String get download {
    return Intl.message(
      'download',
      name: 'download',
      desc: '',
      args: [],
    );
  }

  /// `Download ready to start`
  String get downloadWillStart {
    return Intl.message(
      'Download ready to start',
      name: 'downloadWillStart',
      desc: '',
      args: [],
    );
  }

  /// `File attachment detected`
  String get fileAttachmentDetected {
    return Intl.message(
      'File attachment detected',
      name: 'fileAttachmentDetected',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to download the file`
  String get areYouSureToDownload {
    return Intl.message(
      'Are you sure you want to download the file',
      name: 'areYouSureToDownload',
      desc: '',
      args: [],
    );
  }

  /// `Check identity`
  String get checkIdentity {
    return Intl.message(
      'Check identity',
      name: 'checkIdentity',
      desc: '',
      args: [],
    );
  }

  /// `Origin password`
  String get originPassword {
    return Intl.message(
      'Origin password',
      name: 'originPassword',
      desc: '',
      args: [],
    );
  }

  /// `Different from the original password`
  String get passwordNotSame {
    return Intl.message(
      'Different from the original password',
      name: 'passwordNotSame',
      desc: '',
      args: [],
    );
  }

  /// `Dark mode`
  String get darkMode {
    return Intl.message(
      'Dark mode',
      name: 'darkMode',
      desc: '',
      args: [],
    );
  }

  /// `Download path`
  String get downloadPath {
    return Intl.message(
      'Download path',
      name: 'downloadPath',
      desc: '',
      args: [],
    );
  }

  /// `Open with external video player`
  String get openExternalVideo {
    return Intl.message(
      'Open with external video player',
      name: 'openExternalVideo',
      desc: '',
      args: [],
    );
  }

  /// `Recommend use MX player`
  String get openExternalVideoHint {
    return Intl.message(
      'Recommend use MX player',
      name: 'openExternalVideoHint',
      desc: '',
      args: [],
    );
  }

  /// `Not find support external video player`
  String get noSupportExternalVideoPlayer {
    return Intl.message(
      'Not find support external video player',
      name: 'noSupportExternalVideoPlayer',
      desc: '',
      args: [],
    );
  }

  /// `Cannot set this path as download path`
  String get selectDirectoryFail {
    return Intl.message(
      'Cannot set this path as download path',
      name: 'selectDirectoryFail',
      desc: '',
      args: [],
    );
  }

  /// `Use English interface`
  String get languageSwitch {
    return Intl.message(
      'Use English interface',
      name: 'languageSwitch',
      desc: '',
      args: [],
    );
  }

  /// `Will restart automatically`
  String get willRestart {
    return Intl.message(
      'Will restart automatically',
      name: 'willRestart',
      desc: '',
      args: [],
    );
  }

  /// `Use Moodle WebAPI`
  String get moodleSetting {
    return Intl.message(
      'Use Moodle WebAPI',
      name: 'moodleSetting',
      desc: '',
      args: [],
    );
  }

  /// `Information System`
  String get informationSystem {
    return Intl.message(
      'Information System',
      name: 'informationSystem',
      desc: '',
      args: [],
    );
  }

  /// `Score query`
  String get scoreSearch {
    return Intl.message(
      'Score query',
      name: 'scoreSearch',
      desc: '',
      args: [],
    );
  }

  /// `Download file`
  String get downloadFile {
    return Intl.message(
      'Download file',
      name: 'downloadFile',
      desc: '',
      args: [],
    );
  }

  /// `Downloads`
  String get fileViewer {
    return Intl.message(
      'Downloads',
      name: 'fileViewer',
      desc: '',
      args: [],
    );
  }

  /// `Other`
  String get titleOther {
    return Intl.message(
      'Other',
      name: 'titleOther',
      desc: '',
      args: [],
    );
  }

  /// `Please Login`
  String get pleaseLogin {
    return Intl.message(
      'Please Login',
      name: 'pleaseLogin',
      desc: '',
      args: [],
    );
  }

  /// `No function`
  String get noFunction {
    return Intl.message(
      'No function',
      name: 'noFunction',
      desc: '',
      args: [],
    );
  }

  /// `Change the password`
  String get changePassword {
    return Intl.message(
      'Change the password',
      name: 'changePassword',
      desc: '',
      args: [],
    );
  }

  /// `Sign out`
  String get logout {
    return Intl.message(
      'Sign out',
      name: 'logout',
      desc: '',
      args: [],
    );
  }

  /// `Feedback`
  String get feedback {
    return Intl.message(
      'Feedback',
      name: 'feedback',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get about {
    return Intl.message(
      'About',
      name: 'about',
      desc: '',
      args: [],
    );
  }

  /// `Press again to close`
  String get closeOnce {
    return Intl.message(
      'Press again to close',
      name: 'closeOnce',
      desc: '',
      args: [],
    );
  }

  /// `Developer Mode`
  String get developerMode {
    return Intl.message(
      'Developer Mode',
      name: 'developerMode',
      desc: '',
      args: [],
    );
  }

  /// `Permission denied`
  String get noPermission {
    return Intl.message(
      'Permission denied',
      name: 'noPermission',
      desc: '',
      args: [],
    );
  }

  /// `Find new version`
  String get findNewVersion {
    return Intl.message(
      'Find new version',
      name: 'findNewVersion',
      desc: '',
      args: [],
    );
  }

  /// `Check version`
  String get checkVersion {
    return Intl.message(
      'Check version',
      name: 'checkVersion',
      desc: '',
      args: [],
    );
  }

  /// `Checking version...`
  String get checkingVersion {
    return Intl.message(
      'Checking version...',
      name: 'checkingVersion',
      desc: '',
      args: [],
    );
  }

  /// `Contribution`
  String get Contribution {
    return Intl.message(
      'Contribution',
      name: 'Contribution',
      desc: '',
      args: [],
    );
  }

  /// `Version info`
  String get versionInfo {
    return Intl.message(
      'Version info',
      name: 'versionInfo',
      desc: '',
      args: [],
    );
  }

  /// `Already the latest version`
  String get isNewVersion {
    return Intl.message(
      'Already the latest version',
      name: 'isNewVersion',
      desc: '',
      args: [],
    );
  }

  /// `Auto App Check`
  String get autoAppCheck {
    return Intl.message(
      'Auto App Check',
      name: 'autoAppCheck',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to log out? \nAll data will be cleared`
  String get logoutWarning {
    return Intl.message(
      'Are you sure you want to log out? \nAll data will be cleared',
      name: 'logoutWarning',
      desc: '',
      args: [],
    );
  }

  /// `Privacy policy`
  String get PrivacyPolicy {
    return Intl.message(
      'Privacy policy',
      name: 'PrivacyPolicy',
      desc: '',
      args: [],
    );
  }

  /// `Project link`
  String get projectLink {
    return Intl.message(
      'Project link',
      name: 'projectLink',
      desc: '',
      args: [],
    );
  }

  /// `Github`
  String get github {
    return Intl.message(
      'Github',
      name: 'github',
      desc: '',
      args: [],
    );
  }

  /// `Contributors`
  String get Contributors {
    return Intl.message(
      'Contributors',
      name: 'Contributors',
      desc: '',
      args: [],
    );
  }

  /// `Score`
  String get titleScore {
    return Intl.message(
      'Score',
      name: 'titleScore',
      desc: '',
      args: [],
    );
  }

  /// `Search score`
  String get searchScore {
    return Intl.message(
      'Search score',
      name: 'searchScore',
      desc: '',
      args: [],
    );
  }

  /// `Files`
  String get file {
    return Intl.message(
      'Files',
      name: 'file',
      desc: '',
      args: [],
    );
  }

  /// `Announcements`
  String get announcement {
    return Intl.message(
      'Announcements',
      name: 'announcement',
      desc: '',
      args: [],
    );
  }

  /// `Score`
  String get score {
    return Intl.message(
      'Score',
      name: 'score',
      desc: '',
      args: [],
    );
  }

  /// `text selectable`
  String get selectAble {
    return Intl.message(
      'text selectable',
      name: 'selectAble',
      desc: '',
      args: [],
    );
  }

  /// `rank name`
  String get rankItem {
    return Intl.message(
      'rank name',
      name: 'rankItem',
      desc: '',
      args: [],
    );
  }

  /// `weight`
  String get weight {
    return Intl.message(
      'weight',
      name: 'weight',
      desc: '',
      args: [],
    );
  }

  /// `fullRange`
  String get fullRange {
    return Intl.message(
      'fullRange',
      name: 'fullRange',
      desc: '',
      args: [],
    );
  }

  /// `percentage`
  String get percentage {
    return Intl.message(
      'percentage',
      name: 'percentage',
      desc: '',
      args: [],
    );
  }

  /// `contribute`
  String get contribute {
    return Intl.message(
      'contribute',
      name: 'contribute',
      desc: '',
      args: [],
    );
  }

  /// `Score`
  String get resultsOfVariousSubjects {
    return Intl.message(
      'Score',
      name: 'resultsOfVariousSubjects',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
