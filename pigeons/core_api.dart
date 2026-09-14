// 原生版（ios_native/）與 Dart 核心之間的邊界定義。
//
// 改完這個檔案要重新產生：
//   puro dart run pigeon --input pigeons/core_api.dart
//
// **角色是反過來的。** Pigeon 的預設情境是「Flutter App 呼叫原生」，所以
// `@HostApi` 指的是原生端實作、Dart 呼叫。這個專案把 Dart 當成函式庫在用，
// 兩個方向都要，對應關係是：
//
//   @FlutterApi  Dart 實作、Swift 呼叫  → 取資料（課表、成績…）
//   @HostApi     Swift 實作、Dart 呼叫  → TaskUiDelegate / InteractiveLoginGateway
//
// Pigeon 不支援泛型，所以 `Result<T>` 的每一個 T 都要有自己的一組三態類別。
// 好消息是它支援「空的 sealed 父類別 + 有欄位的子類別」，這和
// lib/src/repository/result.dart 的形狀幾乎一對一。

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/generated/core_api.g.dart',
  dartOptions: DartOptions(),
  swiftOut: 'ios_native/TATNative/Core/Generated/CoreApi.g.swift',
  swiftOptions: SwiftOptions(),
  dartPackageName: 'flutter_app',
))

/// 對應 `lib/src/repository/result.dart` 的 `FailureReason`。
///
/// 決定畫面要畫什麼、以及要不要給「重試」。`retryable` 不放進邊界：
/// 那是各原因的固有性質，Swift 端自己用 switch 判斷就好，
/// 多送一個欄位只會多一個兩邊可能不同步的地方。
sealed class CoreFailure {}

/// 探測不到網路。
class CoreFailureOffline extends CoreFailure {}

/// 沒有登入。**不可重試**：畫登入按鈕而不是重試。
class CoreFailureNotSignedIn extends CoreFailure {}

/// 有憑證但登入失敗。[detail] 是站台自己回的訊息。
class CoreFailureLoginFailed extends CoreFailure {
  String? detail;
}

/// 登入沒問題，取資料這一步失敗。
class CoreFailureFetchFailed extends CoreFailure {
  String? detail;
}

/// 這門課在 Moodle 上找不到對應。**不可重試**。
class CoreFailureUnsupportedCourse extends CoreFailure {}

/// 課表的一格。
///
/// Dart 端是 `Map<Day, Map<SectionNumber, CourseInfoJson>>`，
/// 但 enum 當 map key 過不了邊界，而且 Swift 端本來就要自己組格子，
/// 所以攤平成 cell 清單。
class CourseCell {
  late String day;
  late String section;
  late String courseId;
  late String courseName;
  String? classroom;
  String? teacher;
}

class CourseTable {
  late String studentId;
  late String semester;
  late List<CourseCell> cells;
}

/// `Result<CourseTableJson>` 的三態。
sealed class CourseTableResult {}

/// 這次真的抓到新資料。
class CourseTableOk extends CourseTableResult {
  late CourseTable data;
}

/// 沒抓到，但快取讀得回來。**畫面必須標示這是舊資料。**
class CourseTableStale extends CourseTableResult {
  late CourseTable data;
  late CoreFailure reason;
}

/// 沒抓到也沒有快取。
class CourseTableFailed extends CourseTableResult {
  late CoreFailure reason;
}

/// 成績的摘要。E3 的判準用——證明「Swift 的 WebView 抓 HTML、Dart 解析」
/// 這條路走得通就夠，完整的成績模型等真的做成績頁時再定。
class ScoreSummary {
  late int semesterCount;
  late int itemCount;
  /// 最近一個學期，像 `"115-1"`。
  String? latestSemester;
}

/// `Result<ScoreRankJson>` 的三態。
sealed class ScoreResult {}

class ScoreOk extends ScoreResult {
  late ScoreSummary data;
}

class ScoreStale extends ScoreResult {
  late ScoreSummary data;
  late CoreFailure reason;
}

class ScoreFailed extends ScoreResult {
  late CoreFailure reason;
}

/// 課表畫面上的一欄（星期）。沒有課的週末與「其它」已經收掉。
class CourseGridDay {
  /// `Day` 的索引，格子用它對位。
  late int index;
  late String label;
}

/// 課表畫面上的一列（節次）。沒有課的中午與晚上幾節已經收掉。
class CourseGridSection {
  /// `SectionNumber` 的索引。
  late int index;
  late String label;

  /// 「08:10 - 09:00」。
  late String time;
}

class CourseGridCell {
  late int day;
  late int section;
  late String courseId;
  late String name;
  String? classroom;
  String? teacher;

  /// 選課系統裡的課；false 是使用者自己加的。
  late bool selected;

  /// 課號在這張課表裡的順序。同一門課的格子同一個值，顏色由原生端依它挑。
  late int order;
}

/// 課表頁要畫的東西。哪幾天、哪幾節要顯示是 Dart 的判斷（`CourseTableControl`）。
class CourseGrid {
  late String studentId;

  /// 「115-1」。
  late String semester;
  late int courseCount;
  late int credits;
  late List<CourseGridDay> days;
  late List<CourseGridSection> sections;
  late List<CourseGridCell> cells;
}

/// 「我的課表」的一份：自己下載過的某個學期。
class MyTable {
  late String studentId;
  late String semester;
  late int courseCount;
  late int credits;
}

/// 掃進來的他人課表。
class SharedTableInfo {
  late String id;

  /// 對方的學號。
  late String label;
  late String semester;
  late int courseCount;

  /// 匯入時間（epoch 毫秒）。
  late int savedAt;
}

/// 分享課表需要的東西，由 `CourseTableShareCodec` 產生。
class TableShare {
  /// QR 的內容，含網址前綴。
  late String qr;

  /// 「複製分享碼」複製的那一段。
  late String code;
  late String studentId;
  late String semester;
  late int courseCount;
  late int credits;
}

/// 分享碼解開之後、匯入之前的預覽。
class SharePreview {
  late String studentId;
  late String semester;
  late int courseCount;

  /// 前幾門課。課名與教室由 [TatCourseTableApi.lookupPreview] 補。
  late List<SharePreviewCourse> courses;
}

class SharePreviewCourse {
  late String id;

  /// 「一 2·3　三 4」，一律來自分享碼本身。
  late String slots;
}

/// 查一門課的結果。查不到時 [name] 是 null。
class SharedCourseInfo {
  late String id;
  String? name;
  String? classroom;
}

/// 系所或學院。名字已經依介面語言挑好。
class CourseSearchOption {
  late String no;
  late String name;
}

/// 通識向度，對應 `CourseDimension`。
enum GeDimension { a, b, c, d, e, f }

/// 學制，對應 `CourseProgramLevel`。
enum ProgramLevel { all, underGraduate, master }

/// 搜尋條件，對應 `CourseQueryFilter`。[keyword] 先當課號查，查不到再當課名。
class CourseFilter {
  late String keyword;
  CourseSearchOption? department;
  GeDimension? dimension;
  late ProgramLevel level;
  late bool foreignLanguageOnly;
  late bool generalOnly;
  late bool intensiveOnly;
  late bool ntustOnly;
}

/// 課表上的一格：`Day` 與 `SectionNumber` 的索引。
class TimeSlot {
  late int day;
  late int section;
}

class CourseSearchStart {
  /// 目前課表的學期，只查這一學期的課。
  late String semester;

  /// 課表上最多課的系所代碼，一進來先查它。
  String? keyword;

  /// 節次篩選的欄與列。
  late List<CourseGridDay> days;
  late List<CourseGridSection> sections;
}

enum CourseRequirement { compulsory, elective }

class SearchConflict {
  late String courseName;

  /// 「三 9、四 3·4」。
  late String slots;
}

class SearchCourse {
  late String id;
  late String name;
  String? credits;
  CourseRequirement? requirement;
  String? teacher;

  /// 「三 8　四 3·4」。
  String? slots;
  String? classroom;
  late List<SearchConflict> conflicts;

  /// 已經在課表上。
  late bool added;
}

class CourseSearchResults {
  /// 查到的門數，篩掉之前。
  late int total;

  /// 其中與課表衝堂的門數。
  late int clashes;
  late List<SearchCourse> courses;
}

class CourseSearchChange {
  /// false 代表衝堂、沒有加進去。
  late bool applied;
  CourseGrid? grid;
}

enum ScoreState { ok, notSignedIn, failed }

class ScoreCourse {
  late String courseId;
  late String name;
  late int credits;

  /// 通識向度。
  String? dimension;

  /// 分數欄的字：沒有等第時退回備註，兩者皆無是「尚未評分」。
  late String label;
  late bool failed;
}

class ScoreSemester {
  /// 「115-1」。
  late String semester;

  /// 一門有效成績都沒有時是 null。
  String? gpa;

  /// 及格課程的學分。
  late int credits;
  late int failed;
  late List<ScoreCourse> courses;
}

class ScoreReport {
  late ScoreState state;

  /// 新到舊。抓不到新資料時是手上那一份。
  late List<ScoreSemester> semesters;
}

class MoodleGradeCourse {
  late String courseId;
  late String name;

  /// 伺服器格式化好的字串，原樣顯示。
  late String grade;
}

class MoodleGrades {
  /// 「115-1」。
  String? semester;
  late List<MoodleGradeCourse> courses;

  /// 失敗時的訊息。
  String? error;

  /// 沒抓到新的、顯示的是快取時的原因。
  String? notice;
  late bool signedIn;
}

enum GradeRowKind { item, category, course }

class MoodleGradeRow {
  late int id;
  late String title;
  late GradeRowKind kind;

  /// 百分比、權量、全距，有回饋時最後補「回饋」。
  String? meta;

  /// null 代表尚未評分。
  String? grade;

  /// 老師回饋，HTML。
  String? feedback;
}

class MoodleCourseScore {
  late List<MoodleGradeRow> rows;
  String? error;
  String? notice;
  late bool signedIn;
}

class CalendarDay {
  /// 「2026-09-13」。
  late String date;
  late List<String> events;
}

enum DeadlineKind { overdue, today, thisWeek, later }

class UpcomingEvent {
  late int id;
  late String title;

  /// 課名；站台事件沒有。
  String? course;

  /// 截止時間，epoch 毫秒。
  late int due;

  /// Moodle 模組，決定圖示。
  String? module;
}

class UpcomingGroup {
  late DeadlineKind kind;
  late List<UpcomingEvent> events;
}

class UpcomingEvents {
  late List<UpcomingGroup> groups;
  String? error;

  /// 沒抓到新的、顯示的是快取時的原因。
  String? notice;
  late bool signedIn;
}

/// 自家網站的網址換成免登入網址之後的樣子。
class WebLink {
  late String url;

  /// [url] 是免登入網址時原本要開的那一個，鑰匙被拒時退回去開它。
  String? fallbackUrl;
}

class MoodleProfile {
  late String name;

  /// 學號，大寫。
  late String account;
  String? avatarUrl;

  /// 有自訂頭貼。對著預設圖按移除，伺服器會回失敗，所以沒有自訂時不給移除。
  late bool customAvatar;
}

enum ThemeChoice { system, light, dark }

class ProjectContributor {
  late String login;
  String? avatarUrl;
  String? url;
}

class ServiceLink {
  late String name;
  late String url;
}

class ServiceCategory {
  /// NTUST 那一側的不透明代號，`service-1`…`service-6`。
  late String serviceId;
  late List<ServiceLink> services;

  /// 這一類最上面要不要釘「空教室（App 內）」，照 `sub_system_page.dart`。
  late bool pinsClassroom;
}

class ServiceTree {
  late List<ServiceCategory> categories;
  String? error;
  String? notice;
  late bool signedIn;
}

class MoodleNotifyProcessor {
  late String name;
  late String displayName;
}

class MoodleNotifySetting {
  late String key;
  late String name;

  /// 開著的通知方式。
  late List<String> enabled;
}

class MoodleNotifyGroup {
  late String name;
  late List<MoodleNotifySetting> settings;
}

class MoodleSettings {
  /// 分頁：通知方式。
  late List<MoodleNotifyProcessor> processors;
  late List<MoodleNotifyGroup> groups;
}

class ClassroomBuilding {
  late String code;
  late String name;
}

class ClassroomCampus {
  late String code;
  late String name;

  /// 研揚大樓排第一個，其餘照站台的順序。
  late List<ClassroomBuilding> buildings;
}

enum ClassroomLayout { list, day }

enum ClassroomRun { any, twoSections, threeSections, allDay }

class ClassSection {
  late String label;
  late String start;
  late String end;
}

class ClassroomNow {
  /// 「2026-09-13」。
  late String date;
  late int section;
}

class ClassroomSetup {
  late List<ClassroomCampus> campuses;
  String? campusCode;
  String? buildingCode;
  late ClassroomLayout layout;

  /// 現在是哪一天第幾節；最後一節下課之後是明天第一節。
  late ClassroomNow now;

  /// 節次的代號與起訖時刻，與 `sectionTimes` 對齊。
  late List<ClassSection> sections;
  String? error;
  late bool signedIn;
}

class ClassroomSlot {
  late bool free;
  late String course;
  late String teacher;

  /// 站台標了記號、沒有課名：借出。
  late bool booked;
}

class ClassroomRoom {
  late String name;
  late List<ClassroomSlot> slots;

  /// 從查的那一節起連續空幾節，0 代表這一節有人用。
  late int freeSections;
  late bool freeAllDay;

  /// 空到幾點；沒空著是 null。
  String? freeUntil;

  /// 下一個佔用從幾點開始；到放學都空著是 null。
  String? nextBusyAt;
  late bool nextIsBooking;
  String? nextCourse;
}

class ClassroomFloor {
  /// 解不出樓層的教室收在最後一組，這裡是 null。
  int? floor;
  late List<ClassroomRoom> rooms;
}

class ClassroomDay {
  String? error;

  /// 站台這一天一列都沒回：借用系統只排上課日，不是錯誤，也不是全部空著。
  late bool closed;

  /// 抓取時間，epoch 毫秒。
  int? fetchedAt;
  late int roomCount;

  /// 這一節空著的間數，不套連續節數篩選。
  late int freeCount;

  /// 清單檢視：套了篩選、依樓層分組。
  late List<ClassroomFloor> floors;

  /// 一整天檢視：這一節空著的，空得最久的排前面。
  late List<ClassroomRoom> free;

  /// 一整天檢視：這一節有人用的。
  late List<ClassroomRoom> busy;
}

/// querycourse 課程資訊表格的一列。
class CourseInfoFact {
  late String label;
  late String value;
  String? footnote;
}

/// 課程資訊的一段長文。
class CourseInfoProse {
  late String title;
  late String body;
}

/// 評量方式拆得出百分比時的一列。
class CourseGradingRow {
  late String label;

  /// 「30%」。
  late String percent;
}

/// 一門課的詳細資訊，排法照 `course_info_page.dart`：標題、短欄位表格、長文各自成段。
class CourseDetailInfo {
  late String name;

  /// 「課號 · 學年期」。
  String? subtitle;

  /// 必修、學分、全年。
  late List<String> chips;
  late List<CourseInfoFact> facts;

  /// 選課人數，進修課學生那一列。沒有時是 null。
  String? memberCount;
  CourseInfoProse? objective;

  /// 評量方式拆得出百分比時的表格；拆不出來時看 [gradingText]。
  List<CourseGradingRow>? grading;
  String? gradingText;

  /// 收在「其餘欄位」裡的長欄位。
  late List<CourseInfoProse> more;
  String? courseUrl;
}

class CourseDetailResult {
  CourseDetailInfo? info;
  String? error;

  /// 沒抓到新的、顯示的是快取時的原因。
  String? notice;
}

class CourseMember {
  late String name;
  late String studentId;
  String? avatarUrl;
}

class CourseMembers {
  late List<CourseMember> members;
  String? error;
  String? notice;
  late bool signedIn;
}

/// 課程模組的種類，照 `CourseModuleActions.handle` 的分支。
enum CourseModuleKind { resource, folder, forum, assign, quiz, url, page, label, other }

class CourseModuleItem {
  late int id;
  late int instance;
  late CourseModuleKind kind;
  late String name;

  /// resource 的「PDF · 2.4 MB」。
  String? subtitle;

  /// resource 的檔案類型，`FileIconUtils` 的名稱。
  String? fileIcon;

  /// 老師寫的說明；label 的內文就是它。
  String? descriptionHtml;
}

class CourseSectionItem {
  late int id;
  late String title;
  String? summary;
  late List<CourseModuleItem> modules;
}

/// 「檔案」分頁，分組照 `CourseSectionTree`。
class CourseDirectory {
  late bool weekly;

  /// 「12 個檔案 · 5 週有內容」。
  late String stats;

  /// 今天所在的那一週；學期外或主題式課程是 null。
  CourseSectionItem? currentWeek;

  /// 週次：其餘有內容的週；主題式：有內容的主題。
  late List<CourseSectionItem> sections;

  /// 週次才有：一片空白的週。
  late List<CourseSectionItem> emptySections;
  String? error;
  String? notice;
  late bool signedIn;
}

/// 一個可以直接下載的 Moodle 檔案。
class MoodleFileLink {
  late String name;

  /// 已經帶上憑證。
  late String url;
}

class FolderEntry {
  late String name;
  late String path;
  late String subtitle;
}

/// 清單上的一個 Moodle 檔案。
class MoodleFileRow {
  late String name;
  String? subtitle;
  late String fileIcon;

  /// 已經帶上憑證，可以直接下載。
  late String url;
}

/// 資料夾模組的某一層，照 `course_folder_page.dart`：先子資料夾、再檔案。
class CourseFolder {
  late String title;
  late String breadcrumb;
  late List<FolderEntry> folders;
  late List<MoodleFileRow> files;
}

/// page 模組的 HTML 教材。
class CoursePage {
  String? html;

  /// 相對連結的基準，刻意不帶憑證。
  String? baseUrl;
  String? error;
}

enum MoodleLinkKind { download, web, blocked }

/// HTML 裡的一個連結要怎麼開，判斷照 `MoodleHtmlView._onTapUrl`。
class MoodleLinkTarget {
  late MoodleLinkKind kind;
  late String url;
  String? fallbackUrl;
  String? filename;
}

enum FeedKind { announcement, discussion }

/// 公告與討論區清單的一列，照 `ForumDiscussionCard`。
class ForumRow {
  late int discussionId;
  late int forumId;
  late String name;
  late bool pinned;
  late String author;
  String? studentId;

  /// 「12」，同一天的改印時間。
  late String day;
  late bool hasAttachment;

  /// null 代表不畫回覆數：純公告或沒有人回。
  int? replies;
  late FeedKind kind;
  late int indexInGroup;
  late int groupLength;
}

/// 清單的一格：月份標題，或一則討論串。
class FeedEntry {
  String? header;
  ForumRow? row;
}

/// 「公告」分頁：公告區與課程討論區併成一條時間軸，照 `course_announcement_page.dart`。
class CourseFeed {
  late List<FeedEntry> entries;
  late int announcementCount;
  late int discussionCount;

  /// 清單是空的時候畫的那一句。
  late String emptyMessage;
  String? error;
  String? notice;
  late bool signedIn;
}

class ForumDiscussions {
  late List<FeedEntry> entries;
  String? error;
  String? notice;
  late bool signedIn;
}

/// 狀態籤的語意，照 `StatusPillTone`。
enum StatusTone { pending, submitted, draft, attention, graded, overdue }

/// 作業列最左邊那顆圖示，照 `_statusIcon`。
enum AssignRowIcon { unknown, overdue, draft, attention, submitted, graded, noSubmission }

class AssignmentRow {
  late int id;
  late String name;
  late String subtitle;
  late AssignRowIcon icon;

  /// 已評分時的分數，拆成大字與斜線之後的小字。
  String? grade;
  String? gradeSuffix;
  String? statusLabel;
  StatusTone? statusTone;
  late bool stale;

  /// 狀態還在背景抓。
  late bool loading;
}

/// 「作業」分頁，照 `course_assignment_page.dart`。
class AssignmentList {
  late List<AssignmentRow> rows;

  /// 「3 件 · 全部已評分」。
  late String summary;
  String? error;
  String? notice;
  late bool signedIn;
}

/// 一列「標籤：值」。
class FieldRow {
  late String label;
  late String value;
}

/// 一句說明。擋住動作的那一種用警示色。
class NoteRow {
  late String text;
  late bool blocking;
}

/// 作答時限，照 `_timerSection` 與 `AssignSubmitStatusHeader._timerRow`。
class AssignTimer {
  /// 「作答時限」那一列的值。
  late String limit;

  /// 還沒開始的提醒、算不出剩多久、或時間到了之後的那一句。正在倒數時是 null。
  String? note;

  /// [note] 要不要用警示色。
  late bool alert;

  /// 倒數的終點（Unix 秒，伺服器時鐘）。只有正在倒數時才有。
  int? endsAt;
}

class AssignFeedback {
  String? grade;
  String? gradedAt;
  String? commentsHtml;
  late List<MoodleFileRow> files;
}

/// 作業詳情，排法照 `course_assignment_detail_page.dart`。
class AssignmentDetail {
  late int id;
  late String name;

  late String dueHint;
  late bool dueAlarm;
  String? dueDate;
  late List<FieldRow> deadlineFields;

  /// 繳交狀態那顆籤；狀態還沒抓到或抓不到時是 null。
  String? chipLabel;
  StatusTone? chipTone;
  late bool chipStale;

  /// 繳交狀態抓不到時的原因。
  String? statusError;
  late List<FieldRow> statusFields;
  late List<MoodleFileRow> submittedFiles;
  String? onlineTextHtml;
  late List<NoteRow> statusNotes;
  AssignFeedback? feedback;

  /// 不只一次繳交時才有。
  late List<FieldRow> attempts;

  /// 團隊作業才有。
  late List<NoteRow> teamNotes;
  late bool teamOpenInWeb;
  AssignTimer? timer;

  String? introHtml;

  /// 說明不給看，或是空的時候那一句。
  String? introPlaceholder;
  late bool introHidden;
  late List<MoodleFileRow> introFiles;

  /// 「新增繳交／編輯繳交／開始新的一次繳交」；null 代表這裡不給繳交入口。
  String? entryLabel;
  late bool canSubmitForGrading;
  late List<NoteRow> submitNotes;

  /// 手上的是快取：寫入之前要先重新整理。
  late bool needsFresh;

  late bool canCopyPrevious;
  late bool canRemove;
  late String copyConfirm;
  late String removeConfirm;

  /// 送出評分前要勾選同意的聲明；不需要時是 null。
  String? statementHtml;
  String? notice;

  /// 伺服器時鐘比本機快幾秒，倒數要照伺服器的時間算。
  late int clockSkewSeconds;
}

class AssignmentDetailResult {
  AssignmentDetail? detail;
  String? error;
  late bool signedIn;
}

/// 寫入之後：先依序 toast [messages]，再照 [detail] 重畫。
class AssignWriteResult {
  late List<String> messages;
  AssignmentDetail? detail;
}

class SubmitFile {
  late String name;
  late String subtitle;
  late String fileIcon;

  /// 已經在伺服器上的那一份才有，可以點開確認。
  String? url;
  late bool onServer;

  /// 儲存後會從 Moodle 移除。那一列還在，撤得回來。
  late bool removing;
}

/// 繳交頁的整個畫面，照 `course_assign_submit_page.dart`。每一次操作之後整份重送。
class SubmitState {
  late String name;

  late String dueHint;
  late bool dueAlarm;
  String? dueLine;
  late String chipLabel;
  late StatusTone chipTone;
  AssignTimer? timer;
  String? teamNotice;
  String? attemptLine;
  late String consequence;

  /// 這份作業開了 App 送不出去的繳交外掛，整頁只剩導網頁。
  late bool blocked;

  late bool filesEnabled;
  late List<SubmitFile> files;
  late String pickerHint;
  late bool pickerFull;
  late int remainingFiles;
  NoteRow? filesNote;

  /// 挑檔時可以直接過濾的副檔名；判讀不出來時是空的，挑回來再擋。
  late List<String> fileExtensions;

  late bool textEnabled;
  late bool textEditable;
  late String text;

  /// 現有的線上文字這一次會原樣送回去。
  late bool textKept;
  String? wordCount;
  late bool overWordLimit;

  late bool statementRequired;
  String? statementHtml;

  /// 有草稿階段：聲明在送出評分時才確認，這一頁只給看。
  late bool statementAtSubmit;
  late bool accepted;

  /// 還沒開始計時：動作列只有「開始作答」。
  late bool needsStart;

  /// 站台有沒有開放在 App 內開始計時；沒有時要說清楚，並給一條去網頁的路。
  late bool startAvailable;
  late bool canStart;
  String? blockReason;
  late bool blockIsError;
  late bool canSave;
  late bool savesDraft;

  late bool busy;
  late bool starting;
  late bool hasUnsavedChanges;

  /// 這一次操作要 toast 的話。
  late List<String> messages;
}

class SubmitOutcome {
  late List<String> messages;

  /// 伺服器被寫過了：關掉繳交頁，詳情頁照 [detail] 重畫。
  late bool close;
  AssignmentDetail? detail;
  SubmitState? state;
}

enum TransferPhase { download, upload, posting }

/// 一趟上傳的進度。
class TransferProgress {
  /// 哪一趟：`assign-<id>`、`forum-<id>`、分享課表補課名的 `restore-<id>`，或頭貼的 `avatar`。
  late String key;

  /// 0..1；量不出來時是 null。
  double? progress;
  late String label;
  late TransferPhase phase;
}

/// 開放時間那一行的語意，照 `QuizWindowKind`。
enum QuizWindowTone { always, upcoming, open, closed }

class QuizAttemptRow {
  late String title;
  late String stateLabel;
  late StatusTone tone;
  FieldRow? time;
}

/// 測驗的唯讀資訊，排法照 `course_quiz_detail_page.dart`。作答一律去網頁。
class QuizDetail {
  late String name;
  late String windowHint;
  late QuizWindowTone windowTone;
  late List<FieldRow> windowFields;
  late List<FieldRow> rules;

  /// 「已用 2 / 3 次」；作答紀錄抓不到時是 null。
  String? attemptsChipLabel;
  StatusTone? attemptsChipTone;
  late bool attemptsChipStale;

  String? gradeError;

  /// 「8.00 / 10.00」；還沒有成績時是 null。
  String? bestGrade;
  String? gradeToPass;

  String? attemptsError;
  late List<QuizAttemptRow> attempts;

  String? introHtml;
  String? notice;
}

class QuizDetailResult {
  QuizDetail? detail;
  String? error;
  late bool signedIn;
}

/// 討論串裡的一則貼文，照 `ForumPostBlock`。
class ForumPostItem {
  late int id;

  /// 縮排層級，最多畫三層。
  late int depth;
  late String author;
  late String initial;

  /// 「6月12日 下午3:00 · 已編輯」。
  late String time;

  /// 只有第一篇印標題。
  String? subject;

  /// 被刪掉或是空白的貼文沒有內文，畫 [placeholder]。
  String? messageHtml;
  String? placeholder;
  late bool deleted;
  late List<MoodleFileRow> attachments;
  late bool canReply;
  late bool canEdit;
  late bool canDelete;

  /// 底下已經有回覆：刪除停用並附理由。伺服器那邊還會算私訊回覆，這裡會少算。
  late bool hasReplies;
}

/// 這個討論區能不能附檔、最多幾個、單檔多大。
class ForumAttachRules {
  late bool enabled;
  late int maxFiles;

  /// 「最多 3 個檔案 · 單一檔案上限 10 MB」。
  late String hint;
}

/// 討論串底部那一條要畫什麼。
enum ForumComposerMode { hidden, locked, reply }

/// 討論串頁，照 `course_forum_thread_page.dart`。
class ForumThread {
  late String title;
  late List<ForumPostItem> posts;
  late ForumComposerMode composer;
  late ForumAttachRules attach;

  /// 抓不到回覆時的原因；[posts] 那時只剩清單上那一列當第一篇。
  String? error;
  String? notice;
  late bool signedIn;
}

class AttachmentCheck {
  late List<String> accepted;
  late List<String> messages;
}

class ForumSendResult {
  /// 送出成功：輸入框清空、編輯頁關掉。失敗一律留在原地，字與附件原封不動。
  late bool ok;
  late List<String> messages;
  ForumThread? thread;

  /// 捲到剛送出的那一則。
  int? scrollTo;

  /// 第一篇改過：清單那一列的標題與迴紋針已經不對了。
  late bool listChanged;
}

enum ForumEditorMode { plain, rawSource, rich }

class ForumEditDraft {
  late int postId;
  late bool isTopicPost;
  late ForumEditorMode mode;
  late String subject;

  /// 純文字框預填的字；所見即所得那條路是 null，改看 [editorScript]。
  String? text;

  /// 把貼文 HTML 放進編輯器的那一行 JavaScript。逃脫由核心做。
  String? editorScript;

  /// 純文字框底下那一行說明。
  String? note;
  late List<MoodleFileRow> attachments;
  late ForumAttachRules attach;
}

class ForumEditStart {
  ForumEditDraft? draft;

  /// 不能編輯時要說的那一句。
  String? message;

  /// 編輯窗已經關了：討論串重抓過一次。
  ForumThread? thread;
}

class ForumDeleteResult {
  late List<String> messages;

  /// 刪掉的是第一篇：整串都沒了，回清單。
  late bool closeThread;
  ForumThread? thread;
}

/// 通知中心那一則 TAT 公告（Remote Config）。
class InboxNotice {
  late String title;

  /// Markdown。
  late String content;

  /// 「9月1日」。
  late String date;

  /// 卡片上的純文字摘要。
  late String excerpt;
}

/// 站內通知的類型，決定圖示，照 `NotificationTile.iconFor`。
enum InboxKind { grade, assign, forum, quiz, feedback, lesson, module, system }

class InboxRow {
  late int id;
  late String subject;

  /// 活動名稱；系統通知是「系統通知」。
  late String source;
  late String time;
  late bool unread;
  late InboxKind kind;

  /// 有自家網址可以開；沒有的就地展開 [bodyHtml]。
  late bool openable;
  late String bodyHtml;
}

class InboxSection {
  /// 今天、本週、更早。
  late String title;
  late List<InboxRow> rows;
}

/// 通知中心，照 `AnnouncementCenterController`：TAT 公告與 Moodle 站內通知兩半。
class InboxState {
  /// 新到舊。卡片只畫第一則，其餘在公告頁裡翻。
  late List<InboxNotice> notices;

  /// 第一則在進頁那一刻還沒讀過。
  late bool noticeUnread;
  late List<InboxSection> sections;

  /// 清單是空的時候的標題與說明；在 Moodle 關掉站內通知時說明不一樣。
  String? emptyMessage;
  String? emptyHint;
  String? error;
  String? notice;
  late bool signedIn;

  /// 有未讀，而且不是離線的舊資料。
  late bool canMarkAll;
}

class InboxMarkAll {
  late bool ok;
  late InboxState state;
}

/// 開發者選單裡通知中心的假資料預覽。
class InboxPreviewItem {
  late String title;
  late String subtitle;
}

/// 啟動時要跳的 TAT 公告，照 `RemoteConfigUtils.resolveAnnouncement`。
class LaunchAnnouncement {
  late List<InboxNotice> notices;

  /// 最後一則的「確定」要等幾秒。
  late int countDown;
}

/// App Store 有新版，照 `UpdatePrompt`。
class UpdateOffer {
  late String installedVersion;
  late String storeVersion;
  String? releaseNotes;
  late String storeUrl;
}

/// App 內瀏覽器停在學校登入頁時代填的結果。
enum BrowserLoginOutcome {
  /// 不是登入頁，什麼都沒做。
  notLoginPage,

  /// 已經送出；成功與否看接下來導到哪一頁。
  submitted,

  /// 被驗證碼擋下，要使用者自己來。
  needsHuman,
}

/// 行事曆待辦在 App 內開得起來的那個模組。
class ModuleTarget {
  late String courseId;
  late String courseName;
  late CourseModuleItem module;
}

/// 切換器與管理頁上的一份模擬課表。
class DraftTableInfo {
  late String id;
  late String label;

  /// 「3 門課 · 9 學分 · 2 處衝堂」。
  late String summary;
}

class SimCourse {
  late String id;
  late String name;

  /// 課號在實際課表加草稿裡的順序，顏色由原生端依它挑。
  late int order;
}

/// 模擬課表的一格：實際課表的課、草稿的課，或兩門撞在一起。
class SimCell {
  late int day;
  late int section;
  SimCourse? real;
  SimCourse? draft;

  /// 兩門不同的課搶同一格。
  late bool conflict;
}

class DraftCourseRow {
  late String id;
  late String name;

  /// 「CS3039701 · 3 學分 · 一 3·4」。
  late String supporting;
  late bool clashes;
}

/// 模擬排課頁，照 `simulation_page.dart`。
class SimulationState {
  late String id;
  late String label;

  /// 「3 處衝堂 · 三 3、四 6」；沒有衝堂時是 null。
  String? conflictBanner;
  late List<CourseGridDay> days;
  late List<CourseGridSection> sections;
  late List<SimCell> cells;

  /// 「草稿 3 門 · 9 學分」。
  late String draftSummary;

  /// 加上實際課表的總學分與衝堂；還沒加課時是提示。
  late String detail;
  late bool hasConflicts;
  late List<DraftCourseRow> courses;
}

class LogEntry {
  late String level;
  late String text;
}

/// 開發者選單的一筆 HTTP 請求，秘密已經遮掉。
class HttpCallEntry {
  late int id;
  late String method;
  late String url;
  int? status;
  late int durationMs;

  /// 發出的時間，epoch 毫秒。
  late int startedAt;
  late String requestHeaders;
  String? requestBody;
  late String responseHeaders;
  String? responseBody;
  String? error;
}

class StoreEntry {
  late String key;
  late String value;

  /// 只有字串與整數改得了，照 `StoreEditPage`。
  late bool editable;

  /// 憑證不回顯原文。
  late bool sensitive;
}

/// 課表上一個空堂格，照 `empty_cell_sheet.dart`。
class EmptySlot {
  /// 「週一 第 3 節」：星期取自真正要查的那一天。
  late String title;

  /// 「10:20–11:10 · 空堂」。
  late String subtitle;

  /// 空教室要開在哪一天，「2026-09-14」。
  late String date;
  late int section;
}

/// 信箱分頁一進來先問的事。
class MailStatus {
  /// 設定過信箱密碼；沒有就先畫設定頁。
  late bool configured;

  /// 學號換成的完整位址，設定頁那一列帳號。
  late String address;
}

class MailSetupResult {
  late bool ok;

  /// 密碼錯與連不上分開講，照 `MailSetupPage._submit`。
  String? error;
}

/// 信件清單的一列，照 `MailTile`。
class MailRow {
  /// 開信與回信都用它指名：跨資料夾搜尋的結果 UID 不唯一。
  late String ref;
  late int uid;

  /// 寄件者顯示名稱，沒有就是位址。
  late String from;

  /// 今天給時間、其餘給日期。
  late String time;

  /// 空主旨已換成「（無主旨）」。
  late String subject;
  late bool unread;
}

class MailSection {
  late String title;
  late List<MailRow> rows;
}

/// 清單最底下那一列，照 `MailListPage._loadMoreRow`。
enum MailMoreState {
  /// 還有更舊的：捲到這裡就自己載。
  more,

  /// 上一次失敗了：閂住，等使用者自己按。
  failed,

  /// 沒有更舊的了。
  end,
}

/// 資料夾選單的一列。同一個角色只留一個。
class MailFolderRow {
  late String path;
  late String label;

  /// 「4,367 封 · 2,919 未讀」；問不到數量是 null。
  String? count;
  late bool inbox;

  /// 空的資料夾預設收起來；目前所在的那一個不算。
  late bool empty;
}

/// 信件清單此刻的樣子，照 `MailController` 的狀態與 `mail_list_page.dart` 上的字。
class MailListState {
  late String folderPath;
  late String folderTitle;
  late List<MailFolderRow> folders;

  /// 沒在搜尋時依今天、本週、更早分組。
  late List<MailSection> sections;

  /// 搜尋中的關鍵字；null 代表沒在搜尋。
  String? keyword;
  late bool searchAll;
  late List<MailRow> results;

  /// 「3 個結果」。
  String? resultCount;

  /// 還沒有任何可以畫的資料。
  late bool loading;
  String? error;
  String? notice;
  String? emptyMessage;
  late MailMoreState more;

  /// 信箱密碼不見了：回設定頁。
  late bool needsSetup;
}

enum MailOutboxPhase { waiting, sending, failed }

/// 寄件匣的一列，照 `MailOutboxTile`。
class MailOutboxRow {
  late int id;
  late MailOutboxPhase phase;

  /// 「3 秒後寄出」「寄送中」「寄送失敗」。
  late String status;
  late String subject;
  late String recipients;
}

/// 新信橫幅，照 `MainScreen._onNewMail`。
class MailArrival {
  late String title;
  late String message;

  /// 最新的那一封。
  late String ref;
}

class MailAddressLine {
  late String address;

  /// 自己的位址，後面標「（我）」。
  late bool mine;
}

/// 信件內頁的標頭，照 `MailDetailPage`。
class MailHeader {
  late String subject;
  late String from;

  /// 和 [from] 一樣時是 null。
  String? fromEmail;

  /// 「2026/09/13 14:05」。
  late String date;

  /// 「收件者 3 位」；沒有收件者是 null。
  String? recipientCount;
  late List<MailAddressLine> to;
  late List<MailAddressLine> cc;
}

class MailAttachmentRow {
  late String fetchId;
  late String name;

  /// 「PNG · 1.2 MB」；兩個都問不到是 null。
  String? meta;
}

class MailBody {
  /// 深色模式要中和顏色的元素帶著 `data-tat-neutral`。
  String? html;
  late List<MailAttachmentRow> attachments;

  /// 有指向外部的圖片：預設擋掉，給一顆「顯示圖片」。
  late bool remoteImages;
  String? error;
}

enum MailComposeKind { blank, reply, replyAll, forward }

class MailRecipient {
  late String address;

  /// 格式不對的那一顆畫成紅的。
  late bool valid;
}

class MailComposeStart {
  late List<MailRecipient> to;
  late String subject;

  /// 把引言與提示字放進編輯器的 JavaScript，逃脫由核心做。
  late String editorScript;

  /// 一次最多挑幾個檔。
  late int pickLimit;
}

class MailContactRow {
  late String email;

  /// 「王小明 <a@b.c>」。
  late String label;
}

class MailAttachCheck {
  late List<String> accepted;
  String? error;
}

class MailSendRequest {
  late List<String> to;
  late List<String> cc;
  late List<String> bcc;

  /// 還沒收成籤的那一截也算，照 `MailComposePage._send`。
  late String pendingTo;
  late String pendingCc;
  late String pendingBcc;
  late String subject;

  /// 編輯器吐出來的 HTML；拿不到是 null，退回帶進來的引言。
  String? html;
  late List<String> attachments;
}

class MailSendResult {
  /// 排進寄件匣的那一封；null 代表沒收下，原因在 [error]。
  int? queuedId;
  String? error;

  /// 收得回來的秒數，「收回」鈕就活這麼久。
  late int holdSeconds;
}

/// 介面語言。對應 `OtherSettingJson.lang` 的 `TW_zh` 與 `_en`。
enum AppLanguage { zhTW, en }

/// 啟動時一次拿齊：先進哪一頁、介面用哪個語言。
class AppLaunch {
  late String account;

  /// 使用者沒選過時是 null：原生端依系統語言決定，再用 [TatCoreApi.setLanguage] 寫回，
  /// 與 Flutter 版 `LanguageUtils.init` 的行為一致。
  AppLanguage? language;
}

/// 密碼會過界：登入頁要把它填回欄位，而它不出行程。
class SavedCredentials {
  late String account;
  late String password;
}

/// 核心在這台裝置上看得到什麼。E1 的探針，正式版會拆掉。
class CoreStatus {
  late String credentials;
  late String account;
  late bool hasMoodleToken;
  late int courseTableCount;
  late String locale;
}

/// **Dart 實作、Swift 呼叫。** 取資料的入口。
@FlutterApi()
abstract class TatCoreApi {
  CoreStatus status();

  AppLaunch launch();

  /// 還沒同意隱私權條款，照 `AppService.needsPrivacyAgreement`。
  @async
  bool needsPrivacyAgreement();

  /// 啟動時的同意閘門按下同意，照 `PrivacyPolicyController.onAgreePrivacyPolicy`。
  @async
  void agreePrivacyPolicy();

  /// 核心的字串表（`R.current`）與伺服器請求的語言都跟著換，並寫回設定。
  @async
  void setLanguage(AppLanguage language);

  /// [semester] 傳 null 代表「最近的那個學期」。
  ///
  /// 標 @async 是因為它底下要打網路；沒標的話產生的 Dart 介面是同步的，
  /// 實作回 Future 會直接編譯不過。
  @async
  CourseTableResult getCourseTable(String? semester);

  /// 成績。底下走的是 Swift 的 WKWebView 抓 HTML、Dart 解析（見 E3）。
  @async
  ScoreResult getScore();

  /// 沒存過時兩個欄位都是空字串。
  SavedCredentials credentials();

  /// 只存、不驗證，與 `LoginController.onLoginEvent` 一致。
  @async
  void saveCredentials(String account, String password);

  /// 探針用：直接開可見的登入頁，回傳結果摘要。正式主畫面做出來後拆掉。
  @async
  String debugInteractiveSignIn(bool moodle);
}

/// **Dart 實作、Swift 呼叫。** 課表頁，流程照 `CourseController`／`CourseModel`。
@FlutterApi()
abstract class TatCourseTableApi {
  /// 上次顯示的那一張，不打網路。沒有的話回 null，呼叫端接著 [load]。
  CourseGrid? current();

  /// [semester] 是 null 代表最新的學期；[refresh] 為 true 時不用快取。
  ///
  /// 失敗回 null：錯誤對話框與重試已經由核心的 `run()` 問過使用者。
  @async
  CourseGrid? load(String? semester, bool refresh);

  /// 學期選單，由新到舊。
  @async
  List<String> semesters();

  /// 在背景先把學期清單抓好，照 `CourseModel.preloadSemesterList`：不開任何 UI，失敗就安靜失敗，
  /// 點學期選單時再照常抓。
  @async
  void preloadSemesters();

  /// 切換器的「我的課表」。
  List<MyTable> myTables();

  /// 套用一份我的課表，照 `CourseController.applyFavorite`。找不到回 null。
  @async
  CourseGrid? applyMyTable(String studentId, String semester);

  /// 只清掉本機快取，下次選那個學期會再抓一次。
  @async
  void deleteMyTable(String studentId, String semester);

  /// 目前這一份的分享內容；還沒有課表時回 null。
  TableShare? share();

  @async
  List<SharedTableInfo> sharedTables();

  @async
  CourseGrid? sharedTable(String id);

  @async
  void deleteSharedTable(String id);

  /// 解開分享碼（掃到的網址或貼上的文字），認不得回 null。
  SharePreview? previewShareCode(String raw);

  /// 查預覽裡那幾門課。**學期由分享碼決定，呼叫端不能指定**：同一個課號在不同學期
  /// 會回不同的老師與教室，查錯學期會排出一列看起來完全自洽的假資料。
  @async
  List<SharedCourseInfo> lookupPreview(String raw);

  /// 匯入並存成他人課表。認不得回 null。格子當下就畫得出來，課名之後補。
  @async
  SharedTableInfo? importShareCode(String raw);

  /// 補上他人課表的課名、教室與老師並存回去，回傳補完的格線。查不到的課保持原樣。
  @async
  CourseGrid? restoreSharedTable(String id);

  /// 移除 [day]、[section] 那一格的課並存回去，照 `CourseController.removeCourse`。找不到回 null。
  @async
  CourseGrid? removeCourse(int day, int section);

  /// 改 [day]、[section] 那一格的課號並存回去，照 `editCourseCellId`。找不到回 null。
  @async
  CourseGrid? editCourseId(int day, int section, String courseId);

  /// 點到空堂格：要不要去找那個時段的空教室。對不到任何一天的那一欄（`Day.unKnown`）回 null。
  EmptySlot? emptySlot(int day, int section);
}

/// **Dart 實作、Swift 呼叫。** 導入其他課程，畫面照 `course_search_page.dart`。
///
/// 查到的課留在 Dart：加課要整份課程資料，原生端手上只有畫面上的字。
@FlutterApi()
abstract class TatCourseSearchApi {
  /// 還沒有課表時回 null。[draftId] 不是 null 時加進那一份模擬課表，衝堂對實際課表加草稿算。
  CourseSearchStart? start(String? draftId);

  /// 查詢並記住結果，回傳套用篩選之後的清單。被之後的查詢蓋過時回 null。
  @async
  CourseSearchResults? search(
      CourseFilter filter, bool hideConflict, List<TimeSlot> slots);

  /// 換篩選或課表變了之後重算，不重查。
  CourseSearchResults results(bool hideConflict, List<TimeSlot> slots);

  @async
  CourseSearchChange add(String courseId);

  @async
  CourseSearchChange remove(String courseId);

  @async
  List<CourseSearchOption> colleges();

  @async
  List<CourseSearchOption> departments(String collegeNo);
}

/// **Dart 實作、Swift 呼叫。** 成績頁，流程照 `ScorePageController`、
/// `moodle_course_grades_page.dart` 與 `course_score_page.dart`。
@FlutterApi()
abstract class TatScoreApi {
  /// [refresh] 為 false 時先用存著的，沒有才抓。
  @async
  ScoreReport load(bool refresh);

  /// 這學期每一門課在 Moodle 上的即時總分。[refresh] 為 false 是進頁時的背景載入，不開登入頁。
  @async
  MoodleGrades moodleGrades(bool refresh);

  /// 一門課在 Moodle 上的成績項目。
  @async
  MoodleCourseScore courseScore(String courseId);
}

/// **Dart 實作、Swift 呼叫。** 行事曆頁，流程照 `CalendarController` 與
/// `upcoming_events_section.dart`。
@FlutterApi()
abstract class TatCalendarApi {
  /// 學校行事曆每一天的事。檔案在就不打網路；[refresh] 為 true 時重新下載，會問要哪個學期。
  @async
  List<CalendarDay> schoolCalendar(bool refresh);

  /// Moodle 待辦，依截止時間分好組。[refresh] 為 false 是進頁時的背景載入。
  @async
  UpcomingEvents upcoming(bool refresh);

  /// 開一筆待辦要用的網址，已換成免登入網址。找不到回 null。
  @async
  WebLink? eventLink(int eventId);

  /// 停在 autologin.php 本身代表鑰匙被拒。
  bool isAutologinScript(String url);

  /// 能在 App 內開的模組（作業、測驗、討論區），照 `RouteUtils.tryOpenUpcomingEvent`；開不了回 null。
  @async
  ModuleTarget? eventTarget(int eventId);
}

/// **Dart 實作、Swift 呼叫。** 「更多」分頁與底下的個人資訊、關於，流程照 `other_page.dart`。
@FlutterApi()
abstract class TatMoreApi {
  bool isSignedIn();

  /// Moodle 上的姓名與頭貼，照 `MainController._loadMoodleProfile`。抓不到回 null；
  /// [interactive] 為 false 時不開登入頁。
  @async
  MoodleProfile? profile(bool interactive);

  /// 換頭貼，[jpeg] 是 null 就是移除。成功回 null，失敗回要顯示的訊息。
  @async
  String? changeAvatar(Uint8List? jpeg);

  @async
  ThemeChoice theme();

  @async
  void setTheme(ThemeChoice theme);

  /// 主題色的 ARGB，沒選過是 null：用預設的品牌色。
  @async
  int? themeColor();

  @async
  void setThemeColor(int? argb);

  /// 意見回饋表單，帶上版本與記錄。
  @async
  String feedbackUrl();

  /// 抓不到回 null。
  @async
  List<ProjectContributor>? contributors();

  /// 清掉 Dart 這一側與使用者有關的狀態，照 `SessionCleaner.logoutAll`。WKWebView 的 cookie 由原生端清。
  @async
  void logout();
}

/// **Dart 實作、Swift 呼叫。** 資訊系統，照 `sub_system_page.dart`。搜尋在原生端做，不打 API。
@FlutterApi()
abstract class TatSubSystemApi {
  @async
  ServiceTree tree();
}

/// **Dart 實作、Swift 呼叫。** Moodle 通知設定，照 `MoodleSettingController`。
@FlutterApi()
abstract class TatMoodleSettingApi {
  /// 抓不到回 null。
  @async
  MoodleSettings? load();

  /// 開關一項通知的一種方式並重抓。寫入失敗回 null。
  @async
  MoodleSettings? toggle(String key, String processor, bool enabled);
}

/// **Dart 實作、Swift 呼叫。** 空教室，流程照 `ClassroomController`。
@FlutterApi()
abstract class TatClassroomApi {
  /// 校區與大樓、上次用的檢視與大樓、現在是第幾節。
  @async
  ClassroomSetup start();

  ClassroomNow now();

  /// 一棟在某一天某一節的情形。同一棟同一天抓過就不再打網路，除非 [refresh]。
  @async
  ClassroomDay day(String campusCode, String buildingCode, String date,
      int section, ClassroomRun run, bool refresh);

  @async
  void rememberBuilding(String code);

  @async
  void rememberLayout(ClassroomLayout layout);
}

/// **Dart 實作、Swift 呼叫。** 課程詳細資訊與修課學生，流程照 `CourseDetailController`
/// 與 `CourseMemberController`。
@FlutterApi()
abstract class TatCourseDetailApi {
  /// [semester] 是「115-1」。
  @async
  CourseDetailResult detail(String courseId, String semester);

  /// 名單那支 API 很慢：[refresh] 為 false 時手上已經有就不重打。
  @async
  CourseMembers members(String courseId, bool refresh);

  /// 在上一次抓回來的名單裡找姓名或學號，不打網路。
  List<CourseMember> filterMembers(String courseId, String query);
}

/// **Dart 實作、Swift 呼叫。** 一門課的 Moodle：檔案、公告、作業三個分頁與檔案分頁點進去的東西，
/// 流程照 `CourseDataController` 與 `CourseModuleActions`。成績分頁走 [TatScoreApi.courseScore]。
@FlutterApi()
abstract class TatCourseMoodleApi {
  @async
  CourseDirectory directory(String courseId);

  /// 在上一次抓到的目錄裡找檔名或模組名稱，不打網路。
  List<CourseSectionItem> searchDirectory(String courseId, String query);

  /// resource 模組的檔案。沒有檔案回 null。
  MoodleFileLink? moduleFile(String courseId, int moduleId);

  /// url 模組指向的外部網址。沒有回 null。
  String? moduleUrl(String courseId, int moduleId);

  /// 模組在網頁上的那一頁，已換成免登入網址。
  @async
  WebLink? moduleWebLink(String courseId, int moduleId);

  /// 資料夾模組的 [path] 那一層，頭尾都有 `/`。
  CourseFolder? folder(String courseId, int moduleId, String path);

  @async
  CoursePage page(String courseId, int moduleId);

  @async
  CourseFeed feed(String courseId);

  /// 換篩選時重新分組，不打網路。[kind] 是 null 代表全部。
  CourseFeed filterFeed(String courseId, FeedKind? kind);

  /// 一個討論區的主題清單。[forumId] 是 forum instance id。
  @async
  ForumDiscussions forumDiscussions(int forumId);

  /// 作業清單，狀態還沒抓。
  @async
  AssignmentList assignments(String courseId);

  /// 每一份作業的繳交狀態都背景抓完之後的清單，照狀態重排。
  @async
  AssignmentList assignmentStatuses(String courseId);

  /// 手上已經有的清單與狀態重新排一次，不打網路：作業詳情頁寫進伺服器之後，回到清單要看得到。
  AssignmentList cachedAssignments(String courseId);

  /// 網頁版的討論串，已換成免登入網址。
  @async
  WebLink discussionWebLink(int discussionId);

  /// HTML 裡的連結要怎麼開：自家檔案直接下載、http(s) 在 App 內開、其餘擋掉。
  @async
  MoodleLinkTarget linkTarget(String url);

  /// 停在 autologin.php 本身代表鑰匙被拒。
  bool isAutologinScript(String url);

  /// HTML 裡的圖片，換成現在就載得動的網址：自家檔案要帶憑證，其他站台只收 https。
  List<String> htmlImages(String html);
}

/// **Dart 實作、Swift 呼叫。** 作業詳情與繳交，流程照 `CourseAssignmentController`
/// 與 `CourseAssignSubmitController`。繳交頁的草稿留在 Dart，Swift 每一次操作都拿回整份畫面。
@FlutterApi()
abstract class TatAssignmentApi {
  /// 清單抓過的作業與狀態直接沿用；[refresh] 為 true 時兩個都重抓。
  @async
  AssignmentDetailResult detail(String courseId, int assignId, bool refresh);

  @async
  AssignWriteResult submitForGrading(int assignId, bool acceptStatement);

  @async
  AssignWriteResult removeSubmission(int assignId);

  @async
  AssignWriteResult copyPrevious(int assignId);

  /// 網頁版作業頁，已換成免登入網址。
  @async
  WebLink? webLink(int assignId);

  /// 開繳交頁：作業與狀態兩個都要是這一趟抓到的，否則回 null。
  SubmitState? openSubmit(int assignId);

  SubmitState setText(int assignId, String text);

  SubmitState setAccepted(int assignId, bool accepted);

  /// 挑回來的檔案，類型不合、太大與重名的擋掉，理由放在 [SubmitState.messages]。
  @async
  SubmitState addFiles(int assignId, List<String> paths);

  /// [index] 是 [SubmitState.files] 裡的位置。伺服器上的那一份只是標記、撤得回來；
  /// 這次剛挑的直接拿掉。
  SubmitState toggleFile(int assignId, int index);

  /// 儲存前要不要先問；回 null 就直接存。
  String? saveConfirmation(int assignId);

  @async
  SubmitOutcome save(int assignId);

  /// 取消還在傳的檔案。已經送出去的那一趟收不回來。
  void cancelSubmit(int assignId);

  String startConfirmation(int assignId);

  @async
  SubmitState start(int assignId);

  /// 離開繳交頁。「開始作答」已經寫進伺服器的話，詳情頁要照回來的 [AssignWriteResult.detail] 重畫。
  @async
  AssignWriteResult closeSubmit(int assignId);
}

/// **Dart 實作、Swift 呼叫。** 測驗詳情，流程照 `CourseQuizController`。
@FlutterApi()
abstract class TatQuizApi {
  @async
  QuizDetailResult detail(String courseId, int quizId, bool refresh);

  /// 網頁版測驗頁，已換成免登入網址。
  @async
  WebLink? answerLink(String courseId, int quizId);
}

/// **Swift 實作、Dart 呼叫。** 上傳進度。一趟寫入的結果還是由呼叫它的那一支回答，這裡只報進度。
@HostApi()
abstract class TatTransferHost {
  void onProgress(TransferProgress progress);
}

/// **Dart 實作、Swift 呼叫。** 討論串、回覆、編輯與刪除，流程照 `CourseForumThreadController`
/// 與討論串頁上的判斷。
@FlutterApi()
abstract class TatForumApi {
  /// [title] 是清單那一列的標題。[readOnly] 是公告區：學生本來就不能回覆，底部不畫「去網頁」。
  @async
  ForumThread thread(String courseId, int forumId, int discussionId,
      String title, bool readOnly, bool refresh);

  /// 挑回來的附件先擋：太大、重名、超過數量。[existingNames] 是已經在草稿裡的檔名。
  @async
  AttachmentCheck checkAttachments(
      int discussionId, List<String> existingNames, List<String> paths);

  /// [parentId] 是 null 代表回第一篇。
  @async
  ForumSendResult reply(
      int discussionId, int? parentId, String text, List<String> paths);

  /// 按下編輯時的那一趟：拿新鮮的權限與原文。
  @async
  ForumEditStart startEdit(int discussionId, int postId);

  /// [text] 在所見即所得那條路上是編輯器吐出來的 HTML。[keepNames] 是留下的既有附件。
  @async
  ForumSendResult saveEdit(int discussionId, int postId, String subject,
      String text, List<String> keepNames, List<String> paths);

  @async
  ForumDeleteResult deletePost(int discussionId, int postId);

  /// 取消還在上傳的附件。送出去的那一趟收不回來。
  void cancelTransfer(int discussionId);
}

/// **Dart 實作、Swift 呼叫。** 通知中心，照 `announcement_center_page.dart`。
@FlutterApi()
abstract class TatInboxApi {
  /// 進頁：公告與通知一起抓，通知不開登入頁。
  @async
  InboxState load();

  /// 下拉重新整理，可以開登入頁。
  @async
  InboxState refresh();

  /// 通知那一半的重試，可以開登入頁。
  @async
  InboxState retryNotifications();

  /// 標為已讀。失敗時核心會提示，回來的是改回去的狀態。
  @async
  InboxState markRead(int id);

  @async
  InboxMarkAll markAllRead();

  /// 那一則的自家網址，已換成免登入網址；沒有網址回 null。
  @async
  WebLink? openLink(int id);

  /// 課表頁鈴鐺上的未讀數。[force] 為 false 時一分鐘內不重抓。
  @async
  int badge(bool force);

  List<InboxPreviewItem> previewItems();

  /// 換成假資料，之後的已讀與開啟只動記憶體，直到下一次 [load]。
  InboxState startPreview(int index);
}

/// **Dart 實作、Swift 呼叫。** 啟動時的公告彈窗與更新提示。
@FlutterApi()
abstract class TatAppNoticeApi {
  /// 照 `RouteUtils.showAnnouncement`；沒有要跳的回 null。[test] 是開發者選單的預覽。
  @async
  LaunchAnnouncement? launchAnnouncement(bool test);

  /// 公告頁按下確定。
  @async
  void markAnnouncementRead();

  /// 照 `UpdatePrompt`：一天最多問一次、略過的版本不再問。不必問時回 null。
  /// [manual] 是更多頁的「檢查新版本」：使用者自己來問，略過與一天一次都不算數，也不記成問過。
  @async
  UpdateOffer? updateOffer(bool manual);

  @async
  void ignoreUpdate();

  /// 開發者選單：Remote Config 不快取，照 `DevPage.initState`。
  @async
  void refreshRemoteConfig();
}

/// **Dart 實作、Swift 呼叫。** App 內瀏覽器停在學校登入頁時代填帳密，照 `InAppWebViewPage`。
@FlutterApi()
abstract class TatBrowserApi {
  /// 可見的瀏覽器要讓核心驅動時先拿一個編號，與核心自己開的 WebView 共用同一組。
  int reserveSession();

  bool isLoginPage(String url);

  @async
  BrowserLoginOutcome autoLogin(int sessionId, String url);
}

/// **Dart 實作、Swift 呼叫。** 模擬排課，照 `simulation_page.dart`。草稿不會寫回實際課表。
@FlutterApi()
abstract class TatSimulationApi {
  @async
  List<DraftTableInfo> drafts();

  /// 新增時可以選的學期，由新到舊；querycourse 查不到才退回自己的學期。
  @async
  List<String> semesters();

  /// 那一學期的草稿，沒有就開一份新的。
  @async
  SimulationState open(String semester);

  @async
  SimulationState? draft(String id);

  @async
  SimulationState? removeCourse(String id, String courseId);

  @async
  void deleteDraft(String id);
}

/// **Dart 實作、Swift 呼叫。** 開發者選單，照 `dev_page.dart`。
@FlutterApi()
abstract class TatDeveloperApi {
  List<LogEntry> logs();

  void clearLogs();

  /// 只有 debug 建置會記。
  List<HttpCallEntry> httpCalls();

  void clearHttpCalls();

  @async
  List<StoreEntry> storeEntries();

  @async
  void setStoreValue(String key, String value);

  @async
  void removeStoreKey(String key);

  /// 離開編輯頁時重讀設定，照 `StoreEditPage.dispose`。
  @async
  void reloadStore();
}

/// **Dart 實作、Swift 呼叫。** 信箱分頁：設定、清單、資料夾、搜尋、寄件匣與新信輪詢，流程照
/// `MailPage`、`MailListPage` 與 `MainScreen` 的信箱那幾段。清單狀態由 [TatMailHost.onList] 推過去。
@FlutterApi()
abstract class TatMailApi {
  MailStatus status();

  /// 驗過密碼才存，照 `MailSetupPage._submit`。
  @async
  MailSetupResult setup(String password);

  /// 進分頁：換一份新的清單狀態，先畫本機再打網路。
  @async
  void open();

  /// 下拉重新整理。
  @async
  void reload();

  @async
  void openFolder(String path);

  /// 送出關鍵字或換範圍。空字串回到資料夾清單，範圍留著。
  @async
  void search(String keyword, bool allFolders);

  /// 關掉搜尋列：範圍回到目前資料夾。
  @async
  void endSearch();

  @async
  void loadMore();

  /// 點進去時順手標已讀。
  @async
  void markSeen(String ref);

  /// 列用 ref 指名，不用 UID：跨資料夾搜尋的結果 UID 會撞。
  @async
  bool setSeen(String ref, bool seen);

  @async
  bool moveToTrash(String ref);

  @async
  bool archive(String ref);

  @async
  bool moveToFolder(String ref, String target);

  /// App 回到前景。沒設定密碼時什麼都不做。
  void startWatch();

  /// App 進背景：這一版刻意不做背景輪詢。
  void stopWatch();

  /// 冷啟動時讀回上次沒寄完的。
  @async
  void restoreOutbox();

  /// 只有還在等的收得回來。
  @async
  bool recall(int id);

  @async
  void retry(int id);
}

/// **Dart 實作、Swift 呼叫。** 一封信的內頁，照 `MailDetailPage`。
@FlutterApi()
abstract class TatMailMessageApi {
  /// 清單或橫幅上的那一封；找不到回 null。
  MailHeader? header(String ref);

  /// 內文刻意不快取，每次都是一趟連線。
  @async
  MailBody body(String ref);

  /// 附件存到 [destination]。
  @async
  bool saveAttachment(String ref, String fetchId, String destination);

  /// 從新信橫幅進來時標已讀，照 `MainScreen._openMail`。
  @async
  void markSeen(String ref);

  /// 封存或丟進回收筒。
  @async
  bool move(String ref, bool archive);
}

/// **Dart 實作、Swift 呼叫。** 寫信、回覆與轉寄，照 `MailComposePage` 與 `MailRecipientField`。
@FlutterApi()
abstract class TatMailComposeApi {
  /// [ref] 是回覆或轉寄的那一封；寫新信時是空字串。
  MailComposeStart start(MailComposeKind kind, String ref);

  /// 打的字收成籤：切開、去重、驗格式，回傳整份清單。
  List<MailRecipient> addRecipients(List<String> existing, String raw);

  /// 收件者欄的自動完成。已經收成籤的人不再建議。
  @async
  List<MailContactRow> suggest(String query, List<String> taken);

  /// 挑回來的檔案先擋總大小。
  @async
  MailAttachCheck checkAttachments(List<String> existing, List<String> picked);

  /// 排進寄件匣，不在這裡等 SMTP。
  @async
  MailSendResult send(MailSendRequest request);
}

/// **Dart 呼叫、Swift 實作。** 信箱那一側自己發生的事。
@HostApi()
abstract class TatMailHost {
  void onList(MailListState state);

  /// 寄件匣變了，倒數的每一秒也算。
  void onOutbox(List<MailOutboxRow> rows);

  void onArrival(MailArrival arrival);

  /// 一封信寄完了。
  void onSent(bool sent);
}

/// 平台 WebView store 上的一顆 cookie。
///
/// **平台 store 是權威，Dio 的 jar 是它的鏡像。** 理由見
/// `lib/src/service/cookie_bridge.dart`：所有互動式登入本來就跑在 WebView 裡，
/// 寫的就是平台 store；反過來要讓 WebView 讀 Dio 的 jar 得替它發明一套注入機制。
class WebCookie {
  late String name;
  late String value;
  late bool secure;
  late bool httpOnly;
}

/// 用平台的 WebView 載一頁、把 HTML 拿回來。
///
/// 判準以資料傳進去而不是寫死在 Swift：**哪一頁才算「真的到了」是 Dart 的知識**
/// （見 `ScoreConnector.isScorePage`），Swift 只負責跑 WebView 與計時。
class PageLoadRequest {
  late String url;

  /// HTML 要**同時**含有這些字串才算到站。
  ///
  /// 不可以只看網址：未登入時的轉址鏈最後一站是 ssoam2 的自動送出表單，
  /// 它的網址同樣含 `StuScoreQuery`。在中途站收網會解析出一份非 null 的空成績，
  /// 呼叫端當成功寫回硬碟，成績頁就被清空且沒有任何錯誤訊息。
  late List<String> completeWhenHtmlContainsAll;

  /// 網址含有其中任一個代表被踢回登入頁——等下去不會變好，直接失敗，
  /// 不要讓使用者盯著遮罩等滿逾時。
  late List<String> failWhenUrlContainsAny;

  /// 逾時秒數。**不可以拿掉**：外層進度框是全螢幕、不可點擊的遮罩，
  /// 不收網使用者只能殺掉 App。
  late int timeoutSeconds;
}

enum PageLoadOutcome { ok, redirectedToLogin, timeout, error }

class PageLoadResult {
  late PageLoadOutcome outcome;
  String? html;
  String? detail;
}

/// 一個由 Dart 驅動的 WKWebView。headless 的取代 HeadlessInAppWebView，可見的是登入頁。
///
/// 登入的判準與流程留在 Dart（`Ssoam2Login`、`interactive_login_flow.dart`），Swift 只提供
/// WebView 本身：跑 JavaScript、回報每一頁載完、畫出可見的那一頁。
class WebSessionRequest {
  /// 由 Dart 配發：Dart 先登記再請 Swift 開，事件才不會比登記早到。
  late int sessionId;
  late String url;
  late bool visible;

  /// 可見時的標題。
  late String title;

  /// 可見時一開始顯示的進度提示；null 代表不顯示。顯示期間網頁不接受點擊。
  String? progressMessage;

  /// 導到這些 scheme 時擋下導航、改送 onIntercepted（Moodle 的 `moodlemobile://`）。
  late List<String> interceptSchemes;
}

/// 對話框的種類。只影響標題前那顆圓點的顏色。
enum DialogKind { error, warning, info, success }

/// 對應 `ErrorDialogParameter`。
///
/// 欄位刻意一對一搬過來而不是壓成「標題＋內文」：`destructive`、
/// `offerLoginScreen`、兩個 `hide*` 都會改變使用者的出口，壓掉就沒了。
class ErrorDialogRequest {
  late String desc;
  String? title;
  String? okText;
  String? cancelText;
  DialogKind? kind;

  /// 主鈕換成 error 底。
  late bool destructive;

  late bool hideOk;
  late bool hideCancel;

  /// 站台明確拒絕憑證時為 true：除了重試之外還要給一顆通往登入設定的按鈕。
  /// 一般的抓取失敗不給，多一顆通往登入頁的鈕反而讓人以為是自己帳號有問題。
  late bool offerLoginScreen;
}

/// 單選清單的一個選項。
class ChooseOption {
  /// 顯示的字。
  late String label;

  /// 選了之後要回傳的值。
  late String value;
}

/// 使用者對錯誤對話框的選擇。
enum RetryChoice { retry, giveUp }

/// **Swift 實作、Dart 呼叫。** 對應 `TaskUiDelegate`。
///
/// 核心層不可以自己開對話框（那是 controller -> ui 的上行邊），
/// 原本走 `TaskUiDelegate`，在原生版就是走這條 channel。
@HostApi()
abstract class TatCoreUiApi {
  /// 開一個進度框，回傳只關掉這一個的憑證。
  ///
  /// **一定要有 handle。** 課程頁三個分頁並行載入，沒有東西可以指名的話，
  /// 先結束的那一個會把另外兩個的遮罩一起收掉。
  int beginProgress(String message);

  void dismissProgress(int handle);

  @async
  RetryChoice confirmRetry(ErrorDialogRequest request);

  void toast(String message);

  /// 請使用者從幾個選項裡挑一個，回傳選中的 `value`。
  ///
  /// **取消時回 null，呼叫端不可以自己挑一個頂替**——那會給出使用者沒選過的東西。
  @async
  String? chooseOne(String title, List<ChooseOption> options);

  /// 請使用者手動挑一個學期，格式是 `"115-1"`。取消回 null。
  ///
  /// [allowNull] 為 false 時，使用者沒有選就回「現在這個學期」而不是 null
  /// ——那是既有行為，呼叫端在那條路徑上沒有 null 的處理。
  @async
  String? chooseSemester(bool allowNull);

  /// 帶使用者去登入設定。站台明確拒絕憑證時的出口。
  @async
  void openLoginScreen();

  /// 讀平台 WebView store 上 [url] 的 cookie，鏡射進 Dio 的 jar 用。
  ///
  /// **網域必須留在 `.ntust.edu.tw`**（由 Dart 端寫入時決定）：ssoam2、
  /// stuinfosys、i.ntust 是不同 host，只有網域 cookie 能跨。改成逐 host 會
  /// **靜默**弄壞成績頁。
  @async
  List<WebCookie> webCookies(String url);

  /// 用平台的 WebView 載一頁，回最後的 HTML。取代 HeadlessInAppWebView。
  @async
  PageLoadResult loadPage(PageLoadRequest request);

  void openWebSession(WebSessionRequest request);

  /// 結果是 bool、數字、字串或 null。WebKit 不支援的型別（undefined、DOM 節點）回 null，
  /// 與 flutter_inappwebview 一致。
  @async
  Object? evaluateJavascript(int sessionId, String source);

  @async
  String? webSessionHtml(int sessionId);

  void loadWebSessionUrl(int sessionId, String url);

  /// null 代表收起進度提示，網頁恢復可以點。
  void setWebSessionProgress(int sessionId, String? message);

  /// Dart 要求關掉。不會再送 onDismissed：那個事件只代表使用者自己關掉。
  void closeWebSession(int sessionId);
}

/// **Swift 呼叫、Dart 實作。** WebSession 的事件。
@FlutterApi()
abstract class TatWebSessionEvents {
  /// 一頁載完。轉址鏈的每一站都會來一次。
  void onLoadStop(int sessionId, String? url);

  void onLoadError(int sessionId, String description);

  void onIntercepted(int sessionId, String url);

  /// 使用者自己關掉了可見的頁面。
  void onDismissed(int sessionId);
}

/// 小工具上的一天。
class WidgetTableDay {
  /// 1 是週一，7 是週日。
  late int weekday;
  late String label;
}

/// 小工具格線上的一節。
class WidgetTableSection {
  late int index;
  late String label;

  /// 當天 0 點起算的分鐘數。
  late int start;
  late int end;
}

/// 小工具上的一堂課。同一天、節次相連的同一門課已經併成一段。
class WidgetTableLesson {
  /// 1 是週一，7 是週日。
  late int weekday;
  late int firstSection;
  late int lastSection;

  /// 當天 0 點起算的分鐘數。
  late int start;
  late int end;
  late String name;
  String? classroom;

  /// 課號在課表裡的順序，和課表格子挑顏色的依據相同。
  late int order;
}

/// 小工具要畫的一張課表。有哪幾張、連堂怎麼併是 Dart 的判斷。
class WidgetTable {
  /// 「115-1」。
  late String semester;
  late int courseCount;
  late int credits;
  late List<WidgetTableDay> days;
  late List<WidgetTableSection> sections;
  late List<WidgetTableLesson> lessons;
}

/// **Dart 實作、Swift 呼叫。** 桌面與鎖定畫面的小工具。extension 裡跑不了核心，
/// App 回到背景前要一份寫進 App Group。
@FlutterApi()
abstract class TatWidgetApi {
  /// 自己的課表，學期新的在前；沒登入或還沒有課表時是空的。看哪一學期是每個小工具自己的設定。
  List<WidgetTable> timetables();
}
