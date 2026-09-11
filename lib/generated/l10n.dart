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
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
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
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `NTUST TAT`
  String get loginTitle {
    return Intl.message('NTUST TAT', name: 'loginTitle', desc: '', args: []);
  }

  /// `A campus app designed for students of National Taiwan University of Science and Technology. Moodle, semester timetable, grades, enrollment certificates and more, all in one app.`
  String get loginDescription {
    return Intl.message(
      'A campus app designed for students of National Taiwan University of Science and Technology. Moodle, semester timetable, grades, enrollment certificates and more, all in one app.',
      name: 'loginDescription',
      desc: '',
      args: [],
    );
  }

  /// `Wait`
  String get wait {
    return Intl.message('Wait', name: 'wait', desc: '', args: []);
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Error`
  String get error {
    return Intl.message('Error', name: 'error', desc: '', args: []);
  }

  /// `Success`
  String get success {
    return Intl.message('Success', name: 'success', desc: '', args: []);
  }

  /// `Warning`
  String get warning {
    return Intl.message('Warning', name: 'warning', desc: '', args: []);
  }

  /// `Sure`
  String get sure {
    return Intl.message('Sure', name: 'sure', desc: '', args: []);
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Update`
  String get update {
    return Intl.message('Update', name: 'update', desc: '', args: []);
  }

  /// `Settings`
  String get setting {
    return Intl.message('Settings', name: 'setting', desc: '', args: []);
  }

  /// `Restart`
  String get restart {
    return Intl.message('Restart', name: 'restart', desc: '', args: []);
  }

  /// `Loading...`
  String get loading {
    return Intl.message('Loading...', name: 'loading', desc: '', args: []);
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

  /// `Could not fetch the latest data; showing the last successful result.`
  String get loadingCache {
    return Intl.message(
      'Could not fetch the latest data; showing the last successful result.',
      name: 'loadingCache',
      desc: '',
      args: [],
    );
  }

  /// `Login`
  String get login {
    return Intl.message('Login', name: 'login', desc: '', args: []);
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
    return Intl.message('Password', name: 'password', desc: '', args: []);
  }

  /// `Account`
  String get account {
    return Intl.message('Account', name: 'account', desc: '', args: []);
  }

  /// `Calendar`
  String get calendar {
    return Intl.message('Calendar', name: 'calendar', desc: '', args: []);
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

  /// `Download error`
  String get downloadError {
    return Intl.message(
      'Download error',
      name: 'downloadError',
      desc: '',
      args: [],
    );
  }

  /// `Download...`
  String get downloading {
    return Intl.message('Download...', name: 'downloading', desc: '', args: []);
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

  /// `login NTUST`
  String get loginNTUST {
    return Intl.message('login NTUST', name: 'loginNTUST', desc: '', args: []);
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

  /// `Get semester list...`
  String get getCourseSemester {
    return Intl.message(
      'Get semester list...',
      name: 'getCourseSemester',
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
    return Intl.message('Credit', name: 'credit', desc: '', args: []);
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

  /// `Get Moodle members error`
  String get getMoodleMembersError {
    return Intl.message(
      'Get Moodle members error',
      name: 'getMoodleMembersError',
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

  /// `get course announcement error`
  String get getMoodleCourseAnnouncementError {
    return Intl.message(
      'get course announcement error',
      name: 'getMoodleCourseAnnouncementError',
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

  /// `get score error`
  String get getScoreError {
    return Intl.message(
      'get score error',
      name: 'getScoreError',
      desc: '',
      args: [],
    );
  }

  /// `MON`
  String get Monday {
    return Intl.message('MON', name: 'Monday', desc: '', args: []);
  }

  /// `TUE`
  String get Tuesday {
    return Intl.message('TUE', name: 'Tuesday', desc: '', args: []);
  }

  /// `WED`
  String get Wednesday {
    return Intl.message('WED', name: 'Wednesday', desc: '', args: []);
  }

  /// `THU`
  String get Thursday {
    return Intl.message('THU', name: 'Thursday', desc: '', args: []);
  }

  /// `FRI`
  String get Friday {
    return Intl.message('FRI', name: 'Friday', desc: '', args: []);
  }

  /// `SAT`
  String get Saturday {
    return Intl.message('SAT', name: 'Saturday', desc: '', args: []);
  }

  /// `SUN`
  String get Sunday {
    return Intl.message('SUN', name: 'Sunday', desc: '', args: []);
  }

  /// `Course`
  String get titleCourse {
    return Intl.message('Course', name: 'titleCourse', desc: '', args: []);
  }

  /// `Refresh`
  String get refresh {
    return Intl.message('Refresh', name: 'refresh', desc: '', args: []);
  }

  /// `Course number`
  String get courseId {
    return Intl.message('Course number', name: 'courseId', desc: '', args: []);
  }

  /// `Time`
  String get time {
    return Intl.message('Time', name: 'time', desc: '', args: []);
  }

  /// `Instructor`
  String get instructor {
    return Intl.message('Instructor', name: 'instructor', desc: '', args: []);
  }

  /// `Course Title`
  String get courseName {
    return Intl.message('Course Title', name: 'courseName', desc: '', args: []);
  }

  /// `Start class`
  String get startClass {
    return Intl.message('Start class', name: 'startClass', desc: '', args: []);
  }

  /// `Classroom`
  String get classroom {
    return Intl.message('Classroom', name: 'classroom', desc: '', args: []);
  }

  /// `Details`
  String get details {
    return Intl.message('Details', name: 'details', desc: '', args: []);
  }

  /// ` not support`
  String get noSupport {
    return Intl.message(' not support', name: 'noSupport', desc: '', args: []);
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

  /// `Add a course by its code or name`
  String get importCourseHint {
    return Intl.message(
      'Add a course by its code or name',
      name: 'importCourseHint',
      desc: '',
      args: [],
    );
  }

  /// `Timetable options`
  String get courseTableOptions {
    return Intl.message(
      'Timetable options',
      name: 'courseTableOptions',
      desc: '',
      args: [],
    );
  }

  /// `Remarks`
  String get note {
    return Intl.message('Remarks', name: 'note', desc: '', args: []);
  }

  /// `Search`
  String get search {
    return Intl.message('Search', name: 'search', desc: '', args: []);
  }

  /// `Moodle`
  String get courseData {
    return Intl.message('Moodle', name: 'courseData', desc: '', args: []);
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
    return Intl.message('Course', name: 'course', desc: '', args: []);
  }

  /// `Semester`
  String get semester {
    return Intl.message('Semester', name: 'semester', desc: '', args: []);
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
    return Intl.message('course URL', name: 'courseURL', desc: '', args: []);
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
    return Intl.message('Course note', name: 'courseNote', desc: '', args: []);
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

  /// `Member`
  String get member {
    return Intl.message('Member', name: 'member', desc: '', args: []);
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

  /// `Delete`
  String get delete {
    return Intl.message('Delete', name: 'delete', desc: '', args: []);
  }

  /// `download`
  String get download {
    return Intl.message('download', name: 'download', desc: '', args: []);
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

  /// `Download path`
  String get downloadPath {
    return Intl.message(
      'Download path',
      name: 'downloadPath',
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

  /// `Information system`
  String get informationSystem {
    return Intl.message(
      'Information system',
      name: 'informationSystem',
      desc: '',
      args: [],
    );
  }

  /// `Other`
  String get titleOther {
    return Intl.message('Other', name: 'titleOther', desc: '', args: []);
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
    return Intl.message('No function', name: 'noFunction', desc: '', args: []);
  }

  /// `Sign out`
  String get logout {
    return Intl.message('Sign out', name: 'logout', desc: '', args: []);
  }

  /// `Feedback`
  String get feedback {
    return Intl.message('Feedback', name: 'feedback', desc: '', args: []);
  }

  /// `About`
  String get about {
    return Intl.message('About', name: 'about', desc: '', args: []);
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

  /// `Update available`
  String get updateTitle {
    return Intl.message(
      'Update available',
      name: 'updateTitle',
      desc: '',
      args: [],
    );
  }

  /// `A new version of TAT is out. You have %s; %s is available.`
  String get updateBody {
    return Intl.message(
      'A new version of TAT is out. You have %s; %s is available.',
      name: 'updateBody',
      desc: '',
      args: [],
    );
  }

  /// `Would you like to update now?`
  String get updatePrompt {
    return Intl.message(
      'Would you like to update now?',
      name: 'updatePrompt',
      desc: '',
      args: [],
    );
  }

  /// `What's new`
  String get updateReleaseNotes {
    return Intl.message(
      'What\'s new',
      name: 'updateReleaseNotes',
      desc: '',
      args: [],
    );
  }

  /// `Later`
  String get updateLater {
    return Intl.message('Later', name: 'updateLater', desc: '', args: []);
  }

  /// `Ignore`
  String get updateIgnore {
    return Intl.message('Ignore', name: 'updateIgnore', desc: '', args: []);
  }

  /// `Your password never leaves this phone`
  String get privacySummaryLocalTitle {
    return Intl.message(
      'Your password never leaves this phone',
      name: 'privacySummaryLocalTitle',
      desc: '',
      args: [],
    );
  }

  /// `Sign-in details live in the device's secure storage. They are never sent to a TAT server — there isn't one. The app talks to NTUST and Moodle directly.`
  String get privacySummaryLocalBody {
    return Intl.message(
      'Sign-in details live in the device\'s secure storage. They are never sent to a TAT server — there isn\'t one. The app talks to NTUST and Moodle directly.',
      name: 'privacySummaryLocalBody',
      desc: '',
      args: [],
    );
  }

  /// `Your grades and timetable don't pass through us`
  String get privacySummaryDataTitle {
    return Intl.message(
      'Your grades and timetable don\'t pass through us',
      name: 'privacySummaryDataTitle',
      desc: '',
      args: [],
    );
  }

  /// `Every piece of course data is fetched by your own phone from the school's systems. We never see it and never store it.`
  String get privacySummaryDataBody {
    return Intl.message(
      'Every piece of course data is fetched by your own phone from the school\'s systems. We never see it and never store it.',
      name: 'privacySummaryDataBody',
      desc: '',
      args: [],
    );
  }

  /// `Anonymous usage stats`
  String get privacySummaryAnalyticsTitle {
    return Intl.message(
      'Anonymous usage stats',
      name: 'privacySummaryAnalyticsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Which screens get opened is reported to Firebase Analytics so we know what to fix. No student ID, no grades.`
  String get privacySummaryAnalyticsBody {
    return Intl.message(
      'Which screens get opened is reported to Firebase Analytics so we know what to fix. No student ID, no grades.',
      name: 'privacySummaryAnalyticsBody',
      desc: '',
      args: [],
    );
  }

  /// `Crash reports`
  String get privacySummaryCrashTitle {
    return Intl.message(
      'Crash reports',
      name: 'privacySummaryCrashTitle',
      desc: '',
      args: [],
    );
  }

  /// `When the app crashes, the stack trace goes to Firebase Crashlytics.`
  String get privacySummaryCrashBody {
    return Intl.message(
      'When the app crashes, the stack trace goes to Firebase Crashlytics.',
      name: 'privacySummaryCrashBody',
      desc: '',
      args: [],
    );
  }

  /// `Policy text`
  String get privacyBodyTitle {
    return Intl.message(
      'Policy text',
      name: 'privacyBodyTitle',
      desc: '',
      args: [],
    );
  }

  /// `%s sections`
  String get privacySectionCount {
    return Intl.message(
      '%s sections',
      name: 'privacySectionCount',
      desc: '',
      args: [],
    );
  }

  /// `See this policy's history on GitHub`
  String get privacyHistoryLink {
    return Intl.message(
      'See this policy\'s history on GitHub',
      name: 'privacyHistoryLink',
      desc: '',
      args: [],
    );
  }

  /// `Agree and continue`
  String get privacyAgreeContinue {
    return Intl.message(
      'Agree and continue',
      name: 'privacyAgreeContinue',
      desc: '',
      args: [],
    );
  }

  /// `TAT can't be used without agreeing`
  String get privacyAgreeRequired {
    return Intl.message(
      'TAT can\'t be used without agreeing',
      name: 'privacyAgreeRequired',
      desc: '',
      args: [],
    );
  }

  /// `Privacy Policy`
  String get PrivacyPolicy {
    return Intl.message(
      'Privacy Policy',
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
    return Intl.message('Github', name: 'github', desc: '', args: []);
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
    return Intl.message('Score', name: 'titleScore', desc: '', args: []);
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
    return Intl.message('Files', name: 'file', desc: '', args: []);
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
    return Intl.message('Score', name: 'score', desc: '', args: []);
  }

  /// `weight`
  String get weight {
    return Intl.message('weight', name: 'weight', desc: '', args: []);
  }

  /// `fullRange`
  String get fullRange {
    return Intl.message('fullRange', name: 'fullRange', desc: '', args: []);
  }

  /// `Can't join the class`
  String get addCustomCourseError {
    return Intl.message(
      'Can\'t join the class',
      name: 'addCustomCourseError',
      desc: '',
      args: [],
    );
  }

  /// `Remove`
  String get remove {
    return Intl.message('Remove', name: 'remove', desc: '', args: []);
  }

  /// `Login to use this feature`
  String get pleaseLoginWarning {
    return Intl.message(
      'Login to use this feature',
      name: 'pleaseLoginWarning',
      desc: '',
      args: [],
    );
  }

  /// `Opps something Error`
  String get somethingError {
    return Intl.message(
      'Opps something Error',
      name: 'somethingError',
      desc: '',
      args: [],
    );
  }

  /// `No relevant courses found`
  String get courseSearchNotFound {
    return Intl.message(
      'No relevant courses found',
      name: 'courseSearchNotFound',
      desc: '',
      args: [],
    );
  }

  /// `No Announcement`
  String get announcementEmpty {
    return Intl.message(
      'No Announcement',
      name: 'announcementEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Copied`
  String get copy {
    return Intl.message('Copied', name: 'copy', desc: '', args: []);
  }

  /// `Curriculum`
  String get curriculum {
    return Intl.message('Curriculum', name: 'curriculum', desc: '', args: []);
  }

  /// `Person Information`
  String get person_info {
    return Intl.message(
      'Person Information',
      name: 'person_info',
      desc: '',
      args: [],
    );
  }

  /// `Campus Life`
  String get campus_life {
    return Intl.message('Campus Life', name: 'campus_life', desc: '', args: []);
  }

  /// `Financial Support`
  String get financial_support {
    return Intl.message(
      'Financial Support',
      name: 'financial_support',
      desc: '',
      args: [],
    );
  }

  /// `Activities`
  String get activities {
    return Intl.message('Activities', name: 'activities', desc: '', args: []);
  }

  /// `Resources`
  String get resources {
    return Intl.message('Resources', name: 'resources', desc: '', args: []);
  }

  /// `Moodle setting`
  String get moodle_setting {
    return Intl.message(
      'Moodle setting',
      name: 'moodle_setting',
      desc: '',
      args: [],
    );
  }

  /// `Sync NTUST Moodle website settings`
  String get moodle_setting_description {
    return Intl.message(
      'Sync NTUST Moodle website settings',
      name: 'moodle_setting_description',
      desc: '',
      args: [],
    );
  }

  /// `Dimension`
  String get general_dimension {
    return Intl.message(
      'Dimension',
      name: 'general_dimension',
      desc: '',
      args: [],
    );
  }

  /// `Theme setting`
  String get theme_setting {
    return Intl.message(
      'Theme setting',
      name: 'theme_setting',
      desc: '',
      args: [],
    );
  }

  /// `Change TAT Theme Style`
  String get theme_setting_description {
    return Intl.message(
      'Change TAT Theme Style',
      name: 'theme_setting_description',
      desc: '',
      args: [],
    );
  }

  /// `System`
  String get theme_system {
    return Intl.message('System', name: 'theme_system', desc: '', args: []);
  }

  /// `Light`
  String get theme_light {
    return Intl.message('Light', name: 'theme_light', desc: '', args: []);
  }

  /// `Dark`
  String get theme_dark {
    return Intl.message('Dark', name: 'theme_dark', desc: '', args: []);
  }

  /// `Your login information will be stored only on this device and will not be uploaded to any server.`
  String get login_hint {
    return Intl.message(
      'Your login information will be stored only on this device and will not be uploaded to any server.',
      name: 'login_hint',
      desc: '',
      args: [],
    );
  }

  /// `Show password`
  String get showPassword {
    return Intl.message(
      'Show password',
      name: 'showPassword',
      desc: '',
      args: [],
    );
  }

  /// `Hide password`
  String get hidePassword {
    return Intl.message(
      'Hide password',
      name: 'hidePassword',
      desc: '',
      args: [],
    );
  }

  /// `TAT is signing you in — no need to type your password`
  String get browserAutoLoginNotice {
    return Intl.message(
      'TAT is signing you in — no need to type your password',
      name: 'browserAutoLoginNotice',
      desc: '',
      args: [],
    );
  }

  /// `The school wants a captcha this time; you have to enter it yourself`
  String get browserCaptchaNotice {
    return Intl.message(
      'The school wants a captcha this time; you have to enter it yourself',
      name: 'browserCaptchaNotice',
      desc: '',
      args: [],
    );
  }

  /// `The one-tap sign-in link expired, so the original page was opened instead`
  String get browserAutologinExpired {
    return Intl.message(
      'The one-tap sign-in link expired, so the original page was opened instead',
      name: 'browserAutologinExpired',
      desc: '',
      args: [],
    );
  }

  /// `Sign in again`
  String get browserRelogin {
    return Intl.message(
      'Sign in again',
      name: 'browserRelogin',
      desc: '',
      args: [],
    );
  }

  /// `This is an external site, not a school system`
  String get browserExternalSite {
    return Intl.message(
      'This is an external site, not a school system',
      name: 'browserExternalSite',
      desc: '',
      args: [],
    );
  }

  /// `%s saved to Downloads`
  String get browserDownloadSaved {
    return Intl.message(
      '%s saved to Downloads',
      name: 'browserDownloadSaved',
      desc: '',
      args: [],
    );
  }

  /// `Copy address`
  String get browserCopyUrl {
    return Intl.message(
      'Copy address',
      name: 'browserCopyUrl',
      desc: '',
      args: [],
    );
  }

  /// `Address copied`
  String get browserUrlCopied {
    return Intl.message(
      'Address copied',
      name: 'browserUrlCopied',
      desc: '',
      args: [],
    );
  }

  /// `Share`
  String get browserShare {
    return Intl.message('Share', name: 'browserShare', desc: '', args: []);
  }

  /// `An external browser does not have your sign-in`
  String get browserOpenExternalNote {
    return Intl.message(
      'An external browser does not have your sign-in',
      name: 'browserOpenExternalNote',
      desc: '',
      args: [],
    );
  }

  /// `Open in browser`
  String get openInBrowser {
    return Intl.message(
      'Open in browser',
      name: 'openInBrowser',
      desc: '',
      args: [],
    );
  }

  /// `Edit`
  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '', args: []);
  }

  /// `Course total`
  String get courseTotal {
    return Intl.message(
      'Course total',
      name: 'courseTotal',
      desc: '',
      args: [],
    );
  }

  /// `Category total`
  String get categoryTotal {
    return Intl.message(
      'Category total',
      name: 'categoryTotal',
      desc: '',
      args: [],
    );
  }

  /// `To-do`
  String get upcomingEvents {
    return Intl.message('To-do', name: 'upcomingEvents', desc: '', args: []);
  }

  /// `No upcoming to-do items`
  String get upcomingEventsEmpty {
    return Intl.message(
      'No upcoming to-do items',
      name: 'upcomingEventsEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Overdue`
  String get deadlineOverdue {
    return Intl.message('Overdue', name: 'deadlineOverdue', desc: '', args: []);
  }

  /// `Today`
  String get deadlineToday {
    return Intl.message('Today', name: 'deadlineToday', desc: '', args: []);
  }

  /// `This week`
  String get deadlineThisWeek {
    return Intl.message(
      'This week',
      name: 'deadlineThisWeek',
      desc: '',
      args: [],
    );
  }

  /// `Later`
  String get deadlineLater {
    return Intl.message('Later', name: 'deadlineLater', desc: '', args: []);
  }

  /// `Late %s`
  String get deadlineRestOfMonth {
    return Intl.message(
      'Late %s',
      name: 'deadlineRestOfMonth',
      desc: '',
      args: [],
    );
  }

  /// `%s days left`
  String get deadlineRemainingDays {
    return Intl.message(
      '%s days left',
      name: 'deadlineRemainingDays',
      desc: '',
      args: [],
    );
  }

  /// `%s hours left`
  String get deadlineRemainingHours {
    return Intl.message(
      '%s hours left',
      name: 'deadlineRemainingHours',
      desc: '',
      args: [],
    );
  }

  /// `School calendar`
  String get calendarSourceSchool {
    return Intl.message(
      'School calendar',
      name: 'calendarSourceSchool',
      desc: '',
      args: [],
    );
  }

  /// `Assignment due`
  String get calendarSourceDeadline {
    return Intl.message(
      'Assignment due',
      name: 'calendarSourceDeadline',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load Moodle to-do items`
  String get getUpcomingEventsError {
    return Intl.message(
      'Failed to load Moodle to-do items',
      name: 'getUpcomingEventsError',
      desc: '',
      args: [],
    );
  }

  /// `Not signed in to Moodle`
  String get moodleNotSignedIn {
    return Intl.message(
      'Not signed in to Moodle',
      name: 'moodleNotSignedIn',
      desc: '',
      args: [],
    );
  }

  /// `Assignments`
  String get assignment {
    return Intl.message('Assignments', name: 'assignment', desc: '', args: []);
  }

  /// `Assignment`
  String get assignmentDetail {
    return Intl.message(
      'Assignment',
      name: 'assignmentDetail',
      desc: '',
      args: [],
    );
  }

  /// `No assignments in this course`
  String get assignmentEmpty {
    return Intl.message(
      'No assignments in this course',
      name: 'assignmentEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load assignments`
  String get getMoodleAssignmentsError {
    return Intl.message(
      'Failed to load assignments',
      name: 'getMoodleAssignmentsError',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load submission status`
  String get getMoodleAssignmentStatusError {
    return Intl.message(
      'Failed to load submission status',
      name: 'getMoodleAssignmentStatusError',
      desc: '',
      args: [],
    );
  }

  /// `This assignment was not found on Moodle`
  String get assignmentNotFound {
    return Intl.message(
      'This assignment was not found on Moodle',
      name: 'assignmentNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Not submitted`
  String get assignStatusNotSubmitted {
    return Intl.message(
      'Not submitted',
      name: 'assignStatusNotSubmitted',
      desc: '',
      args: [],
    );
  }

  /// `Draft`
  String get assignStatusDraft {
    return Intl.message('Draft', name: 'assignStatusDraft', desc: '', args: []);
  }

  /// `Graded`
  String get assignStatusGraded {
    return Intl.message(
      'Graded',
      name: 'assignStatusGraded',
      desc: '',
      args: [],
    );
  }

  /// `Overdue`
  String get assignStatusOverdue {
    return Intl.message(
      'Overdue',
      name: 'assignStatusOverdue',
      desc: '',
      args: [],
    );
  }

  /// `No submission required`
  String get assignStatusNoSubmissionRequired {
    return Intl.message(
      'No submission required',
      name: 'assignStatusNoSubmissionRequired',
      desc: '',
      args: [],
    );
  }

  /// `Not graded yet`
  String get assignNotGraded {
    return Intl.message(
      'Not graded yet',
      name: 'assignNotGraded',
      desc: '',
      args: [],
    );
  }

  /// `Due date`
  String get assignDueDate {
    return Intl.message('Due date', name: 'assignDueDate', desc: '', args: []);
  }

  /// `No due date`
  String get assignNoDueDate {
    return Intl.message(
      'No due date',
      name: 'assignNoDueDate',
      desc: '',
      args: [],
    );
  }

  /// `Opens`
  String get assignAllowSubmissionsFrom {
    return Intl.message(
      'Opens',
      name: 'assignAllowSubmissionsFrom',
      desc: '',
      args: [],
    );
  }

  /// `Cut-off date`
  String get assignCutoffDate {
    return Intl.message(
      'Cut-off date',
      name: 'assignCutoffDate',
      desc: '',
      args: [],
    );
  }

  /// `Extension due date`
  String get assignExtensionDueDate {
    return Intl.message(
      'Extension due date',
      name: 'assignExtensionDueDate',
      desc: '',
      args: [],
    );
  }

  /// `Due in %s day(s)`
  String get assignDueInDays {
    return Intl.message(
      'Due in %s day(s)',
      name: 'assignDueInDays',
      desc: '',
      args: [],
    );
  }

  /// `Due in %s hour(s)`
  String get assignDueInHours {
    return Intl.message(
      'Due in %s hour(s)',
      name: 'assignDueInHours',
      desc: '',
      args: [],
    );
  }

  /// `Due within an hour`
  String get assignDueSoon {
    return Intl.message(
      'Due within an hour',
      name: 'assignDueSoon',
      desc: '',
      args: [],
    );
  }

  /// `%s day(s) overdue`
  String get assignOverdueDays {
    return Intl.message(
      '%s day(s) overdue',
      name: 'assignOverdueDays',
      desc: '',
      args: [],
    );
  }

  /// `%s hour(s) overdue`
  String get assignOverdueHours {
    return Intl.message(
      '%s hour(s) overdue',
      name: 'assignOverdueHours',
      desc: '',
      args: [],
    );
  }

  /// `Just past due`
  String get assignOverdueJustNow {
    return Intl.message(
      'Just past due',
      name: 'assignOverdueJustNow',
      desc: '',
      args: [],
    );
  }

  /// `Submission status`
  String get assignSubmissionStatus {
    return Intl.message(
      'Submission status',
      name: 'assignSubmissionStatus',
      desc: '',
      args: [],
    );
  }

  /// `Grading status`
  String get assignGradingStatus {
    return Intl.message(
      'Grading status',
      name: 'assignGradingStatus',
      desc: '',
      args: [],
    );
  }

  /// `Submitted on`
  String get assignSubmittedAt {
    return Intl.message(
      'Submitted on',
      name: 'assignSubmittedAt',
      desc: '',
      args: [],
    );
  }

  /// `Last modified`
  String get assignLastModified {
    return Intl.message(
      'Last modified',
      name: 'assignLastModified',
      desc: '',
      args: [],
    );
  }

  /// `Submitted files`
  String get assignSubmittedFiles {
    return Intl.message(
      'Submitted files',
      name: 'assignSubmittedFiles',
      desc: '',
      args: [],
    );
  }

  /// `Online text`
  String get assignOnlineText {
    return Intl.message(
      'Online text',
      name: 'assignOnlineText',
      desc: '',
      args: [],
    );
  }

  /// `Description`
  String get assignIntro {
    return Intl.message('Description', name: 'assignIntro', desc: '', args: []);
  }

  /// `The description is hidden until submissions open`
  String get assignIntroHidden {
    return Intl.message(
      'The description is hidden until submissions open',
      name: 'assignIntroHidden',
      desc: '',
      args: [],
    );
  }

  /// `Attachments`
  String get assignAttachments {
    return Intl.message(
      'Attachments',
      name: 'assignAttachments',
      desc: '',
      args: [],
    );
  }

  /// `Grade`
  String get assignGrade {
    return Intl.message('Grade', name: 'assignGrade', desc: '', args: []);
  }

  /// `Graded on`
  String get assignGradedAt {
    return Intl.message(
      'Graded on',
      name: 'assignGradedAt',
      desc: '',
      args: [],
    );
  }

  /// `Feedback`
  String get assignFeedback {
    return Intl.message('Feedback', name: 'assignFeedback', desc: '', args: []);
  }

  /// `Feedback files`
  String get assignFeedbackFiles {
    return Intl.message(
      'Feedback files',
      name: 'assignFeedbackFiles',
      desc: '',
      args: [],
    );
  }

  /// `Open in web`
  String get assignOpenInWeb {
    return Intl.message(
      'Open in web',
      name: 'assignOpenInWeb',
      desc: '',
      args: [],
    );
  }

  /// `Grade & feedback`
  String get assignSectionGradeFeedback {
    return Intl.message(
      'Grade & feedback',
      name: 'assignSectionGradeFeedback',
      desc: '',
      args: [],
    );
  }

  /// `Add submission`
  String get assignAddSubmission {
    return Intl.message(
      'Add submission',
      name: 'assignAddSubmission',
      desc: '',
      args: [],
    );
  }

  /// `Edit submission`
  String get assignEditSubmission {
    return Intl.message(
      'Edit submission',
      name: 'assignEditSubmission',
      desc: '',
      args: [],
    );
  }

  /// `Submit`
  String get assignSubmit {
    return Intl.message('Submit', name: 'assignSubmit', desc: '', args: []);
  }

  /// `Save draft`
  String get assignSaveDraft {
    return Intl.message(
      'Save draft',
      name: 'assignSaveDraft',
      desc: '',
      args: [],
    );
  }

  /// `Submit for grading`
  String get assignSubmitForGrading {
    return Intl.message(
      'Submit for grading',
      name: 'assignSubmitForGrading',
      desc: '',
      args: [],
    );
  }

  /// `Once submitted for grading you can no longer edit it. Submit now?`
  String get assignSubmitForGradingConfirm {
    return Intl.message(
      'Once submitted for grading you can no longer edit it. Submit now?',
      name: 'assignSubmitForGradingConfirm',
      desc: '',
      args: [],
    );
  }

  /// `This assignment has no draft stage: saving submits it. Submit now?`
  String get assignSubmitDirectConfirm {
    return Intl.message(
      'This assignment has no draft stage: saving submits it. Submit now?',
      name: 'assignSubmitDirectConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Re-submitting replaces the files you have already submitted with this list`
  String get assignSubmitAgainWarning {
    return Intl.message(
      'Re-submitting replaces the files you have already submitted with this list',
      name: 'assignSubmitAgainWarning',
      desc: '',
      args: [],
    );
  }

  /// `Saving deletes %s file(s) you already submitted from Moodle, and that cannot be undone`
  String get assignRemoveFilesWarning {
    return Intl.message(
      'Saving deletes %s file(s) you already submitted from Moodle, and that cannot be undone',
      name: 'assignRemoveFilesWarning',
      desc: '',
      args: [],
    );
  }

  /// `Draft saved`
  String get assignDraftSaved {
    return Intl.message(
      'Draft saved',
      name: 'assignDraftSaved',
      desc: '',
      args: [],
    );
  }

  /// `Assignment submitted`
  String get assignSubmittedToast {
    return Intl.message(
      'Assignment submitted',
      name: 'assignSubmittedToast',
      desc: '',
      args: [],
    );
  }

  /// `Files to submit`
  String get assignAttachmentSection {
    return Intl.message(
      'Files to submit',
      name: 'assignAttachmentSection',
      desc: '',
      args: [],
    );
  }

  /// `Add files`
  String get assignAddFiles {
    return Intl.message(
      'Add files',
      name: 'assignAddFiles',
      desc: '',
      args: [],
    );
  }

  /// `Remove this file`
  String get assignRemoveFile {
    return Intl.message(
      'Remove this file',
      name: 'assignRemoveFile',
      desc: '',
      args: [],
    );
  }

  /// `Undo removing this file`
  String get assignRestoreFile {
    return Intl.message(
      'Undo removing this file',
      name: 'assignRestoreFile',
      desc: '',
      args: [],
    );
  }

  /// `Removing every submitted file has to be done on the web`
  String get assignFilesEmptiedWebOnly {
    return Intl.message(
      'Removing every submitted file has to be done on the web',
      name: 'assignFilesEmptiedWebOnly',
      desc: '',
      args: [],
    );
  }

  /// `Up to %s files`
  String get assignFileLimit {
    return Intl.message(
      'Up to %s files',
      name: 'assignFileLimit',
      desc: '',
      args: [],
    );
  }

  /// `Up to %s per file`
  String get assignFileSizeLimit {
    return Intl.message(
      'Up to %s per file',
      name: 'assignFileSizeLimit',
      desc: '',
      args: [],
    );
  }

  /// `Allowed file types: %s`
  String get assignFileTypes {
    return Intl.message(
      'Allowed file types: %s',
      name: 'assignFileTypes',
      desc: '',
      args: [],
    );
  }

  /// `This assignment accepts at most %s files`
  String get assignFileCountExceeded {
    return Intl.message(
      'This assignment accepts at most %s files',
      name: 'assignFileCountExceeded',
      desc: '',
      args: [],
    );
  }

  /// `"%s" is larger than the %s limit`
  String get assignFileTooLarge {
    return Intl.message(
      '"%s" is larger than the %s limit',
      name: 'assignFileTooLarge',
      desc: '',
      args: [],
    );
  }

  /// `The file exceeds the Moodle upload size limit`
  String get assignFileTooLargeUnknown {
    return Intl.message(
      'The file exceeds the Moodle upload size limit',
      name: 'assignFileTooLargeUnknown',
      desc: '',
      args: [],
    );
  }

  /// `"%s" is not an allowed file type for this assignment`
  String get assignFileTypeRejected {
    return Intl.message(
      '"%s" is not an allowed file type for this assignment',
      name: 'assignFileTypeRejected',
      desc: '',
      args: [],
    );
  }

  /// `Two files share the same name; Moodle would keep only the first. Rename one first.`
  String get assignFileDuplicateName {
    return Intl.message(
      'Two files share the same name; Moodle would keep only the first. Rename one first.',
      name: 'assignFileDuplicateName',
      desc: '',
      args: [],
    );
  }

  /// `The site's antivirus scan rejected this file`
  String get assignFileVirusFound {
    return Intl.message(
      'The site\'s antivirus scan rejected this file',
      name: 'assignFileVirusFound',
      desc: '',
      args: [],
    );
  }

  /// `What you type here is submitted as plain text`
  String get assignOnlineTextHint {
    return Intl.message(
      'What you type here is submitted as plain text',
      name: 'assignOnlineTextHint',
      desc: '',
      args: [],
    );
  }

  /// `Words: %s of %s`
  String get assignWordCount {
    return Intl.message(
      'Words: %s of %s',
      name: 'assignWordCount',
      desc: '',
      args: [],
    );
  }

  /// `Over the word limit; shorten your text before submitting`
  String get assignWordCountExceeded {
    return Intl.message(
      'Over the word limit; shorten your text before submitting',
      name: 'assignWordCountExceeded',
      desc: '',
      args: [],
    );
  }

  /// `The existing online text is over the word limit, so Moodle will reject the whole save. Trim it on the web.`
  String get assignWordCountExceededReadOnly {
    return Intl.message(
      'The existing online text is over the word limit, so Moodle will reject the whole save. Trim it on the web.',
      name: 'assignWordCountExceededReadOnly',
      desc: '',
      args: [],
    );
  }

  /// `Kept as-is`
  String get assignOnlineTextKeepAsIs {
    return Intl.message(
      'Kept as-is',
      name: 'assignOnlineTextKeepAsIs',
      desc: '',
      args: [],
    );
  }

  /// `This text contains images or formatting, so the app leaves it alone — it is sent back unchanged when you save, so the images and formatting survive. To change the text itself, edit it on the web. You can still add or remove files above.`
  String get assignOnlineTextPreserved {
    return Intl.message(
      'This text contains images or formatting, so the app leaves it alone — it is sent back unchanged when you save, so the images and formatting survive. To change the text itself, edit it on the web. You can still add or remove files above.',
      name: 'assignOnlineTextPreserved',
      desc: '',
      args: [],
    );
  }

  /// `This text contains images or formatting that the app's plain-text box cannot edit. To change the text itself, edit it on the web.`
  String get assignOnlineTextReadOnly {
    return Intl.message(
      'This text contains images or formatting that the app\'s plain-text box cannot edit. To change the text itself, edit it on the web.',
      name: 'assignOnlineTextReadOnly',
      desc: '',
      args: [],
    );
  }

  /// `Edit text on the web`
  String get assignEditOnlineTextInWeb {
    return Intl.message(
      'Edit text on the web',
      name: 'assignEditOnlineTextInWeb',
      desc: '',
      args: [],
    );
  }

  /// `Submission statement`
  String get assignSubmissionStatement {
    return Intl.message(
      'Submission statement',
      name: 'assignSubmissionStatement',
      desc: '',
      args: [],
    );
  }

  /// `I have read and accept the statement above`
  String get assignAcceptStatement {
    return Intl.message(
      'I have read and accept the statement above',
      name: 'assignAcceptStatement',
      desc: '',
      args: [],
    );
  }

  /// `There is nothing to submit`
  String get assignNothingToSubmit {
    return Intl.message(
      'There is nothing to submit',
      name: 'assignNothingToSubmit',
      desc: '',
      args: [],
    );
  }

  /// `Discard your unsaved changes?`
  String get assignDiscardChanges {
    return Intl.message(
      'Discard your unsaved changes?',
      name: 'assignDiscardChanges',
      desc: '',
      args: [],
    );
  }

  /// `Could not submit`
  String get assignSubmitError {
    return Intl.message(
      'Could not submit',
      name: 'assignSubmitError',
      desc: '',
      args: [],
    );
  }

  /// `Moodle did not accept this submission; the deadline may have passed or submissions are closed`
  String get assignSubmitRejected {
    return Intl.message(
      'Moodle did not accept this submission; the deadline may have passed or submissions are closed',
      name: 'assignSubmitRejected',
      desc: '',
      args: [],
    );
  }

  /// `Moodle did not accept the submit for grading; refresh and try again`
  String get assignSubmitForGradingRejected {
    return Intl.message(
      'Moodle did not accept the submit for grading; refresh and try again',
      name: 'assignSubmitForGradingRejected',
      desc: '',
      args: [],
    );
  }

  /// `Your work was saved but the submit for grading failed; refresh and submit again`
  String get assignSavedNotSubmitted {
    return Intl.message(
      'Your work was saved but the submit for grading failed; refresh and submit again',
      name: 'assignSavedNotSubmitted',
      desc: '',
      args: [],
    );
  }

  /// `This submission has been locked by your teacher`
  String get assignSubmitLocked {
    return Intl.message(
      'This submission has been locked by your teacher',
      name: 'assignSubmitLocked',
      desc: '',
      args: [],
    );
  }

  /// `Your Moodle account cannot submit this assignment`
  String get assignSubmitNoPermission {
    return Intl.message(
      'Your Moodle account cannot submit this assignment',
      name: 'assignSubmitNoPermission',
      desc: '',
      args: [],
    );
  }

  /// `File upload is disabled on the school's Moodle`
  String get assignUploadDisabled {
    return Intl.message(
      'File upload is disabled on the school\'s Moodle',
      name: 'assignUploadDisabled',
      desc: '',
      args: [],
    );
  }

  /// `Submitting needs up-to-date assignment data; refresh first`
  String get assignSubmitNeedsFresh {
    return Intl.message(
      'Submitting needs up-to-date assignment data; refresh first',
      name: 'assignSubmitNeedsFresh',
      desc: '',
      args: [],
    );
  }

  /// `No permission to read files; enable it in system settings and try again`
  String get assignFilePickerDenied {
    return Intl.message(
      'No permission to read files; enable it in system settings and try again',
      name: 'assignFilePickerDenied',
      desc: '',
      args: [],
    );
  }

  /// `The file picker is unavailable right now; try again later`
  String get assignFilePickerUnavailable {
    return Intl.message(
      'The file picker is unavailable right now; try again later',
      name: 'assignFilePickerUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Uploading %s`
  String get assignUploadingFile {
    return Intl.message(
      'Uploading %s',
      name: 'assignUploadingFile',
      desc: '',
      args: [],
    );
  }

  /// `Preparing %s`
  String get assignPreparingFile {
    return Intl.message(
      'Preparing %s',
      name: 'assignPreparingFile',
      desc: '',
      args: [],
    );
  }

  /// `Upload cancelled`
  String get assignSubmitCancelled {
    return Intl.message(
      'Upload cancelled',
      name: 'assignSubmitCancelled',
      desc: '',
      args: [],
    );
  }

  /// `Could not read what Moodle actually stores for this online text, so nothing was submitted. Try again in a moment.`
  String get assignOnlineTextRawFailed {
    return Intl.message(
      'Could not read what Moodle actually stores for this online text, so nothing was submitted. Try again in a moment.',
      name: 'assignOnlineTextRawFailed',
      desc: '',
      args: [],
    );
  }

  /// `Sent, but the latest status could not be loaded; refresh to confirm`
  String get assignStatusRefreshFailed {
    return Intl.message(
      'Sent, but the latest status could not be loaded; refresh to confirm',
      name: 'assignStatusRefreshFailed',
      desc: '',
      args: [],
    );
  }

  /// `Saving keeps this as a draft; go back and tap Submit for grading to hand it in`
  String get assignConsequenceDraft {
    return Intl.message(
      'Saving keeps this as a draft; go back and tap Submit for grading to hand it in',
      name: 'assignConsequenceDraft',
      desc: '',
      args: [],
    );
  }

  /// `This assignment has no draft stage: saving submits it`
  String get assignConsequenceDirect {
    return Intl.message(
      'This assignment has no draft stage: saving submits it',
      name: 'assignConsequenceDirect',
      desc: '',
      args: [],
    );
  }

  /// `Saving replaces what you have already submitted`
  String get assignConsequenceOverwrite {
    return Intl.message(
      'Saving replaces what you have already submitted',
      name: 'assignConsequenceOverwrite',
      desc: '',
      args: [],
    );
  }

  /// `This is reopened attempt %s; saving does not change your previous grade`
  String get assignConsequenceReopened {
    return Intl.message(
      'This is reopened attempt %s; saving does not change your previous grade',
      name: 'assignConsequenceReopened',
      desc: '',
      args: [],
    );
  }

  /// `This is reopened attempt %s; saving keeps it as a draft, so go back and tap Submit for grading to hand it in. Your previous grade is not affected`
  String get assignConsequenceReopenedDraft {
    return Intl.message(
      'This is reopened attempt %s; saving keeps it as a draft, so go back and tap Submit for grading to hand it in. Your previous grade is not affected',
      name: 'assignConsequenceReopenedDraft',
      desc: '',
      args: [],
    );
  }

  /// `Accept the submission statement first`
  String get assignBlockedStatement {
    return Intl.message(
      'Accept the submission statement first',
      name: 'assignBlockedStatement',
      desc: '',
      args: [],
    );
  }

  /// `Nothing has changed yet`
  String get assignBlockedNoChanges {
    return Intl.message(
      'Nothing has changed yet',
      name: 'assignBlockedNoChanges',
      desc: '',
      args: [],
    );
  }

  /// `You have reached the %s-file limit`
  String get assignFileLimitReached {
    return Intl.message(
      'You have reached the %s-file limit',
      name: 'assignFileLimitReached',
      desc: '',
      args: [],
    );
  }

  /// `Already on Moodle`
  String get assignFileOnServer {
    return Intl.message(
      'Already on Moodle',
      name: 'assignFileOnServer',
      desc: '',
      args: [],
    );
  }

  /// `Will be removed from Moodle when you save`
  String get assignFileWillBeRemoved {
    return Intl.message(
      'Will be removed from Moodle when you save',
      name: 'assignFileWillBeRemoved',
      desc: '',
      args: [],
    );
  }

  /// `Added now · %s`
  String get assignFileJustAdded {
    return Intl.message(
      'Added now · %s',
      name: 'assignFileJustAdded',
      desc: '',
      args: [],
    );
  }

  /// `Confirmed at submit time`
  String get assignStatementAtSubmit {
    return Intl.message(
      'Confirmed at submit time',
      name: 'assignStatementAtSubmit',
      desc: '',
      args: [],
    );
  }

  /// `Time limit`
  String get assignTimeLimit {
    return Intl.message(
      'Time limit',
      name: 'assignTimeLimit',
      desc: '',
      args: [],
    );
  }

  /// `Start`
  String get assignStartAttempt {
    return Intl.message(
      'Start',
      name: 'assignStartAttempt',
      desc: '',
      args: [],
    );
  }

  /// `Starting gives you %s to work; the clock cannot be paused`
  String get assignTimeLimitNotice {
    return Intl.message(
      'Starting gives you %s to work; the clock cannot be paused',
      name: 'assignTimeLimitNotice',
      desc: '',
      args: [],
    );
  }

  /// `The clock starts now and will not stop. Begin?`
  String get assignStartConfirm {
    return Intl.message(
      'The clock starts now and will not stop. Begin?',
      name: 'assignStartConfirm',
      desc: '',
      args: [],
    );
  }

  /// `%s left`
  String get assignTimeLeft {
    return Intl.message('%s left', name: 'assignTimeLeft', desc: '', args: []);
  }

  /// `Time remaining`
  String get assignTimeRemaining {
    return Intl.message(
      'Time remaining',
      name: 'assignTimeRemaining',
      desc: '',
      args: [],
    );
  }

  /// `Your time is up; you can still save, but it will be marked late`
  String get assignTimeExpiredStillEditable {
    return Intl.message(
      'Your time is up; you can still save, but it will be marked late',
      name: 'assignTimeExpiredStillEditable',
      desc: '',
      args: [],
    );
  }

  /// `Your attempt has started, but the time remaining is unavailable; please refresh`
  String get assignTimerStartedUnknown {
    return Intl.message(
      'Your attempt has started, but the time remaining is unavailable; please refresh',
      name: 'assignTimerStartedUnknown',
      desc: '',
      args: [],
    );
  }

  /// `This assignment is not open for submission right now`
  String get assignStartNotOpen {
    return Intl.message(
      'This assignment is not open for submission right now',
      name: 'assignStartNotOpen',
      desc: '',
      args: [],
    );
  }

  /// `This site does not allow starting the timer in the app; start it on the web`
  String get assignTimerNotAvailable {
    return Intl.message(
      'This site does not allow starting the timer in the app; start it on the web',
      name: 'assignTimerNotAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Group assignment`
  String get assignTeamSubmission {
    return Intl.message(
      'Group assignment',
      name: 'assignTeamSubmission',
      desc: '',
      args: [],
    );
  }

  /// `This is the group's shared submission; everyone in the group sees your changes`
  String get assignTeamNotice {
    return Intl.message(
      'This is the group\'s shared submission; everyone in the group sees your changes',
      name: 'assignTeamNotice',
      desc: '',
      args: [],
    );
  }

  /// `Saving replaces the whole group's current submission`
  String get assignTeamOverwriteWarning {
    return Intl.message(
      'Saving replaces the whole group\'s current submission',
      name: 'assignTeamOverwriteWarning',
      desc: '',
      args: [],
    );
  }

  /// `%s group member(s) have not submitted yet`
  String get assignTeamPendingMembers {
    return Intl.message(
      '%s group member(s) have not submitted yet',
      name: 'assignTeamPendingMembers',
      desc: '',
      args: [],
    );
  }

  /// `Everyone in the group has submitted`
  String get assignTeamAllSubmitted {
    return Intl.message(
      'Everyone in the group has submitted',
      name: 'assignTeamAllSubmitted',
      desc: '',
      args: [],
    );
  }

  /// `You are not in a group yet; ask your teacher`
  String get assignTeamNoGroup {
    return Intl.message(
      'You are not in a group yet; ask your teacher',
      name: 'assignTeamNoGroup',
      desc: '',
      args: [],
    );
  }

  /// `You belong to more than one group; choose which one on the web`
  String get assignTeamMultipleGroups {
    return Intl.message(
      'You belong to more than one group; choose which one on the web',
      name: 'assignTeamMultipleGroups',
      desc: '',
      args: [],
    );
  }

  /// `Attempt %s`
  String get assignAttemptLabel {
    return Intl.message(
      'Attempt %s',
      name: 'assignAttemptLabel',
      desc: '',
      args: [],
    );
  }

  /// `Attempt %s of %s`
  String get assignAttemptLabelOf {
    return Intl.message(
      'Attempt %s of %s',
      name: 'assignAttemptLabelOf',
      desc: '',
      args: [],
    );
  }

  /// `Current attempt`
  String get assignCurrentAttempt {
    return Intl.message(
      'Current attempt',
      name: 'assignCurrentAttempt',
      desc: '',
      args: [],
    );
  }

  /// `Previous attempts`
  String get assignPreviousAttempts {
    return Intl.message(
      'Previous attempts',
      name: 'assignPreviousAttempts',
      desc: '',
      args: [],
    );
  }

  /// `Reopened`
  String get assignStatusReopened {
    return Intl.message(
      'Reopened',
      name: 'assignStatusReopened',
      desc: '',
      args: [],
    );
  }

  /// `Start a new attempt`
  String get assignStartNewAttempt {
    return Intl.message(
      'Start a new attempt',
      name: 'assignStartNewAttempt',
      desc: '',
      args: [],
    );
  }

  /// `Copy previous attempt`
  String get assignCopyPrevious {
    return Intl.message(
      'Copy previous attempt',
      name: 'assignCopyPrevious',
      desc: '',
      args: [],
    );
  }

  /// `This copies the files and text from your last attempt over anything you have entered`
  String get assignCopyPreviousConfirm {
    return Intl.message(
      'This copies the files and text from your last attempt over anything you have entered',
      name: 'assignCopyPreviousConfirm',
      desc: '',
      args: [],
    );
  }

  /// `This assignment has no draft stage: the copy is submitted immediately`
  String get assignCopyPreviousSubmitsNow {
    return Intl.message(
      'This assignment has no draft stage: the copy is submitted immediately',
      name: 'assignCopyPreviousSubmitsNow',
      desc: '',
      args: [],
    );
  }

  /// `This site does not allow copying in the app; do it on the web`
  String get assignCopyPreviousWebOnly {
    return Intl.message(
      'This site does not allow copying in the app; do it on the web',
      name: 'assignCopyPreviousWebOnly',
      desc: '',
      args: [],
    );
  }

  /// `Copied from your last attempt`
  String get assignCopyPreviousDone {
    return Intl.message(
      'Copied from your last attempt',
      name: 'assignCopyPreviousDone',
      desc: '',
      args: [],
    );
  }

  /// `Moodle did not copy your last attempt; refresh and try again`
  String get assignCopyPreviousRejected {
    return Intl.message(
      'Moodle did not copy your last attempt; refresh and try again',
      name: 'assignCopyPreviousRejected',
      desc: '',
      args: [],
    );
  }

  /// `Remove submission`
  String get assignRemoveSubmission {
    return Intl.message(
      'Remove submission',
      name: 'assignRemoveSubmission',
      desc: '',
      args: [],
    );
  }

  /// `This deletes every file and all the text in this submission, and cannot be undone`
  String get assignRemoveConfirm {
    return Intl.message(
      'This deletes every file and all the text in this submission, and cannot be undone',
      name: 'assignRemoveConfirm',
      desc: '',
      args: [],
    );
  }

  /// `This wipes the whole group's submission; every member is affected`
  String get assignRemoveConfirmTeam {
    return Intl.message(
      'This wipes the whole group\'s submission; every member is affected',
      name: 'assignRemoveConfirmTeam',
      desc: '',
      args: [],
    );
  }

  /// `This assignment is already submitted; you would have to submit again`
  String get assignRemoveConfirmSubmitted {
    return Intl.message(
      'This assignment is already submitted; you would have to submit again',
      name: 'assignRemoveConfirmSubmitted',
      desc: '',
      args: [],
    );
  }

  /// `Removing does not reset the time limit`
  String get assignRemoveKeepsTimer {
    return Intl.message(
      'Removing does not reset the time limit',
      name: 'assignRemoveKeepsTimer',
      desc: '',
      args: [],
    );
  }

  /// `Submission removed`
  String get assignRemoved {
    return Intl.message(
      'Submission removed',
      name: 'assignRemoved',
      desc: '',
      args: [],
    );
  }

  /// `Moodle did not remove the submission; refresh and try again`
  String get assignRemoveRejected {
    return Intl.message(
      'Moodle did not remove the submission; refresh and try again',
      name: 'assignRemoveRejected',
      desc: '',
      args: [],
    );
  }

  /// `This site does not allow removing in the app; do it on the web`
  String get assignRemoveWebOnly {
    return Intl.message(
      'This site does not allow removing in the app; do it on the web',
      name: 'assignRemoveWebOnly',
      desc: '',
      args: [],
    );
  }

  /// `This assignment uses a submission type the app does not support yet; submit it on the web`
  String get assignSubmitWebOnlyPlugin {
    return Intl.message(
      'This assignment uses a submission type the app does not support yet; submit it on the web',
      name: 'assignSubmitWebOnlyPlugin',
      desc: '',
      args: [],
    );
  }

  /// `This assignment is blind-marked; your teacher does not see your name`
  String get assignBlindMarkingNote {
    return Intl.message(
      'This assignment is blind-marked; your teacher does not see your name',
      name: 'assignBlindMarkingNote',
      desc: '',
      args: [],
    );
  }

  /// `Awaiting grade`
  String get assignStatusAwaitingGrade {
    return Intl.message(
      'Awaiting grade',
      name: 'assignStatusAwaitingGrade',
      desc: '',
      args: [],
    );
  }

  /// `Extended`
  String get assignStatusExtended {
    return Intl.message(
      'Extended',
      name: 'assignStatusExtended',
      desc: '',
      args: [],
    );
  }

  /// `Due %s`
  String get assignDueOn {
    return Intl.message('Due %s', name: 'assignDueOn', desc: '', args: []);
  }

  /// `Extended to %s`
  String get assignExtendedTo {
    return Intl.message(
      'Extended to %s',
      name: 'assignExtendedTo',
      desc: '',
      args: [],
    );
  }

  /// `Submitted %s`
  String get assignSubmittedOn {
    return Intl.message(
      'Submitted %s',
      name: 'assignSubmittedOn',
      desc: '',
      args: [],
    );
  }

  /// `Last edited %s`
  String get assignDraftEditedAt {
    return Intl.message(
      'Last edited %s',
      name: 'assignDraftEditedAt',
      desc: '',
      args: [],
    );
  }

  /// `%s day(s) left`
  String get assignRemainDays {
    return Intl.message(
      '%s day(s) left',
      name: 'assignRemainDays',
      desc: '',
      args: [],
    );
  }

  /// `%s hour(s) left`
  String get assignRemainHours {
    return Intl.message(
      '%s hour(s) left',
      name: 'assignRemainHours',
      desc: '',
      args: [],
    );
  }

  /// `Less than an hour left`
  String get assignRemainSoon {
    return Intl.message(
      'Less than an hour left',
      name: 'assignRemainSoon',
      desc: '',
      args: [],
    );
  }

  /// `%s item(s)`
  String get assignCountItems {
    return Intl.message(
      '%s item(s)',
      name: 'assignCountItems',
      desc: '',
      args: [],
    );
  }

  /// `All graded`
  String get assignAllGraded {
    return Intl.message(
      'All graded',
      name: 'assignAllGraded',
      desc: '',
      args: [],
    );
  }

  /// `Feedback`
  String get gradeFeedbackTag {
    return Intl.message(
      'Feedback',
      name: 'gradeFeedbackTag',
      desc: '',
      args: [],
    );
  }

  /// `Collapse`
  String get collapse {
    return Intl.message('Collapse', name: 'collapse', desc: '', args: []);
  }

  /// `Quiz`
  String get quizDetail {
    return Intl.message('Quiz', name: 'quizDetail', desc: '', args: []);
  }

  /// `Failed to load quizzes`
  String get getMoodleQuizzesError {
    return Intl.message(
      'Failed to load quizzes',
      name: 'getMoodleQuizzesError',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load quiz attempts`
  String get getMoodleQuizAttemptsError {
    return Intl.message(
      'Failed to load quiz attempts',
      name: 'getMoodleQuizAttemptsError',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load quiz grade`
  String get getMoodleQuizBestGradeError {
    return Intl.message(
      'Failed to load quiz grade',
      name: 'getMoodleQuizBestGradeError',
      desc: '',
      args: [],
    );
  }

  /// `This quiz was not found on Moodle`
  String get quizNotFound {
    return Intl.message(
      'This quiz was not found on Moodle',
      name: 'quizNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Availability`
  String get quizSectionWindow {
    return Intl.message(
      'Availability',
      name: 'quizSectionWindow',
      desc: '',
      args: [],
    );
  }

  /// `Rules`
  String get quizSectionRules {
    return Intl.message('Rules', name: 'quizSectionRules', desc: '', args: []);
  }

  /// `My grade`
  String get quizSectionGrade {
    return Intl.message(
      'My grade',
      name: 'quizSectionGrade',
      desc: '',
      args: [],
    );
  }

  /// `Attempts`
  String get quizSectionAttempts {
    return Intl.message(
      'Attempts',
      name: 'quizSectionAttempts',
      desc: '',
      args: [],
    );
  }

  /// `Description`
  String get quizIntro {
    return Intl.message('Description', name: 'quizIntro', desc: '', args: []);
  }

  /// `Opens`
  String get quizTimeOpen {
    return Intl.message('Opens', name: 'quizTimeOpen', desc: '', args: []);
  }

  /// `Closes`
  String get quizTimeClose {
    return Intl.message('Closes', name: 'quizTimeClose', desc: '', args: []);
  }

  /// `Always available`
  String get quizAlwaysOpen {
    return Intl.message(
      'Always available',
      name: 'quizAlwaysOpen',
      desc: '',
      args: [],
    );
  }

  /// `Opens in %s day(s)`
  String get quizOpensInDays {
    return Intl.message(
      'Opens in %s day(s)',
      name: 'quizOpensInDays',
      desc: '',
      args: [],
    );
  }

  /// `Opens in %s hour(s)`
  String get quizOpensInHours {
    return Intl.message(
      'Opens in %s hour(s)',
      name: 'quizOpensInHours',
      desc: '',
      args: [],
    );
  }

  /// `Opens within an hour`
  String get quizOpensSoon {
    return Intl.message(
      'Opens within an hour',
      name: 'quizOpensSoon',
      desc: '',
      args: [],
    );
  }

  /// `Open, with no closing time`
  String get quizOpenNoClose {
    return Intl.message(
      'Open, with no closing time',
      name: 'quizOpenNoClose',
      desc: '',
      args: [],
    );
  }

  /// `Closes in %s day(s)`
  String get quizClosesInDays {
    return Intl.message(
      'Closes in %s day(s)',
      name: 'quizClosesInDays',
      desc: '',
      args: [],
    );
  }

  /// `Closes in %s hour(s)`
  String get quizClosesInHours {
    return Intl.message(
      'Closes in %s hour(s)',
      name: 'quizClosesInHours',
      desc: '',
      args: [],
    );
  }

  /// `Closes within an hour`
  String get quizClosesSoon {
    return Intl.message(
      'Closes within an hour',
      name: 'quizClosesSoon',
      desc: '',
      args: [],
    );
  }

  /// `Closed %s day(s) ago`
  String get quizClosedDays {
    return Intl.message(
      'Closed %s day(s) ago',
      name: 'quizClosedDays',
      desc: '',
      args: [],
    );
  }

  /// `Closed %s hour(s) ago`
  String get quizClosedHours {
    return Intl.message(
      'Closed %s hour(s) ago',
      name: 'quizClosedHours',
      desc: '',
      args: [],
    );
  }

  /// `Just closed`
  String get quizClosedJustNow {
    return Intl.message(
      'Just closed',
      name: 'quizClosedJustNow',
      desc: '',
      args: [],
    );
  }

  /// `Time limit`
  String get quizTimeLimit {
    return Intl.message(
      'Time limit',
      name: 'quizTimeLimit',
      desc: '',
      args: [],
    );
  }

  /// `No time limit`
  String get quizNoTimeLimit {
    return Intl.message(
      'No time limit',
      name: 'quizNoTimeLimit',
      desc: '',
      args: [],
    );
  }

  /// `%s hr`
  String get quizDurationHours {
    return Intl.message('%s hr', name: 'quizDurationHours', desc: '', args: []);
  }

  /// `%s min`
  String get quizDurationMinutes {
    return Intl.message(
      '%s min',
      name: 'quizDurationMinutes',
      desc: '',
      args: [],
    );
  }

  /// `Attempts allowed`
  String get quizAttemptsAllowed {
    return Intl.message(
      'Attempts allowed',
      name: 'quizAttemptsAllowed',
      desc: '',
      args: [],
    );
  }

  /// `Unlimited`
  String get quizAttemptsUnlimited {
    return Intl.message(
      'Unlimited',
      name: 'quizAttemptsUnlimited',
      desc: '',
      args: [],
    );
  }

  /// `%s of %s used`
  String get quizAttemptsUsedOf {
    return Intl.message(
      '%s of %s used',
      name: 'quizAttemptsUsedOf',
      desc: '',
      args: [],
    );
  }

  /// `Grading method`
  String get quizGradeMethod {
    return Intl.message(
      'Grading method',
      name: 'quizGradeMethod',
      desc: '',
      args: [],
    );
  }

  /// `Highest grade`
  String get quizGradeMethodHighest {
    return Intl.message(
      'Highest grade',
      name: 'quizGradeMethodHighest',
      desc: '',
      args: [],
    );
  }

  /// `Average grade`
  String get quizGradeMethodAverage {
    return Intl.message(
      'Average grade',
      name: 'quizGradeMethodAverage',
      desc: '',
      args: [],
    );
  }

  /// `First attempt`
  String get quizGradeMethodFirst {
    return Intl.message(
      'First attempt',
      name: 'quizGradeMethodFirst',
      desc: '',
      args: [],
    );
  }

  /// `Last attempt`
  String get quizGradeMethodLast {
    return Intl.message(
      'Last attempt',
      name: 'quizGradeMethodLast',
      desc: '',
      args: [],
    );
  }

  /// `Unknown grading method`
  String get quizGradeMethodUnknown {
    return Intl.message(
      'Unknown grading method',
      name: 'quizGradeMethodUnknown',
      desc: '',
      args: [],
    );
  }

  /// `Best grade`
  String get quizBestGrade {
    return Intl.message(
      'Best grade',
      name: 'quizBestGrade',
      desc: '',
      args: [],
    );
  }

  /// `No grade yet`
  String get quizNoGrade {
    return Intl.message(
      'No grade yet',
      name: 'quizNoGrade',
      desc: '',
      args: [],
    );
  }

  /// `Grade to pass`
  String get quizGradeToPass {
    return Intl.message(
      'Grade to pass',
      name: 'quizGradeToPass',
      desc: '',
      args: [],
    );
  }

  /// `%s / %s`
  String get quizGradeOutOf {
    return Intl.message('%s / %s', name: 'quizGradeOutOf', desc: '', args: []);
  }

  /// `Attempt %s`
  String get quizAttemptNumber {
    return Intl.message(
      'Attempt %s',
      name: 'quizAttemptNumber',
      desc: '',
      args: [],
    );
  }

  /// `Not started`
  String get quizAttemptStateNotStarted {
    return Intl.message(
      'Not started',
      name: 'quizAttemptStateNotStarted',
      desc: '',
      args: [],
    );
  }

  /// `In progress`
  String get quizAttemptStateInProgress {
    return Intl.message(
      'In progress',
      name: 'quizAttemptStateInProgress',
      desc: '',
      args: [],
    );
  }

  /// `Submitted`
  String get quizAttemptStateSubmitted {
    return Intl.message(
      'Submitted',
      name: 'quizAttemptStateSubmitted',
      desc: '',
      args: [],
    );
  }

  /// `Overdue`
  String get quizAttemptStateOverdue {
    return Intl.message(
      'Overdue',
      name: 'quizAttemptStateOverdue',
      desc: '',
      args: [],
    );
  }

  /// `Finished`
  String get quizAttemptStateFinished {
    return Intl.message(
      'Finished',
      name: 'quizAttemptStateFinished',
      desc: '',
      args: [],
    );
  }

  /// `Never submitted`
  String get quizAttemptStateAbandoned {
    return Intl.message(
      'Never submitted',
      name: 'quizAttemptStateAbandoned',
      desc: '',
      args: [],
    );
  }

  /// `Unknown state`
  String get quizAttemptStateUnknown {
    return Intl.message(
      'Unknown state',
      name: 'quizAttemptStateUnknown',
      desc: '',
      args: [],
    );
  }

  /// `Submitted`
  String get quizAttemptFinishedAt {
    return Intl.message(
      'Submitted',
      name: 'quizAttemptFinishedAt',
      desc: '',
      args: [],
    );
  }

  /// `Started`
  String get quizAttemptStartedAt {
    return Intl.message(
      'Started',
      name: 'quizAttemptStartedAt',
      desc: '',
      args: [],
    );
  }

  /// `You haven't attempted this quiz yet`
  String get quizAttemptsEmpty {
    return Intl.message(
      'You haven\'t attempted this quiz yet',
      name: 'quizAttemptsEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Attempt in browser`
  String get quizAnswerInWeb {
    return Intl.message(
      'Attempt in browser',
      name: 'quizAnswerInWeb',
      desc: '',
      args: [],
    );
  }

  /// `This course has no announcements forum`
  String get announcementNoForum {
    return Intl.message(
      'This course has no announcements forum',
      name: 'announcementNoForum',
      desc: '',
      args: [],
    );
  }

  /// `%s replies`
  String get forumReplies {
    return Intl.message('%s replies', name: 'forumReplies', desc: '', args: []);
  }

  /// `Attachments`
  String get forumAttachments {
    return Intl.message(
      'Attachments',
      name: 'forumAttachments',
      desc: '',
      args: [],
    );
  }

  /// `This post has been deleted`
  String get forumPostDeleted {
    return Intl.message(
      'This post has been deleted',
      name: 'forumPostDeleted',
      desc: '',
      args: [],
    );
  }

  /// `Unknown author`
  String get forumUnknownAuthor {
    return Intl.message(
      'Unknown author',
      name: 'forumUnknownAuthor',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load the discussion`
  String get getMoodleForumPostsError {
    return Intl.message(
      'Failed to load the discussion',
      name: 'getMoodleForumPostsError',
      desc: '',
      args: [],
    );
  }

  /// `Reply`
  String get forumReply {
    return Intl.message('Reply', name: 'forumReply', desc: '', args: []);
  }

  /// `Replying to %s`
  String get forumReplyingTo {
    return Intl.message(
      'Replying to %s',
      name: 'forumReplyingTo',
      desc: '',
      args: [],
    );
  }

  /// `Replying to the topic: %s`
  String get forumReplyingToTopic {
    return Intl.message(
      'Replying to the topic: %s',
      name: 'forumReplyingToTopic',
      desc: '',
      args: [],
    );
  }

  /// `Subject`
  String get forumSubject {
    return Intl.message('Subject', name: 'forumSubject', desc: '', args: []);
  }

  /// `Give this discussion a subject`
  String get forumSubjectHint {
    return Intl.message(
      'Give this discussion a subject',
      name: 'forumSubjectHint',
      desc: '',
      args: [],
    );
  }

  /// `Write your message…`
  String get forumMessageHint {
    return Intl.message(
      'Write your message…',
      name: 'forumMessageHint',
      desc: '',
      args: [],
    );
  }

  /// `Post`
  String get forumSend {
    return Intl.message('Post', name: 'forumSend', desc: '', args: []);
  }

  /// `Posting…`
  String get forumSending {
    return Intl.message('Posting…', name: 'forumSending', desc: '', args: []);
  }

  /// `Posted, but the thread could not be reloaded`
  String get forumSendDoneRefreshFailed {
    return Intl.message(
      'Posted, but the thread could not be reloaded',
      name: 'forumSendDoneRefreshFailed',
      desc: '',
      args: [],
    );
  }

  /// `Couldn't post — refresh to check whether it went through before posting again`
  String get forumSendError {
    return Intl.message(
      'Couldn\'t post — refresh to check whether it went through before posting again',
      name: 'forumSendError',
      desc: '',
      args: [],
    );
  }

  /// `Upload cancelled`
  String get forumSendCancelled {
    return Intl.message(
      'Upload cancelled',
      name: 'forumSendCancelled',
      desc: '',
      args: [],
    );
  }

  /// `Enter a subject first`
  String get forumSubjectRequired {
    return Intl.message(
      'Enter a subject first',
      name: 'forumSubjectRequired',
      desc: '',
      args: [],
    );
  }

  /// `Write something first`
  String get forumMessageRequired {
    return Intl.message(
      'Write something first',
      name: 'forumMessageRequired',
      desc: '',
      args: [],
    );
  }

  /// `Discard what you haven't posted yet?`
  String get forumDiscardDraft {
    return Intl.message(
      'Discard what you haven\'t posted yet?',
      name: 'forumDiscardDraft',
      desc: '',
      args: [],
    );
  }

  /// `Open forum in browser`
  String get forumOpenInWeb {
    return Intl.message(
      'Open forum in browser',
      name: 'forumOpenInWeb',
      desc: '',
      args: [],
    );
  }

  /// `All`
  String get forumFilterAll {
    return Intl.message('All', name: 'forumFilterAll', desc: '', args: []);
  }

  /// `Announcements %s`
  String get forumFilterAnnouncements {
    return Intl.message(
      'Announcements %s',
      name: 'forumFilterAnnouncements',
      desc: '',
      args: [],
    );
  }

  /// `Discussions %s`
  String get forumFilterDiscussions {
    return Intl.message(
      'Discussions %s',
      name: 'forumFilterDiscussions',
      desc: '',
      args: [],
    );
  }

  /// `This forum has no discussions yet`
  String get forumEmpty {
    return Intl.message(
      'This forum has no discussions yet',
      name: 'forumEmpty',
      desc: '',
      args: [],
    );
  }

  /// `This thread is not open for replies`
  String get forumThreadLocked {
    return Intl.message(
      'This thread is not open for replies',
      name: 'forumThreadLocked',
      desc: '',
      args: [],
    );
  }

  /// `You can't post in this forum from the app`
  String get forumCannotPost {
    return Intl.message(
      'You can\'t post in this forum from the app',
      name: 'forumCannotPost',
      desc: '',
      args: [],
    );
  }

  /// `You can't post in this thread right now`
  String get forumErrorNoPermission {
    return Intl.message(
      'You can\'t post in this thread right now',
      name: 'forumErrorNoPermission',
      desc: '',
      args: [],
    );
  }

  /// `The post you replied to is gone; the thread may have changed`
  String get forumErrorPostGone {
    return Intl.message(
      'The post you replied to is gone; the thread may have changed',
      name: 'forumErrorPostGone',
      desc: '',
      args: [],
    );
  }

  /// `You've hit this forum's posting limit`
  String get forumErrorTooManyPosts {
    return Intl.message(
      'You\'ve hit this forum\'s posting limit',
      name: 'forumErrorTooManyPosts',
      desc: '',
      args: [],
    );
  }

  /// `This folder is empty`
  String get folderEmpty {
    return Intl.message(
      'This folder is empty',
      name: 'folderEmpty',
      desc: '',
      args: [],
    );
  }

  /// `%s file(s)`
  String get folderFileCount {
    return Intl.message(
      '%s file(s)',
      name: 'folderFileCount',
      desc: '',
      args: [],
    );
  }

  /// `Announcements & notifications`
  String get announcementCenter {
    return Intl.message(
      'Announcements & notifications',
      name: 'announcementCenter',
      desc: '',
      args: [],
    );
  }

  /// `Notifications`
  String get notificationCenterTitle {
    return Intl.message(
      'Notifications',
      name: 'notificationCenterTitle',
      desc: '',
      args: [],
    );
  }

  /// `TAT announcements`
  String get appAnnouncement {
    return Intl.message(
      'TAT announcements',
      name: 'appAnnouncement',
      desc: '',
      args: [],
    );
  }

  /// `Published`
  String get announcementPublishedAt {
    return Intl.message(
      'Published',
      name: 'announcementPublishedAt',
      desc: '',
      args: [],
    );
  }

  /// `Read the full announcement`
  String get announcementReadFull {
    return Intl.message(
      'Read the full announcement',
      name: 'announcementReadFull',
      desc: '',
      args: [],
    );
  }

  /// `Next`
  String get announcementNext {
    return Intl.message('Next', name: 'announcementNext', desc: '', args: []);
  }

  /// `Failed to load TAT announcements`
  String get getAppNoticeError {
    return Intl.message(
      'Failed to load TAT announcements',
      name: 'getAppNoticeError',
      desc: '',
      args: [],
    );
  }

  /// `Earlier`
  String get notificationGroupEarlier {
    return Intl.message(
      'Earlier',
      name: 'notificationGroupEarlier',
      desc: '',
      args: [],
    );
  }

  /// `No notifications`
  String get notificationEmpty {
    return Intl.message(
      'No notifications',
      name: 'notificationEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Course announcements, assignment deadlines and released grades show up here.`
  String get notificationEmptyHint {
    return Intl.message(
      'Course announcements, assignment deadlines and released grades show up here.',
      name: 'notificationEmptyHint',
      desc: '',
      args: [],
    );
  }

  /// `Site notifications are turned off in your Moodle preferences. Turn them back on in the notification preferences on the Moodle website.`
  String get notificationDisabledOnMoodle {
    return Intl.message(
      'Site notifications are turned off in your Moodle preferences. Turn them back on in the notification preferences on the Moodle website.',
      name: 'notificationDisabledOnMoodle',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load Moodle notifications`
  String get getMoodleNotificationsError {
    return Intl.message(
      'Failed to load Moodle notifications',
      name: 'getMoodleNotificationsError',
      desc: '',
      args: [],
    );
  }

  /// `Unread`
  String get notificationUnread {
    return Intl.message(
      'Unread',
      name: 'notificationUnread',
      desc: '',
      args: [],
    );
  }

  /// `Announcements & notifications, %s unread`
  String get notificationUnreadTooltip {
    return Intl.message(
      'Announcements & notifications, %s unread',
      name: 'notificationUnreadTooltip',
      desc: '',
      args: [],
    );
  }

  /// `System notification`
  String get notificationUnknownSource {
    return Intl.message(
      'System notification',
      name: 'notificationUnknownSource',
      desc: '',
      args: [],
    );
  }

  /// `Mark all as read`
  String get notificationMarkAllRead {
    return Intl.message(
      'Mark all as read',
      name: 'notificationMarkAllRead',
      desc: '',
      args: [],
    );
  }

  /// `Mark every unread notification on Moodle as read, including ones not shown on this page? The school server deletes read notifications after 7 days by default.`
  String get notificationMarkAllReadConfirm {
    return Intl.message(
      'Mark every unread notification on Moodle as read, including ones not shown on this page? The school server deletes read notifications after 7 days by default.',
      name: 'notificationMarkAllReadConfirm',
      desc: '',
      args: [],
    );
  }

  /// `All notifications marked as read`
  String get notificationMarkAllReadDone {
    return Intl.message(
      'All notifications marked as read',
      name: 'notificationMarkAllReadDone',
      desc: '',
      args: [],
    );
  }

  /// `Failed to mark all as read`
  String get notificationMarkAllReadError {
    return Intl.message(
      'Failed to mark all as read',
      name: 'notificationMarkAllReadError',
      desc: '',
      args: [],
    );
  }

  /// `Failed to mark as read`
  String get notificationMarkReadError {
    return Intl.message(
      'Failed to mark as read',
      name: 'notificationMarkReadError',
      desc: '',
      args: [],
    );
  }

  /// `Moodle running totals`
  String get moodleCourseGrades {
    return Intl.message(
      'Moodle running totals',
      name: 'moodleCourseGrades',
      desc: '',
      args: [],
    );
  }

  /// `These are running totals calculated from grading on Moodle, not your official NTUST grades. A course shows "-" when it has no total yet — the teacher may not have graded it, or may have hidden the total.`
  String get moodleCourseGradesHint {
    return Intl.message(
      'These are running totals calculated from grading on Moodle, not your official NTUST grades. A course shows "-" when it has no total yet — the teacher may not have graded it, or may have hidden the total.',
      name: 'moodleCourseGradesHint',
      desc: '',
      args: [],
    );
  }

  /// `No Moodle totals to show for this semester`
  String get moodleCourseGradesEmpty {
    return Intl.message(
      'No Moodle totals to show for this semester',
      name: 'moodleCourseGradesEmpty',
      desc: '',
      args: [],
    );
  }

  /// `Failed to load Moodle running totals`
  String get getMoodleCourseGradesError {
    return Intl.message(
      'Failed to load Moodle running totals',
      name: 'getMoodleCourseGradesError',
      desc: '',
      args: [],
    );
  }

  /// `Change profile picture`
  String get avatarChange {
    return Intl.message(
      'Change profile picture',
      name: 'avatarChange',
      desc: '',
      args: [],
    );
  }

  /// `Choose from library`
  String get avatarFromGallery {
    return Intl.message(
      'Choose from library',
      name: 'avatarFromGallery',
      desc: '',
      args: [],
    );
  }

  /// `Take a photo`
  String get avatarTakePhoto {
    return Intl.message(
      'Take a photo',
      name: 'avatarTakePhoto',
      desc: '',
      args: [],
    );
  }

  /// `Remove picture`
  String get avatarRemove {
    return Intl.message(
      'Remove picture',
      name: 'avatarRemove',
      desc: '',
      args: [],
    );
  }

  /// `Remove your current profile picture? Moodle will fall back to the default icon and the original image cannot be recovered.`
  String get avatarRemoveConfirm {
    return Intl.message(
      'Remove your current profile picture? Moodle will fall back to the default icon and the original image cannot be recovered.',
      name: 'avatarRemoveConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Profile picture updated`
  String get avatarUpdated {
    return Intl.message(
      'Profile picture updated',
      name: 'avatarUpdated',
      desc: '',
      args: [],
    );
  }

  /// `Profile picture removed`
  String get avatarRemoved {
    return Intl.message(
      'Profile picture removed',
      name: 'avatarRemoved',
      desc: '',
      args: [],
    );
  }

  /// `Couldn't change your profile picture`
  String get avatarUpdateError {
    return Intl.message(
      'Couldn\'t change your profile picture',
      name: 'avatarUpdateError',
      desc: '',
      args: [],
    );
  }

  /// `This Moodle site doesn't allow changing your picture from the app. Change it on the Moodle website instead.`
  String get avatarNotSupported {
    return Intl.message(
      'This Moodle site doesn\'t allow changing your picture from the app. Change it on the Moodle website instead.',
      name: 'avatarNotSupported',
      desc: '',
      args: [],
    );
  }

  /// `Profile pictures are turned off on this Moodle site`
  String get avatarDisabledOnSite {
    return Intl.message(
      'Profile pictures are turned off on this Moodle site',
      name: 'avatarDisabledOnSite',
      desc: '',
      args: [],
    );
  }

  /// `Your Moodle profile is managed by the school account system and can't be edited in the app`
  String get avatarProfileLocked {
    return Intl.message(
      'Your Moodle profile is managed by the school account system and can\'t be edited in the app',
      name: 'avatarProfileLocked',
      desc: '',
      args: [],
    );
  }

  /// `Your Moodle account isn't allowed to edit its own profile`
  String get avatarNoPermission {
    return Intl.message(
      'Your Moodle account isn\'t allowed to edit its own profile',
      name: 'avatarNoPermission',
      desc: '',
      args: [],
    );
  }

  /// `File upload is turned off on this Moodle site`
  String get avatarUploadDisabled {
    return Intl.message(
      'File upload is turned off on this Moodle site',
      name: 'avatarUploadDisabled',
      desc: '',
      args: [],
    );
  }

  /// `That image is too large. The site limit is %s.`
  String get avatarTooLarge {
    return Intl.message(
      'That image is too large. The site limit is %s.',
      name: 'avatarTooLarge',
      desc: '',
      args: [],
    );
  }

  /// `That image is over the Moodle site's upload size limit`
  String get avatarTooLargeUnknown {
    return Intl.message(
      'That image is over the Moodle site\'s upload size limit',
      name: 'avatarTooLargeUnknown',
      desc: '',
      args: [],
    );
  }

  /// `Moodle couldn't process that image. Try a JPG or PNG.`
  String get avatarInvalidImage {
    return Intl.message(
      'Moodle couldn\'t process that image. Try a JPG or PNG.',
      name: 'avatarInvalidImage',
      desc: '',
      args: [],
    );
  }

  /// `Camera access is off. Turn it on in system settings and try again.`
  String get avatarCameraDenied {
    return Intl.message(
      'Camera access is off. Turn it on in system settings and try again.',
      name: 'avatarCameraDenied',
      desc: '',
      args: [],
    );
  }

  /// `Photo access is off. Turn it on in system settings and try again.`
  String get avatarGalleryDenied {
    return Intl.message(
      'Photo access is off. Turn it on in system settings and try again.',
      name: 'avatarGalleryDenied',
      desc: '',
      args: [],
    );
  }

  /// `Couldn't open the camera or photo library right now. Please try again.`
  String get avatarPickerUnavailable {
    return Intl.message(
      'Couldn\'t open the camera or photo library right now. Please try again.',
      name: 'avatarPickerUnavailable',
      desc: '',
      args: [],
    );
  }

  /// `Write a reply…`
  String get forumReplyHint {
    return Intl.message(
      'Write a reply…',
      name: 'forumReplyHint',
      desc: '',
      args: [],
    );
  }

  /// `Reply to the first post instead`
  String get forumCancelReplyTarget {
    return Intl.message(
      'Reply to the first post instead',
      name: 'forumCancelReplyTarget',
      desc: '',
      args: [],
    );
  }

  /// `Add attachment`
  String get forumAddAttachment {
    return Intl.message(
      'Add attachment',
      name: 'forumAddAttachment',
      desc: '',
      args: [],
    );
  }

  /// `Take a photo`
  String get forumAttachFromCamera {
    return Intl.message(
      'Take a photo',
      name: 'forumAttachFromCamera',
      desc: '',
      args: [],
    );
  }

  /// `Choose from library`
  String get forumAttachFromGallery {
    return Intl.message(
      'Choose from library',
      name: 'forumAttachFromGallery',
      desc: '',
      args: [],
    );
  }

  /// `Choose a file`
  String get forumAttachFromFiles {
    return Intl.message(
      'Choose a file',
      name: 'forumAttachFromFiles',
      desc: '',
      args: [],
    );
  }

  /// `Remove this attachment`
  String get forumRemoveAttachment {
    return Intl.message(
      'Remove this attachment',
      name: 'forumRemoveAttachment',
      desc: '',
      args: [],
    );
  }

  /// `Up to %s files`
  String get forumAttachmentLimit {
    return Intl.message(
      'Up to %s files',
      name: 'forumAttachmentLimit',
      desc: '',
      args: [],
    );
  }

  /// `Up to %s per file`
  String get forumAttachmentSizeLimit {
    return Intl.message(
      'Up to %s per file',
      name: 'forumAttachmentSizeLimit',
      desc: '',
      args: [],
    );
  }

  /// `"%s" is over the %s per-file limit`
  String get forumAttachmentTooLarge {
    return Intl.message(
      '"%s" is over the %s per-file limit',
      name: 'forumAttachmentTooLarge',
      desc: '',
      args: [],
    );
  }

  /// `Two files share a name; Moodle keeps only the first, so rename one`
  String get forumAttachmentDuplicateName {
    return Intl.message(
      'Two files share a name; Moodle keeps only the first, so rename one',
      name: 'forumAttachmentDuplicateName',
      desc: '',
      args: [],
    );
  }

  /// `This forum allows at most %s attachments`
  String get forumAttachmentCountExceeded {
    return Intl.message(
      'This forum allows at most %s attachments',
      name: 'forumAttachmentCountExceeded',
      desc: '',
      args: [],
    );
  }

  /// `%s did not upload; check on the website`
  String get forumAttachmentMissing {
    return Intl.message(
      '%s did not upload; check on the website',
      name: 'forumAttachmentMissing',
      desc: '',
      args: [],
    );
  }

  /// `This forum does not allow attachments`
  String get forumAttachmentDisabled {
    return Intl.message(
      'This forum does not allow attachments',
      name: 'forumAttachmentDisabled',
      desc: '',
      args: [],
    );
  }

  /// `File upload is disabled on the school's Moodle`
  String get forumAttachmentUploadDisabled {
    return Intl.message(
      'File upload is disabled on the school\'s Moodle',
      name: 'forumAttachmentUploadDisabled',
      desc: '',
      args: [],
    );
  }

  /// `Bold, lists and tables need the website editor.`
  String get forumFormattingInWeb {
    return Intl.message(
      'Bold, lists and tables need the website editor.',
      name: 'forumFormattingInWeb',
      desc: '',
      args: [],
    );
  }

  /// `This post is Markdown source: **bold**, - lists and tables all work right here.`
  String get forumMarkdownSource {
    return Intl.message(
      'This post is Markdown source: **bold**, - lists and tables all work right here.',
      name: 'forumMarkdownSource',
      desc: '',
      args: [],
    );
  }

  /// `This post uses the site's own format and is saved back exactly as typed.`
  String get forumRawSourceEdit {
    return Intl.message(
      'This post uses the site\'s own format and is saved back exactly as typed.',
      name: 'forumRawSourceEdit',
      desc: '',
      args: [],
    );
  }

  /// `edited`
  String get forumEdited {
    return Intl.message('edited', name: 'forumEdited', desc: '', args: []);
  }

  /// `Started`
  String get forumTopicStarter {
    return Intl.message(
      'Started',
      name: 'forumTopicStarter',
      desc: '',
      args: [],
    );
  }

  /// `Edit post`
  String get forumEditPost {
    return Intl.message('Edit post', name: 'forumEditPost', desc: '', args: []);
  }

  /// `Save`
  String get forumSaveEdit {
    return Intl.message('Save', name: 'forumSaveEdit', desc: '', args: []);
  }

  /// `Updated`
  String get forumEditDone {
    return Intl.message('Updated', name: 'forumEditDone', desc: '', args: []);
  }

  /// `Update failed; refresh to check whether it went through instead of saving again`
  String get forumEditError {
    return Intl.message(
      'Update failed; refresh to check whether it went through instead of saving again',
      name: 'forumEditError',
      desc: '',
      args: [],
    );
  }

  /// `The time window for editing this post has closed`
  String get forumEditWindowClosed {
    return Intl.message(
      'The time window for editing this post has closed',
      name: 'forumEditWindowClosed',
      desc: '',
      args: [],
    );
  }

  /// `Edit post`
  String get forumEditRichTitle {
    return Intl.message(
      'Edit post',
      name: 'forumEditRichTitle',
      desc: '',
      args: [],
    );
  }

  /// `Bold`
  String get forumEditorBold {
    return Intl.message('Bold', name: 'forumEditorBold', desc: '', args: []);
  }

  /// `Italic`
  String get forumEditorItalic {
    return Intl.message(
      'Italic',
      name: 'forumEditorItalic',
      desc: '',
      args: [],
    );
  }

  /// `Underline`
  String get forumEditorUnderline {
    return Intl.message(
      'Underline',
      name: 'forumEditorUnderline',
      desc: '',
      args: [],
    );
  }

  /// `Strikethrough`
  String get forumEditorStrikethrough {
    return Intl.message(
      'Strikethrough',
      name: 'forumEditorStrikethrough',
      desc: '',
      args: [],
    );
  }

  /// `Paragraph`
  String get forumEditorParagraph {
    return Intl.message(
      'Paragraph',
      name: 'forumEditorParagraph',
      desc: '',
      args: [],
    );
  }

  /// `Heading %s`
  String get forumEditorHeading {
    return Intl.message(
      'Heading %s',
      name: 'forumEditorHeading',
      desc: '',
      args: [],
    );
  }

  /// `Bulleted list`
  String get forumEditorBulletList {
    return Intl.message(
      'Bulleted list',
      name: 'forumEditorBulletList',
      desc: '',
      args: [],
    );
  }

  /// `Numbered list`
  String get forumEditorNumberedList {
    return Intl.message(
      'Numbered list',
      name: 'forumEditorNumberedList',
      desc: '',
      args: [],
    );
  }

  /// `Clear formatting`
  String get forumEditorClearFormat {
    return Intl.message(
      'Clear formatting',
      name: 'forumEditorClearFormat',
      desc: '',
      args: [],
    );
  }

  /// `HTML source`
  String get forumEditorSource {
    return Intl.message(
      'HTML source',
      name: 'forumEditorSource',
      desc: '',
      args: [],
    );
  }

  /// `Hide keyboard`
  String get forumEditorHideKeyboard {
    return Intl.message(
      'Hide keyboard',
      name: 'forumEditorHideKeyboard',
      desc: '',
      args: [],
    );
  }

  /// `Loading the editor…`
  String get forumEditorLoading {
    return Intl.message(
      'Loading the editor…',
      name: 'forumEditorLoading',
      desc: '',
      args: [],
    );
  }

  /// `The editor could not load, so this post cannot be edited right now`
  String get forumEditorLoadFailed {
    return Intl.message(
      'The editor could not load, so this post cannot be edited right now',
      name: 'forumEditorLoadFailed',
      desc: '',
      args: [],
    );
  }

  /// `A safety check on the content failed, so the save was stopped to avoid damaging the post`
  String get forumEditorUnsafeContent {
    return Intl.message(
      'A safety check on the content failed, so the save was stopped to avoid damaging the post',
      name: 'forumEditorUnsafeContent',
      desc: '',
      args: [],
    );
  }

  /// `This post has attachments and the school's Moodle does not let the app edit it without breaking the attachment marker. Edit it on the website.`
  String get forumEditAttachmentsWebOnly {
    return Intl.message(
      'This post has attachments and the school\'s Moodle does not let the app edit it without breaking the attachment marker. Edit it on the website.',
      name: 'forumEditAttachmentsWebOnly',
      desc: '',
      args: [],
    );
  }

  /// `This post`
  String get forumPostActions {
    return Intl.message(
      'This post',
      name: 'forumPostActions',
      desc: '',
      args: [],
    );
  }

  /// `Delete post`
  String get forumDeletePost {
    return Intl.message(
      'Delete post',
      name: 'forumDeletePost',
      desc: '',
      args: [],
    );
  }

  /// `Delete this post?`
  String get forumDeletePostConfirm {
    return Intl.message(
      'Delete this post?',
      name: 'forumDeletePostConfirm',
      desc: '',
      args: [],
    );
  }

  /// `This is the first post: deleting it removes the whole discussion and every reply. Delete?`
  String get forumDeleteTopicConfirm {
    return Intl.message(
      'This is the first post: deleting it removes the whole discussion and every reply. Delete?',
      name: 'forumDeleteTopicConfirm',
      desc: '',
      args: [],
    );
  }

  /// `Deleted`
  String get forumDeleteDone {
    return Intl.message('Deleted', name: 'forumDeleteDone', desc: '', args: []);
  }

  /// `Delete failed; refresh to check whether the post is still there`
  String get forumDeleteError {
    return Intl.message(
      'Delete failed; refresh to check whether the post is still there',
      name: 'forumDeleteError',
      desc: '',
      args: [],
    );
  }

  /// `This post can no longer be deleted`
  String get forumCannotDeletePost {
    return Intl.message(
      'This post can no longer be deleted',
      name: 'forumCannotDeletePost',
      desc: '',
      args: [],
    );
  }

  /// `This post has replies and cannot be deleted`
  String get forumCannotDeleteHasReplies {
    return Intl.message(
      'This post has replies and cannot be deleted',
      name: 'forumCannotDeleteHasReplies',
      desc: '',
      args: [],
    );
  }

  /// `This post has been rated and cannot be deleted`
  String get forumCannotDeleteRated {
    return Intl.message(
      'This post has been rated and cannot be deleted',
      name: 'forumCannotDeleteRated',
      desc: '',
      args: [],
    );
  }

  /// `You cannot edit this post`
  String get forumErrorNoEditPermission {
    return Intl.message(
      'You cannot edit this post',
      name: 'forumErrorNoEditPermission',
      desc: '',
      args: [],
    );
  }

  /// `More`
  String get titleMore {
    return Intl.message('More', name: 'titleMore', desc: '', args: []);
  }

  /// `About TAT`
  String get groupAboutTat {
    return Intl.message('About TAT', name: 'groupAboutTat', desc: '', args: []);
  }

  /// `All services`
  String get allServices {
    return Intl.message(
      'All services',
      name: 'allServices',
      desc: '',
      args: [],
    );
  }

  /// `Enrollment, course search, evaluation`
  String get curriculumDescription {
    return Intl.message(
      'Enrollment, course search, evaluation',
      name: 'curriculumDescription',
      desc: '',
      args: [],
    );
  }

  /// `Student record, conduct, leaving procedures`
  String get personInfoDescription {
    return Intl.message(
      'Student record, conduct, leaving procedures',
      name: 'personInfoDescription',
      desc: '',
      args: [],
    );
  }

  /// `Dormitory, room booking, counselling`
  String get campusLifeDescription {
    return Intl.message(
      'Dormitory, room booking, counselling',
      name: 'campusLifeDescription',
      desc: '',
      args: [],
    );
  }

  /// `Scholarships, fee waivers, work-study`
  String get financialSupportDescription {
    return Intl.message(
      'Scholarships, fee waivers, work-study',
      name: 'financialSupportDescription',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get languageSetting {
    return Intl.message(
      'Language',
      name: 'languageSetting',
      desc: '',
      args: [],
    );
  }

  /// `Traditional Chinese`
  String get languageZhTW {
    return Intl.message(
      'Traditional Chinese',
      name: 'languageZhTW',
      desc: '',
      args: [],
    );
  }

  /// `English`
  String get languageEn {
    return Intl.message('English', name: 'languageEn', desc: '', args: []);
  }

  /// `This information comes from the university's systems. To correct it, go through campus services.`
  String get profileReadOnlyNote {
    return Intl.message(
      'This information comes from the university\'s systems. To correct it, go through campus services.',
      name: 'profileReadOnlyNote',
      desc: '',
      args: [],
    );
  }

  /// `Open student record`
  String get goToStudentRecord {
    return Intl.message(
      'Open student record',
      name: 'goToStudentRecord',
      desc: '',
      args: [],
    );
  }

  /// `Search services`
  String get searchService {
    return Intl.message(
      'Search services',
      name: 'searchService',
      desc: '',
      args: [],
    );
  }

  /// `%s items`
  String get itemCount {
    return Intl.message('%s items', name: 'itemCount', desc: '', args: []);
  }

  /// `No services found`
  String get subSystemSearchEmpty {
    return Intl.message(
      'No services found',
      name: 'subSystemSearchEmpty',
      desc: '',
      args: [],
    );
  }

  /// `GPA`
  String get gpaLabel {
    return Intl.message('GPA', name: 'gpaLabel', desc: '', args: []);
  }

  /// `Failed`
  String get scoreFailed {
    return Intl.message('Failed', name: 'scoreFailed', desc: '', args: []);
  }

  /// `Passed`
  String get scorePassed {
    return Intl.message('Passed', name: 'scorePassed', desc: '', args: []);
  }

  /// `%s courses`
  String get courseCount {
    return Intl.message('%s courses', name: 'courseCount', desc: '', args: []);
  }

  /// `%s credits`
  String get creditCount {
    return Intl.message('%s credits', name: 'creditCount', desc: '', args: []);
  }

  /// `Assignment and exam scores during the term`
  String get moodleCourseGradesSubtitle {
    return Intl.message(
      'Assignment and exam scores during the term',
      name: 'moodleCourseGradesSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Copy`
  String get copyAction {
    return Intl.message('Copy', name: 'copyAction', desc: '', args: []);
  }

  /// `Class / lab`
  String get courseAndPracticalTimes {
    return Intl.message(
      'Class / lab',
      name: 'courseAndPracticalTimes',
      desc: '',
      args: [],
    );
  }

  /// `%s / %s hr`
  String get hoursValue {
    return Intl.message('%s / %s hr', name: 'hoursValue', desc: '', args: []);
  }

  /// `Enrolled`
  String get enrolledCount {
    return Intl.message('Enrolled', name: 'enrolledCount', desc: '', args: []);
  }

  /// `%s (%s / %s)`
  String get enrolledCountValue {
    return Intl.message(
      '%s (%s / %s)',
      name: 'enrolledCountValue',
      desc: '',
      args: [],
    );
  }

  /// `Limit %s · NTUST %s · Cross-campus %s`
  String get enrollmentLimitSummary {
    return Intl.message(
      'Limit %s · NTUST %s · Cross-campus %s',
      name: 'enrollmentLimitSummary',
      desc: '',
      args: [],
    );
  }

  /// `Enrolled students`
  String get enrolledStudents {
    return Intl.message(
      'Enrolled students',
      name: 'enrolledStudents',
      desc: '',
      args: [],
    );
  }

  /// `%s people`
  String get peopleCount {
    return Intl.message('%s people', name: 'peopleCount', desc: '', args: []);
  }

  /// `Textbooks and references`
  String get courseTextbookAndRefbook {
    return Intl.message(
      'Textbooks and references',
      name: 'courseTextbookAndRefbook',
      desc: '',
      args: [],
    );
  }

  /// `Search by name or class`
  String get searchStudent {
    return Intl.message(
      'Search by name or class',
      name: 'searchStudent',
      desc: '',
      args: [],
    );
  }

  /// `By continuing you agree to the`
  String get continueMeansAgree {
    return Intl.message(
      'By continuing you agree to the',
      name: 'continueMeansAgree',
      desc: '',
      args: [],
    );
  }

  /// `B11234567`
  String get accountHint {
    return Intl.message('B11234567', name: 'accountHint', desc: '', args: []);
  }

  /// `Log out?`
  String get logoutConfirmTitle {
    return Intl.message(
      'Log out?',
      name: 'logoutConfirmTitle',
      desc: '',
      args: [],
    );
  }

  /// `This clears all data, including the account and password saved on this device and the cached timetable.`
  String get logoutConfirmDesc {
    return Intl.message(
      'This clears all data, including the account and password saved on this device and the cached timetable.',
      name: 'logoutConfirmDesc',
      desc: '',
      args: [],
    );
  }

  /// `The NTUST system rejected the saved account and password. If you changed it recently, update it and try again.`
  String get credentialRejectedDesc {
    return Intl.message(
      'The NTUST system rejected the saved account and password. If you changed it recently, update it and try again.',
      name: 'credentialRejectedDesc',
      desc: '',
      args: [],
    );
  }

  /// `Exchange student enrollment`
  String get activitiesDescription {
    return Intl.message(
      'Exchange student enrollment',
      name: 'activitiesDescription',
      desc: '',
      args: [],
    );
  }

  /// `Licensed software, campus documents`
  String get resourcesDescription {
    return Intl.message(
      'Licensed software, campus documents',
      name: 'resourcesDescription',
      desc: '',
      args: [],
    );
  }

  /// `Contact`
  String get contactInfo {
    return Intl.message('Contact', name: 'contactInfo', desc: '', args: []);
  }

  /// `Campus email`
  String get campusEmail {
    return Intl.message(
      'Campus email',
      name: 'campusEmail',
      desc: '',
      args: [],
    );
  }

  /// `More fields`
  String get otherFields {
    return Intl.message('More fields', name: 'otherFields', desc: '', args: []);
  }

  /// `No semester selected, the calendar was not updated`
  String get calendarNoSemesterSelected {
    return Intl.message(
      'No semester selected, the calendar was not updated',
      name: 'calendarNoSemesterSelected',
      desc: '',
      args: [],
    );
  }

  /// `%s courses · %s credits`
  String get courseTableSummary {
    return Intl.message(
      '%s courses · %s credits',
      name: 'courseTableSummary',
      desc: '',
      args: [],
    );
  }

  /// `Search file name`
  String get searchFileName {
    return Intl.message(
      'Search file name',
      name: 'searchFileName',
      desc: '',
      args: [],
    );
  }

  /// `No files match that name`
  String get fileSearchNoResult {
    return Intl.message(
      'No files match that name',
      name: 'fileSearchNoResult',
      desc: '',
      args: [],
    );
  }

  /// `%s file(s) · %s week(s) with content`
  String get fileStatsWeekly {
    return Intl.message(
      '%s file(s) · %s week(s) with content',
      name: 'fileStatsWeekly',
      desc: '',
      args: [],
    );
  }

  /// `%s file(s) · %s topic(s)`
  String get fileStatsTopic {
    return Intl.message(
      '%s file(s) · %s topic(s)',
      name: 'fileStatsTopic',
      desc: '',
      args: [],
    );
  }

  /// `This week`
  String get thisWeek {
    return Intl.message('This week', name: 'thisWeek', desc: '', args: []);
  }

  /// `Weeks with content`
  String get weeksWithFiles {
    return Intl.message(
      'Weeks with content',
      name: 'weeksWithFiles',
      desc: '',
      args: [],
    );
  }

  /// `Other weeks with content`
  String get otherWeeksWithFiles {
    return Intl.message(
      'Other weeks with content',
      name: 'otherWeeksWithFiles',
      desc: '',
      args: [],
    );
  }

  /// `Show the %s empty week(s)`
  String get showEmptyWeeks {
    return Intl.message(
      'Show the %s empty week(s)',
      name: 'showEmptyWeeks',
      desc: '',
      args: [],
    );
  }

  /// `Hide the empty weeks`
  String get hideEmptyWeeks {
    return Intl.message(
      'Hide the empty weeks',
      name: 'hideEmptyWeeks',
      desc: '',
      args: [],
    );
  }

  /// `Show %s more item(s)`
  String get showRemainingFiles {
    return Intl.message(
      'Show %s more item(s)',
      name: 'showRemainingFiles',
      desc: '',
      args: [],
    );
  }

  /// `Topics`
  String get topic {
    return Intl.message('Topics', name: 'topic', desc: '', args: []);
  }

  /// `%s add-drop draft`
  String get simulationDraftLabel {
    return Intl.message(
      '%s add-drop draft',
      name: 'simulationDraftLabel',
      desc: '',
      args: [],
    );
  }

  /// `Draft only, your real table is untouched`
  String get simulationSubtitle {
    return Intl.message(
      'Draft only, your real table is untouched',
      name: 'simulationSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `%s clashes: %s`
  String get simulationConflictBanner {
    return Intl.message(
      '%s clashes: %s',
      name: 'simulationConflictBanner',
      desc: '',
      args: [],
    );
  }

  /// `Draft: %s courses, %s credits`
  String get simulationDraftSummary {
    return Intl.message(
      'Draft: %s courses, %s credits',
      name: 'simulationDraftSummary',
      desc: '',
      args: [],
    );
  }

  /// `%s credits including your real table`
  String get simulationTotalSummary {
    return Intl.message(
      '%s credits including your real table',
      name: 'simulationTotalSummary',
      desc: '',
      args: [],
    );
  }

  /// `No clashes`
  String get simulationNoConflict {
    return Intl.message(
      'No clashes',
      name: 'simulationNoConflict',
      desc: '',
      args: [],
    );
  }

  /// `No courses yet. Tap Search courses below to start planning.`
  String get simulationEmptyHint {
    return Intl.message(
      'No courses yet. Tap Search courses below to start planning.',
      name: 'simulationEmptyHint',
      desc: '',
      args: [],
    );
  }

  /// `New draft table`
  String get simulationNew {
    return Intl.message(
      'New draft table',
      name: 'simulationNew',
      desc: '',
      args: [],
    );
  }

  /// `Selected courses`
  String get simulationDraftListTitle {
    return Intl.message(
      'Selected courses',
      name: 'simulationDraftListTitle',
      desc: '',
      args: [],
    );
  }

  /// `Remove from draft`
  String get simulationRemoveCourse {
    return Intl.message(
      'Remove from draft',
      name: 'simulationRemoveCourse',
      desc: '',
      args: [],
    );
  }

  /// `Search courses`
  String get courseSearchTitle {
    return Intl.message(
      'Search courses',
      name: 'courseSearchTitle',
      desc: '',
      args: [],
    );
  }

  /// `Hide clashes`
  String get courseSearchHideConflict {
    return Intl.message(
      'Hide clashes',
      name: 'courseSearchHideConflict',
      desc: '',
      args: [],
    );
  }

  /// `%s courses`
  String get courseSearchResultSummary {
    return Intl.message(
      '%s courses',
      name: 'courseSearchResultSummary',
      desc: '',
      args: [],
    );
  }

  /// `%s clash with your table`
  String get courseSearchConflictSummary {
    return Intl.message(
      '%s clash with your table',
      name: 'courseSearchConflictSummary',
      desc: '',
      args: [],
    );
  }

  /// `Clashes with %s (%s)`
  String get courseSearchConflictWith {
    return Intl.message(
      'Clashes with %s (%s)',
      name: 'courseSearchConflictWith',
      desc: '',
      args: [],
    );
  }

  /// `Add to draft`
  String get courseSearchAdd {
    return Intl.message(
      'Add to draft',
      name: 'courseSearchAdd',
      desc: '',
      args: [],
    );
  }

  /// `%s clashes`
  String get simulationConflictCount {
    return Intl.message(
      '%s clashes',
      name: 'simulationConflictCount',
      desc: '',
      args: [],
    );
  }

  /// `Filter`
  String get courseSearchFilter {
    return Intl.message(
      'Filter',
      name: 'courseSearchFilter',
      desc: '',
      args: [],
    );
  }

  /// `Filters`
  String get courseSearchFilterTitle {
    return Intl.message(
      'Filters',
      name: 'courseSearchFilterTitle',
      desc: '',
      args: [],
    );
  }

  /// `Any program`
  String get courseSearchLevelAny {
    return Intl.message(
      'Any program',
      name: 'courseSearchLevelAny',
      desc: '',
      args: [],
    );
  }

  /// `Undergraduate`
  String get courseSearchLevelUnder {
    return Intl.message(
      'Undergraduate',
      name: 'courseSearchLevelUnder',
      desc: '',
      args: [],
    );
  }

  /// `Graduate`
  String get courseSearchLevelMaster {
    return Intl.message(
      'Graduate',
      name: 'courseSearchLevelMaster',
      desc: '',
      args: [],
    );
  }

  /// `Taught in English`
  String get courseSearchForeignLanguage {
    return Intl.message(
      'Taught in English',
      name: 'courseSearchForeignLanguage',
      desc: '',
      args: [],
    );
  }

  /// `General education`
  String get courseSearchGeneral {
    return Intl.message(
      'General education',
      name: 'courseSearchGeneral',
      desc: '',
      args: [],
    );
  }

  /// `Intensive`
  String get courseSearchIntensive {
    return Intl.message(
      'Intensive',
      name: 'courseSearchIntensive',
      desc: '',
      args: [],
    );
  }

  /// `Exclude NTU system`
  String get courseSearchNtustOnly {
    return Intl.message(
      'Exclude NTU system',
      name: 'courseSearchNtustOnly',
      desc: '',
      args: [],
    );
  }

  /// `GE dimension`
  String get courseSearchDimension {
    return Intl.message(
      'GE dimension',
      name: 'courseSearchDimension',
      desc: '',
      args: [],
    );
  }

  /// `Any dimension`
  String get courseSearchDimensionAny {
    return Intl.message(
      'Any dimension',
      name: 'courseSearchDimensionAny',
      desc: '',
      args: [],
    );
  }

  /// `Periods`
  String get courseSearchSlot {
    return Intl.message(
      'Periods',
      name: 'courseSearchSlot',
      desc: '',
      args: [],
    );
  }

  /// `Only shows courses that fit entirely in the selected periods. No selection means no filter.`
  String get courseSearchSlotHint {
    return Intl.message(
      'Only shows courses that fit entirely in the selected periods. No selection means no filter.',
      name: 'courseSearchSlotHint',
      desc: '',
      args: [],
    );
  }

  /// `Clear filters`
  String get courseSearchReset {
    return Intl.message(
      'Clear filters',
      name: 'courseSearchReset',
      desc: '',
      args: [],
    );
  }

  /// `Required`
  String get courseRequired {
    return Intl.message('Required', name: 'courseRequired', desc: '', args: []);
  }

  /// `Elective`
  String get courseElective {
    return Intl.message('Elective', name: 'courseElective', desc: '', args: []);
  }

  /// `Program`
  String get courseSearchLevel {
    return Intl.message(
      'Program',
      name: 'courseSearchLevel',
      desc: '',
      args: [],
    );
  }

  /// `Options`
  String get courseSearchOptions {
    return Intl.message(
      'Options',
      name: 'courseSearchOptions',
      desc: '',
      args: [],
    );
  }

  /// `Humanities and Thinking`
  String get courseDimensionA {
    return Intl.message(
      'Humanities and Thinking',
      name: 'courseDimensionA',
      desc: '',
      args: [],
    );
  }

  /// `Contemporary Civilization`
  String get courseDimensionB {
    return Intl.message(
      'Contemporary Civilization',
      name: 'courseDimensionB',
      desc: '',
      args: [],
    );
  }

  /// `Aesthetics and Life Wisdom`
  String get courseDimensionC {
    return Intl.message(
      'Aesthetics and Life Wisdom',
      name: 'courseDimensionC',
      desc: '',
      args: [],
    );
  }

  /// `Social Cultures and History`
  String get courseDimensionD {
    return Intl.message(
      'Social Cultures and History',
      name: 'courseDimensionD',
      desc: '',
      args: [],
    );
  }

  /// `Community and Relationships`
  String get courseDimensionE {
    return Intl.message(
      'Community and Relationships',
      name: 'courseDimensionE',
      desc: '',
      args: [],
    );
  }

  /// `Nature and Life Science`
  String get courseDimensionF {
    return Intl.message(
      'Nature and Life Science',
      name: 'courseDimensionF',
      desc: '',
      args: [],
    );
  }

  /// `Choose a table`
  String get tableSwitcherTitle {
    return Intl.message(
      'Choose a table',
      name: 'tableSwitcherTitle',
      desc: '',
      args: [],
    );
  }

  /// `My tables`
  String get tableSwitcherMine {
    return Intl.message(
      'My tables',
      name: 'tableSwitcherMine',
      desc: '',
      args: [],
    );
  }

  /// `Shared with me`
  String get tableSwitcherShared {
    return Intl.message(
      'Shared with me',
      name: 'tableSwitcherShared',
      desc: '',
      args: [],
    );
  }

  /// `Draft tables`
  String get tableSwitcherDrafts {
    return Intl.message(
      'Draft tables',
      name: 'tableSwitcherDrafts',
      desc: '',
      args: [],
    );
  }

  /// `Manage tables`
  String get manageTablesTitle {
    return Intl.message(
      'Manage tables',
      name: 'manageTablesTitle',
      desc: '',
      args: [],
    );
  }

  /// `My tables, downloaded`
  String get manageTablesMine {
    return Intl.message(
      'My tables, downloaded',
      name: 'manageTablesMine',
      desc: '',
      args: [],
    );
  }

  /// `Each semester you open is saved here automatically.`
  String get manageTablesMineHint {
    return Intl.message(
      'Each semester you open is saved here automatically.',
      name: 'manageTablesMineHint',
      desc: '',
      args: [],
    );
  }

  /// `Scanned from someone else`
  String get manageTablesShared {
    return Intl.message(
      'Scanned from someone else',
      name: 'manageTablesShared',
      desc: '',
      args: [],
    );
  }

  /// `A scanned table is a snapshot; later add-drops by that person will not sync.`
  String get manageTablesSharedHint {
    return Intl.message(
      'A scanned table is a snapshot; later add-drops by that person will not sync.',
      name: 'manageTablesSharedHint',
      desc: '',
      args: [],
    );
  }

  /// `Simulations · your drafts`
  String get manageTablesDrafts {
    return Intl.message(
      'Simulations · your drafts',
      name: 'manageTablesDrafts',
      desc: '',
      args: [],
    );
  }

  /// `Simulations are just for planning; they never touch your real timetable.`
  String get manageTablesDraftsHint {
    return Intl.message(
      'Simulations are just for planning; they never touch your real timetable.',
      name: 'manageTablesDraftsHint',
      desc: '',
      args: [],
    );
  }

  /// `Current`
  String get manageTablesCurrent {
    return Intl.message(
      'Current',
      name: 'manageTablesCurrent',
      desc: '',
      args: [],
    );
  }

  /// `Scan a table`
  String get scanTableTitle {
    return Intl.message(
      'Scan a table',
      name: 'scanTableTitle',
      desc: '',
      args: [],
    );
  }

  /// `Imported %s`
  String get importedOn {
    return Intl.message('Imported %s', name: 'importedOn', desc: '', args: []);
  }

  /// `Switch table`
  String get switchTable {
    return Intl.message(
      'Switch table',
      name: 'switchTable',
      desc: '',
      args: [],
    );
  }

  /// `Mine, shared, drafts`
  String get switchTableHint {
    return Intl.message(
      'Mine, shared, drafts',
      name: 'switchTableHint',
      desc: '',
      args: [],
    );
  }

  /// `Share table`
  String get shareTableTitle {
    return Intl.message(
      'Share table',
      name: 'shareTableTitle',
      desc: '',
      args: [],
    );
  }

  /// `Have them use Scan a table`
  String get shareTableHint {
    return Intl.message(
      'Have them use Scan a table',
      name: 'shareTableHint',
      desc: '',
      args: [],
    );
  }

  /// `Save as image`
  String get shareTableSaveImage {
    return Intl.message(
      'Save as image',
      name: 'shareTableSaveImage',
      desc: '',
      args: [],
    );
  }

  /// `The QR carries only the student ID, semester and course codes. Nothing is uploaded, and it contains no grades or assignments. Their app fills in course names and rooms itself.`
  String get shareTableNote {
    return Intl.message(
      'The QR carries only the student ID, semester and course codes. Nothing is uploaded, and it contains no grades or assignments. Their app fills in course names and rooms itself.',
      name: 'shareTableNote',
      desc: '',
      args: [],
    );
  }

  /// `Copy code`
  String get shareTableCopyCode {
    return Intl.message(
      'Copy code',
      name: 'shareTableCopyCode',
      desc: '',
      args: [],
    );
  }

  /// `Code copied`
  String get shareTableCodeCopied {
    return Intl.message(
      'Code copied',
      name: 'shareTableCodeCopied',
      desc: '',
      args: [],
    );
  }

  /// `Export image`
  String get exportImage {
    return Intl.message(
      'Export image',
      name: 'exportImage',
      desc: '',
      args: [],
    );
  }

  /// `PNG, whole week`
  String get exportImageHint {
    return Intl.message(
      'PNG, whole week',
      name: 'exportImageHint',
      desc: '',
      args: [],
    );
  }

  /// `Line up their QR inside the frame`
  String get scanTableHint {
    return Intl.message(
      'Line up their QR inside the frame',
      name: 'scanTableHint',
      desc: '',
      args: [],
    );
  }

  /// `You will get to confirm whose table it is before it is imported.`
  String get scanTableNote {
    return Intl.message(
      'You will get to confirm whose table it is before it is imported.',
      name: 'scanTableNote',
      desc: '',
      args: [],
    );
  }

  /// `Torch`
  String get scanTableTorch {
    return Intl.message('Torch', name: 'scanTableTorch', desc: '', args: []);
  }

  /// `From photos`
  String get scanTableGallery {
    return Intl.message(
      'From photos',
      name: 'scanTableGallery',
      desc: '',
      args: [],
    );
  }

  /// `Paste code`
  String get scanTablePaste {
    return Intl.message(
      'Paste code',
      name: 'scanTablePaste',
      desc: '',
      args: [],
    );
  }

  /// `Paste the code they sent you`
  String get scanTablePasteHint {
    return Intl.message(
      'Paste the code they sent you',
      name: 'scanTablePasteHint',
      desc: '',
      args: [],
    );
  }

  /// `That is not a TAT table code`
  String get scanTableInvalid {
    return Intl.message(
      'That is not a TAT table code',
      name: 'scanTableInvalid',
      desc: '',
      args: [],
    );
  }

  /// `No camera access. Use From photos or Paste code instead.`
  String get scanTablePermission {
    return Intl.message(
      'No camera access. Use From photos or Paste code instead.',
      name: 'scanTablePermission',
      desc: '',
      args: [],
    );
  }

  /// `Import this table?`
  String get importConfirmTitle {
    return Intl.message(
      'Import this table?',
      name: 'importConfirmTitle',
      desc: '',
      args: [],
    );
  }

  /// `Import and open`
  String get importConfirmOpen {
    return Intl.message(
      'Import and open',
      name: 'importConfirmOpen',
      desc: '',
      args: [],
    );
  }

  /// `and %s more`
  String get importMoreCourses {
    return Intl.message(
      'and %s more',
      name: 'importMoreCourses',
      desc: '',
      args: [],
    );
  }

  /// `Restoring course names (%s/%s)`
  String get importRestoring {
    return Intl.message(
      'Restoring course names (%s/%s)',
      name: 'importRestoring',
      desc: '',
      args: [],
    );
  }

  /// `Imported %s's table`
  String get importDone {
    return Intl.message(
      'Imported %s\'s table',
      name: 'importDone',
      desc: '',
      args: [],
    );
  }

  /// `Shared`
  String get sharedTableBadge {
    return Intl.message('Shared', name: 'sharedTableBadge', desc: '', args: []);
  }

  /// `Department`
  String get courseSearchDepartment {
    return Intl.message(
      'Department',
      name: 'courseSearchDepartment',
      desc: '',
      args: [],
    );
  }

  /// `Any department`
  String get courseSearchDepartmentAny {
    return Intl.message(
      'Any department',
      name: 'courseSearchDepartmentAny',
      desc: '',
      args: [],
    );
  }

  /// `College`
  String get courseSearchCollege {
    return Intl.message(
      'College',
      name: 'courseSearchCollege',
      desc: '',
      args: [],
    );
  }

  /// `Apply`
  String get courseSearchFilterApply {
    return Intl.message(
      'Apply',
      name: 'courseSearchFilterApply',
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
