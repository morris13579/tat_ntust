import 'package:flutter/widgets.dart';

/// Lucide 圖示。字體是自帶的 assets/fonts/lucide-*.ttf，不裝
/// lucide_icons_flutter（理由見 pubspec.yaml）。
///
/// 這個檔案是產生出來的，不要手改：加完用法之後跑
/// `python3 tool/gen_lucide_icons.py`，它會掃 lib/ 並重產這裡的常數。
/// 名稱查 https://lucide.dev/icons/ ，碼位查 tool/lucide_codepoints.json。
///
/// 三個類別是三種筆畫粗細，碼位相同、只差 fontFamily。挑粗細就換類別：
/// 內文與清單用預設的 [LucideIcons]，要更細（例如和檔案類型圖示並排）用
/// [LucideIconsThin]，要強調用 [LucideIconsThick]。

/// 1.5px，App 預設的筆畫。
@staticIconProvider
class LucideIcons {
  const LucideIcons._();

  static const String _family = 'Lucide';

  /// arrow-down
  static const IconData arrowDown = IconData(0xe042, fontFamily: _family);

  /// arrow-left
  static const IconData arrowLeft = IconData(0xe048, fontFamily: _family);

  /// award
  static const IconData award = IconData(0xe04f, fontFamily: _family);

  /// bell
  static const IconData bell = IconData(0xe059, fontFamily: _family);

  /// bold
  static const IconData bold = IconData(0xe05d, fontFamily: _family);

  /// book-open
  static const IconData bookOpen = IconData(0xe05f, fontFamily: _family);

  /// building-2
  static const IconData building2 = IconData(0xe290, fontFamily: _family);

  /// bus
  static const IconData bus = IconData(0xe1d4, fontFamily: _family);

  /// calendar
  static const IconData calendar = IconData(0xe063, fontFamily: _family);

  /// calendar-clock
  static const IconData calendarClock = IconData(0xe304, fontFamily: _family);

  /// calendar-days
  static const IconData calendarDays = IconData(0xe2b9, fontFamily: _family);

  /// camera
  static const IconData camera = IconData(0xe064, fontFamily: _family);

  /// camera-off
  static const IconData cameraOff = IconData(0xe065, fontFamily: _family);

  /// chart-column
  static const IconData chartColumn = IconData(0xe2a3, fontFamily: _family);

  /// check
  static const IconData check = IconData(0xe06c, fontFamily: _family);

  /// check-check
  static const IconData checkCheck = IconData(0xe38e, fontFamily: _family);

  /// chevron-down
  static const IconData chevronDown = IconData(0xe06d, fontFamily: _family);

  /// chevron-left
  static const IconData chevronLeft = IconData(0xe06e, fontFamily: _family);

  /// chevron-right
  static const IconData chevronRight = IconData(0xe06f, fontFamily: _family);

  /// chevron-up
  static const IconData chevronUp = IconData(0xe070, fontFamily: _family);

  /// circle-alert
  static const IconData circleAlert = IconData(0xe077, fontFamily: _family);

  /// circle-check
  static const IconData circleCheck = IconData(0xe07c, fontFamily: _family);

  /// clipboard
  static const IconData clipboard = IconData(0xe085, fontFamily: _family);

  /// clipboard-check
  static const IconData clipboardCheck = IconData(0xe219, fontFamily: _family);

  /// clipboard-list
  static const IconData clipboardList = IconData(0xe086, fontFamily: _family);

  /// clock
  static const IconData clock = IconData(0xe087, fontFamily: _family);

  /// cloud-download
  static const IconData cloudDownload = IconData(0xe089, fontFamily: _family);

  /// code-xml
  static const IconData codeXml = IconData(0xe206, fontFamily: _family);

  /// copy
  static const IconData copy = IconData(0xe09e, fontFamily: _family);

  /// download
  static const IconData download = IconData(0xe0b2, fontFamily: _family);

  /// ellipsis-vertical
  static const IconData ellipsisVertical =
      IconData(0xe0b7, fontFamily: _family);

  /// external-link
  static const IconData externalLink = IconData(0xe0b9, fontFamily: _family);

  /// eye
  static const IconData eye = IconData(0xe0ba, fontFamily: _family);

  /// eye-off
  static const IconData eyeOff = IconData(0xe0bb, fontFamily: _family);

  /// file-check-2
  static const IconData fileCheck2 = IconData(0xe0c2, fontFamily: _family);

  /// file-pen
  static const IconData filePen = IconData(0xe31f, fontFamily: _family);

  /// file-question
  static const IconData fileQuestion = IconData(0xe322, fontFamily: _family);

  /// file-text
  static const IconData fileText = IconData(0xe0cc, fontFamily: _family);

  /// filter
  static const IconData filter = IconData(0xe0dc, fontFamily: _family);

  /// flashlight
  static const IconData flashlight = IconData(0xe0d3, fontFamily: _family);

  /// flask-conical
  static const IconData flaskConical = IconData(0xe0d5, fontFamily: _family);

  /// folder
  static const IconData folder = IconData(0xe0d7, fontFamily: _family);

  /// graduation-cap
  static const IconData graduationCap = IconData(0xe234, fontFamily: _family);

  /// hand-coins
  static const IconData handCoins = IconData(0xe5b8, fontFamily: _family);

  /// hash
  static const IconData hash = IconData(0xe0ef, fontFamily: _family);

  /// heading-3
  static const IconData heading3 = IconData(0xe387, fontFamily: _family);

  /// heading-4
  static const IconData heading4 = IconData(0xe388, fontFamily: _family);

  /// heading-5
  static const IconData heading5 = IconData(0xe389, fontFamily: _family);

  /// history
  static const IconData history = IconData(0xe1f5, fontFamily: _family);

  /// id-card
  static const IconData idCard = IconData(0xe617, fontFamily: _family);

  /// image
  static const IconData image = IconData(0xe0f6, fontFamily: _family);

  /// image-off
  static const IconData imageOff = IconData(0xe1c0, fontFamily: _family);

  /// images
  static const IconData images = IconData(0xe5c4, fontFamily: _family);

  /// info
  static const IconData info = IconData(0xe0f9, fontFamily: _family);

  /// italic
  static const IconData italic = IconData(0xe0fb, fontFamily: _family);

  /// key-round
  static const IconData keyRound = IconData(0xe4a3, fontFamily: _family);

  /// languages
  static const IconData languages = IconData(0xe0fe, fontFamily: _family);

  /// layers-2
  static const IconData layers2 = IconData(0xe52a, fontFamily: _family);

  /// layout-grid
  static const IconData layoutGrid = IconData(0xe0ff, fontFamily: _family);

  /// link
  static const IconData link = IconData(0xe102, fontFamily: _family);

  /// list
  static const IconData list = IconData(0xe106, fontFamily: _family);

  /// list-ordered
  static const IconData listOrdered = IconData(0xe1d1, fontFamily: _family);

  /// log-in
  static const IconData logIn = IconData(0xe10d, fontFamily: _family);

  /// log-out
  static const IconData logOut = IconData(0xe10e, fontFamily: _family);

  /// megaphone
  static const IconData megaphone = IconData(0xe235, fontFamily: _family);

  /// menu
  static const IconData menu = IconData(0xe115, fontFamily: _family);

  /// message-circle
  static const IconData messageCircle = IconData(0xe116, fontFamily: _family);

  /// message-square
  static const IconData messageSquare = IconData(0xe117, fontFamily: _family);

  /// message-square-plus
  static const IconData messageSquarePlus =
      IconData(0xe40c, fontFamily: _family);

  /// messages-square
  static const IconData messagesSquare = IconData(0xe40d, fontFamily: _family);

  /// minus
  static const IconData minus = IconData(0xe11c, fontFamily: _family);

  /// palette
  static const IconData palette = IconData(0xe1dd, fontFamily: _family);

  /// paperclip
  static const IconData paperclip = IconData(0xe12d, fontFamily: _family);

  /// pencil
  static const IconData pencil = IconData(0xe1f9, fontFamily: _family);

  /// pilcrow
  static const IconData pilcrow = IconData(0xe3a3, fontFamily: _family);

  /// pin
  static const IconData pin = IconData(0xe259, fontFamily: _family);

  /// play
  static const IconData play = IconData(0xe13c, fontFamily: _family);

  /// plus
  static const IconData plus = IconData(0xe13d, fontFamily: _family);

  /// puzzle
  static const IconData puzzle = IconData(0xe29c, fontFamily: _family);

  /// refresh-cw
  static const IconData refreshCw = IconData(0xe145, fontFamily: _family);

  /// remove-formatting
  static const IconData removeFormatting =
      IconData(0xe3b3, fontFamily: _family);

  /// reply
  static const IconData reply = IconData(0xe22a, fontFamily: _family);

  /// scan-line
  static const IconData scanLine = IconData(0xe258, fontFamily: _family);

  /// search
  static const IconData search = IconData(0xe151, fontFamily: _family);

  /// search-x
  static const IconData searchX = IconData(0xe4ad, fontFamily: _family);

  /// send
  static const IconData send = IconData(0xe152, fontFamily: _family);

  /// settings-2
  static const IconData settings2 = IconData(0xe245, fontFamily: _family);

  /// share-2
  static const IconData share2 = IconData(0xe156, fontFamily: _family);

  /// shield-check
  static const IconData shieldCheck = IconData(0xe1ff, fontFamily: _family);

  /// square-pen
  static const IconData squarePen = IconData(0xe172, fontFamily: _family);

  /// strikethrough
  static const IconData strikethrough = IconData(0xe177, fontFamily: _family);

  /// table
  static const IconData table = IconData(0xe17d, fontFamily: _family);

  /// ticket
  static const IconData ticket = IconData(0xe20f, fontFamily: _family);

  /// timer
  static const IconData timer = IconData(0xe1e0, fontFamily: _family);

  /// trash-2
  static const IconData trash2 = IconData(0xe18e, fontFamily: _family);

  /// triangle-alert
  static const IconData triangleAlert = IconData(0xe193, fontFamily: _family);

  /// underline
  static const IconData underline = IconData(0xe19a, fontFamily: _family);

  /// undo-2
  static const IconData undo2 = IconData(0xe2a1, fontFamily: _family);

  /// user
  static const IconData user = IconData(0xe19f, fontFamily: _family);

  /// users
  static const IconData users = IconData(0xe1a4, fontFamily: _family);

  /// vote
  static const IconData vote = IconData(0xe3ad, fontFamily: _family);

  /// x
  static const IconData x = IconData(0xe1b2, fontFamily: _family);
}

/// 1.0px，和 Moodle 檔案類型圖示同粗。
@staticIconProvider
class LucideIconsThin {
  const LucideIconsThin._();

  static const String _family = 'LucideThin';

  /// clipboard-list
  static const IconData clipboardList = IconData(0xe086, fontFamily: _family);

  /// copy
  static const IconData copy = IconData(0xe09e, fontFamily: _family);

  /// download
  static const IconData download = IconData(0xe0b2, fontFamily: _family);

  /// file-question
  static const IconData fileQuestion = IconData(0xe322, fontFamily: _family);

  /// folder
  static const IconData folder = IconData(0xe0d7, fontFamily: _family);

  /// inbox
  static const IconData inbox = IconData(0xe0f7, fontFamily: _family);

  /// link
  static const IconData link = IconData(0xe102, fontFamily: _family);

  /// message-square
  static const IconData messageSquare = IconData(0xe117, fontFamily: _family);

  /// messages-square
  static const IconData messagesSquare = IconData(0xe40d, fontFamily: _family);

  /// tag
  static const IconData tag = IconData(0xe17f, fontFamily: _family);
}
