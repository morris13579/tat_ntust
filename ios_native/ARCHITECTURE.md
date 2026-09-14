# ios_native 架構

iOS 原生版：SwiftUI 畫面 + 一顆沒有畫面的 `FlutterEngine` 跑 `lib/` 的 Dart 核心。
Android 維持 Flutter，兩邊共用同一份核心、同一份翻譯、同一份圖示字體。
這份只講 Swift 端的資料夾與寫法；整體架構與 Swift／Dart 怎麼溝通見 `docs/IOS_NATIVE_ARCHITECTURE.md`，
不綁本專案的通用做法見 `docs/FLUTTER_NATIVE_IOS_GUIDE.md`。

**引擎只能有一顆**：`AppAuthSession` 的 in-flight 表是 process 級的 static，多一顆就多一份登入狀態。

## 分層

```
TATNative/
├── App/            @main、AppDelegate、AppEnvironment（唯一的依賴容器）、RootView、MainTabView、L10n
├── Features/       一個畫面一個資料夾：XxxView ＋ XxxModel
│   ├── Assignment/     作業詳情與繳交
│   ├── Browser/
│   ├── Calendar/
│   ├── Classroom/
│   ├── CourseDetail/   課程資訊與修課同學
│   ├── CourseMoodle/   課程 Moodle：檔案、公告、作業分頁與模組頁
│   ├── CourseSearch/
│   ├── CourseTable/
│   ├── Forum/          討論串、回覆、編輯
│   ├── Inbox/          通知中心、TAT 公告全文、啟動時的公告與更新提示
│   ├── Login/
│   ├── Mail/           信箱：設定、清單與搜尋、信件內頁、寫信與寄件匣
│   ├── MoodleSetting/
│   ├── More/
│   ├── PrivacyPolicy/
│   ├── Quiz/
│   ├── Score/
│   ├── Simulation/     模擬排課
│   └── SubSystem/
├── CoreUI/         核心要求的 UI：對話框、toast、進度框、登入用的 WebView sheet
├── DesignSystem/   品牌色、按鈕樣式、Lucide 圖示、共用元件
├── Platform/       系統服務：分享面板、QR 產生、相機與相簿掃描、手電筒、下載與預覽、挑檔、所見即所得編輯器
├── Web/            WKWebView：cookie、一次性載頁、給核心驅動的 WebView
├── Widgets/        小工具的資料格式、時間判斷與各尺寸畫面，App 與小工具 extension 都編
├── Core/           Dart 核心的邊界：引擎、CoreClient、CoreUiHost、CoreResult、Pigeon 產物
├── Debug/          開發人員選項（只在 Debug 建置）與探針
└── Resources/      Info.plist、*.lproj 字串、Generated/（L10n 與 Lucide 常數）
```

| 資料夾 | 可以依賴 |
| --- | --- |
| `App/` | 全部 |
| `Features/` | `DesignSystem`、`CoreUI`、`Platform`、`Core` |
| `CoreUI/` | `DesignSystem`、`Web`、`Core` 的資料型別 |
| `DesignSystem/` | 無 |
| `Platform/` | 無（包 UIKit／VisionKit 這類系統 API 與 Firebase Analytics，不認得核心） |
| `Web/` | 無（不認得 Pigeon，只提供 Swift 的回呼） |
| `Widgets/` | `DesignSystem` 的 Lucide 與課表配色、`L10n`（extension 也會編，不可以碰核心與 App 專用的 API） |

`ios_native/TATWidget/` 是小工具 extension 自己的檔案：`@main` 的 WidgetBundle、timeline provider、Info.plist 與 entitlements。
其餘向 App 借，清單在 `generate_project.rb` 的 `WIDGET_BORROWS`。
| `Core/` | `CoreUiHost` 轉給 `CoreUI` 與 `Web`，其餘只依賴 Pigeon 產物 |

## 規則

1. **Pigeon 的 API 只在 `Core/` 裡呼叫。** 畫面用 `CoreClient` 的 async 函式；sealed 的結果一拿到
   就轉成 `CoreResult`（Pigeon 把 sealed 產生成 protocol，switch 沒有窮盡檢查）。產生的資料型別
   （`CourseTable`、`SavedCredentials`…）可以直接用。
   每一支呼叫都包在 `pigeonCall` 裡：核心起來之前在 `CoreGate` 排隊，直接呼叫的話同一支方法送兩次會丟掉一則。
   畫面不等引擎，啟動時照 `LaunchHint`（上一次核心的回答）進畫面，細節見 `docs/IOS_NATIVE_ARCHITECTURE.md`。
2. **判斷留在 Dart。** 判準、重試、快取、登入流程都在核心；Swift 只畫畫面、呼叫平台 API。
   要加新判斷時先問「Android 要不要一樣」——要的話就寫在 Dart。
3. **狀態用 Observation。** 畫面狀態放在 `@MainActor @Observable` 的 `XxxModel`，依賴由父畫面從
   `AppEnvironment` 傳進建構子；不用 `ObservableObject`。
4. **介面照 iOS 的習慣。** 內容與流程對齊 Flutter 版；字級用 Dynamic Type 的文字樣式、顏色用語意色、
   主要按鈕用 `prominentButtonStyle()`（iOS 26 是 Liquid Glass），品牌色只當 tint。
   品牌色 `Color.tatBrand` 跟著「主題顏色」的設定換（`BrandPalette`）：只在 view 裡讀，不要存進 `static let` 或 UIKit 外觀，
   否則換色時不會更新。
   例外：toast 的版面維持 Flutter 版的膠囊；底色跟著深淺色，iOS 26 是 Liquid Glass。
   - sheet 用 `SheetStack`（系統的導覽列、把手與圓角，內容通常是 `List`）：高度跟著內容，上下留白也由它給，
     內容本身不要再加上下 padding。幾個動作的選單用 `Menu` 或 `confirmationDialog`，不做成 sheet。
     相鄰但無關的導覽列按鈕在 iOS 26 用 `ToolbarSpacer` 分成兩塊玻璃。
     `confirmationDialog` 掛在被點的那個 view 上：iOS 26 從掛的地方跳出來，掛在整頁會指到別處。
   - 字級照 HIG 的文字樣式分工，不照 Flutter 版的字級：列的主文字 Body、第二行 Subheadline、補充說明 Footnote、
     Caption 只給籤、圖例與密集格線；不在 `List` 裡的段標題用 `Font.sectionHeader`（和清單段標題一樣大）。
   - 圖示不要淡到看不清：不用細筆畫，列首圖示用品牌色、說明性的小圖示用 secondary，不用 tertiary。
   - 分組的圓角一律用 `ListGroupShape`（iOS 26 是 26pt，和系統分組清單同一種圓）：自製的分組列 `GroupedRowShape`、
     卡片與內容裡裁成卡片的 `NoticeBar` 用 `ListGroupShape.card`。輸入框、籤、按鈕與格線的格子不算。
   - 導覽列上的按鈕（圖示與文字）一律 `toolbarButtonTint()`：iOS 26 的系統返回鍵是單色的，整條導覽列跟著用文字主色；
     有字的主要動作用 `prominentButtonStyle()`。
   - 返回鍵一律是同一張 Lucide 箭頭：系統返回鍵在啟動時換掉（`BackIndicator`）；要先攔下返回的頁面隱藏系統返回鍵、
     改放 `BackButton`，不要自己畫箭頭。
   - 分頁列選到的分頁用實心圖示：`LucideIcon.filledUIImage()`（Lucide 沒有實心版，從字形推出來）設成
     `UITabBarItem.selectedImage`，Liquid Glass 拖曳經過的那一格也是實心的。
   - 推進來的頁面要搜尋時用 `SystemSearchBar`，以 `pinnedTopBar` 釘在內容頂端；導覽列的 `.searchable` 只用在分頁的根頁面與 sheet：
     推頁時系統搜尋列的背景要等動畫結束才出現。`.searchable` 一律 `placement: .navigationBarDrawer(displayMode: .always)`，
     不指定會跟著清單捲走。兩種搜尋列都不墊底色，內容捲到後面時由系統淡出；開始打字時旁邊都有關閉鈕，按了清空關鍵字。
   - 載入中會是空的 `List` 要自己墊 `systemGroupedBackground`（`scrollContentBackground(.hidden)`）：
     空清單的底是白的，載完變成灰底會閃一下。
   - 捲動內容要能捲到導覽列、分頁列與釘住的列後面：底部列用 `pinnedBottomBar`，清單上方不跟著捲走的一列（篩選籤、搜尋列）用
     `pinnedTopBar`。page 樣式的 `TabView` 會把每一頁裁在安全區域裡，要掛 `extendsUnderBars`、每一頁的捲動內容掛 `pageScrollInset`。
     `TabView` 上方要釘一列（成績的學期籤）時，`pinnedTopBar` 掛在 `extendsUnderBars` 外面，不要用 `safeAreaInset` 疊上去：
     每一頁量不到那段高度，內容會被蓋住。Moodle 課程頁的分頁鈕照舊和 `TabView` 排進同一個 `VStack`（檔案頁自己有釘住的搜尋列），
     內容不會透到分頁鈕後面。
5. **文字一律走 `L10n`，不寫字面值。** key 與翻譯就是 `lib/l10n/*.arb`，名稱與 `R.current.<key>` 相同。
   新字串加進兩個 ARB，兩邊一起重產。語言跟著核心的設定走，不跟系統。
6. **圖示一律用 Lucide**（`LucideImage(Lucide.eyeOff)`），和 Flutter 同一份字體與碼位，不用 SF Symbols。
7. **產生的檔案不要手改**：`Core/Generated/`、`Resources/Generated/`、`Resources/*.lproj/`。
8. **專案檔是產出物。** 資料夾就是 Xcode 群組；新增檔案後重跑產生腳本，不必手動列清單。

`Debug/` 不受 5 約束：開發人員選項照 Flutter 版的 `DevPage` 不進翻譯檔，探針是暫時的。

推播與 Analytics 走原生的 Firebase SDK，不走 Flutter 外掛（見 `Core/CorePluginRegistrant.m`）；
推播要的 `aps-environment` 只在實機建置掛上（`Resources/TATNative.entitlements`）。

核心自己發生的事走 `@HostApi` 推過來，收在 `Core/` 讓畫面讀：上傳進度在 `TransferCenter`；信箱的清單狀態、
寄件匣倒數、新信與寄送結果在 `MailCenter`（信箱清單照 `MailController` 的每一步變動推，不是一問一答）。

小工具跑不了核心：課表由 Dart 的 `TatWidgetApi` 準備好（自己每一學期、連堂併好），看哪一學期是小工具自己的設定（`TimetableWidgetIntent`）；
`App/WidgetSync` 在 App 回到背景、
啟動完成與登出時寫進 App Group（`TimetableSnapshotStore`），內容有變才叫 `WidgetCenter` 重排；小工具只照星期與時間查表。
模擬器建置沒有 entitlements，也就沒有 App Group，小工具拿不到課表：版面用 `TAT_WIDGET_PREVIEW=1` 啟動 App 來看，
各尺寸的 PNG 寫在 App 的 Documents/widget-preview/（`Debug/WidgetPreview.swift`）。

## 新增一個畫面

1. 建 `Features/<名稱>/<名稱>View.swift` 與 `<名稱>Model.swift`。
2. 需要核心的資料：在 `pigeons/core_api.dart` 為這個畫面加一個 `@FlutterApi`（例如 `TatCourseTableApi`）→
   `lib/src/native/<名稱>_bridge.dart` 實作並在 `core_main.dart` 安裝 → `Core/<名稱>Client.swift` 用
   `pigeonCall` 包成 async。橋接只翻譯，判斷沿用既有的 controller／util（課表就是 `CourseModel` 與
   `CourseTableControl`），而且要能在沒有 Flutter UI 的情況下跑——碰到 `Get.theme` 之類的就先把它拆開。
3. 需要新字串或圖示：改兩個 ARB、在 Swift 寫 `Lucide.xxx`。
4. 重產。Flutter 的字串照舊由 flutter_intl 產生（IDE 外掛，或下面的 `intl_utils`，第一次要先
   `puro dart pub global activate intl_utils`）：

```bash
puro dart run pigeon --input pigeons/core_api.dart
puro dart pub global run intl_utils:generate
python3 tool/gen_ios_l10n.py
python3 tool/gen_lucide_icons.py
ruby ios_native/generate_project.rb && (cd ios_native && pod install)
```

## 建置與上架

- 原生版的 `App.framework` 只編 `lib/core_main.dart`（`generate_project.rb` 的 `FLUTTER_TARGET`）：畫面都在 Swift，
  `lib/ui/` 不進 App。`core_main.dart` 要有 `main()` 才當得了建置目標；Flutter 版的 Runner 與 Android 照舊用 `lib/main.dart`。
- 版號寫在 `generate_project.rb` 的 `MARKETING_VERSION`／`BUILD_NUMBER`，App 與小工具的 `Info.plist` 都讀它們；兩者必須相同。
- 上架包：`tool/release.sh ios-native`，加 `--upload` 直接送 App Store Connect。Crashlytics 的 dSYM 只在封存時上傳。
- Swift 用到 required reason API（`UserDefaults`、檔案時間戳、開機時間、剩餘空間）要寫進 `Resources/PrivacyInfo.xcprivacy`，
  沒宣告的上傳會被 App Store Connect 退件。
