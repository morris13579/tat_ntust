# R8 保留規則。
#
# 舊版是早期的 Flutter v1 範本，19 行裡有 6 行在
# 保留整個 io.flutter 命名空間——實測那一行就釘住 8,586 個項目，佔全部保留
# 量的三分之一，而且**全部都是多餘的**。
#
# 判斷依據不是推理，是實際跑一次 release 建置之後讀
# build/app/outputs/mapping/release/configuration.txt（R8 真正吃進去的完整
# 規則）與 seeds.txt（真正被保留的項目）。想再驗一次就重跑一次 release 建置
# 然後讀那兩個檔案。
#
# ---------------------------------------------------------------------------
# 這個檔案**不需要**寫的東西，以及理由：
#
# * 任何 io.flutter.** 的保留。三件事已經蓋住它：
#     - aapt_rules.txt（AGP 從合併後的 manifest 自動產生）保留了
#       club.ntust.tat.MainActivity、widget.CourseWidgetProvider、
#       FlutterFirebaseMessagingBackgroundService / InitProvider / Receiver、
#       以及所有 FileProvider——都是 `{ <init>(); }`。
#     - flutter_proguard_rules.pro（Flutter 自己的 Gradle plugin 掛的）有
#       `-if class * implements ...FlutterPlugin -keep,allowshrinking,
#       allowobfuscation class <1>`，涵蓋外掛註冊。
#     - proguard-android-optimize.txt（同樣由 Flutter 的 plugin 掛上，所以
#       build.gradle 不必再寫 getDefaultProguardFile）處理 @Keep 註解。
#
#   曾經有個說法是「刪掉 io.flutter 的 blanket 會弄壞 FCM 背景推播」。那是
#   錯的：背景那三個元件宣告在 firebase_messaging 自己的 AndroidManifest
#   裡，由 aapt_rules 保留；唯一靠字串反射載入的 FlutterFirebaseAppRegistrar
#   由 firebase-components 自帶的
#   `-keep class * implements ...ComponentRegistrar` 保留。兩者都在
#   configuration.txt 裡看得到。
#
# * com.google.firebase.provider.FirebaseInitProvider。firebase-common 的
#   manifest 宣告了它，aapt_rules 已經保留。
#
# * 任何外掛自帶 consumer 規則的東西（file_picker 的 Apache Tika、
#   flutter_inappwebview、permission_handler 的 dexter……）。AAR 裡的
#   proguard.txt 會自動套用，在這裡重寫一次只會讓人以為是我們需要的。
# ---------------------------------------------------------------------------

## flutter_local_notifications 的排程資料模型
#
# 沒有這一行會壞掉的是：**排程通知**。這個外掛把排程存在 SharedPreferences
# 裡，用 gson 依欄位名序列化（FlutterLocalNotificationsPlugin.java:523-533
# 與 ScheduledNotificationReceiver）。欄位名被混淆之後，重開機或跳到排定
# 時間時反序列化會拿到一堆 null。
#
# 19.5.0 **沒有**自帶 consumer 規則，gson 2.10.1 的 jar 裡也沒有
# META-INF/proguard——兩邊都確認過，所以這一行只能寫在這裡。
#
# App 目前只用 `.show()`、沒有用 zonedSchedule，所以嚴格說今天走不到這條路。
# 留著是給「哪天有人加了排程通知」用的保險：那種壞法只在 release 出現，
# 而且不會有任何編譯期徵兆。範圍只框 models，不是整個 com.dexterous.**。
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

## 泛型簽章與註解
#
# 沒有這兩行會壞掉的是：任何靠反射看型別的序列化。gson 用 Signature 還原
# `List<NotificationDetails>` 這種泛型；沒有它會退化成 List<Object>。
-keepattributes Signature
-keepattributes *Annotation*

## 原生當機堆疊的可讀性
#
# 沒有這三行會壞掉的是：**Crashlytics 上 Java/Kotlin 的堆疊會變成亂碼**——
# 沒有檔名也沒有行號。Dart 那一側不受影響（R8 碰不到 libapp.so，Dart 的
# 混淆是 --obfuscate 另外做的），所以先前沒開壓縮時看不出缺這幾行。
#
# Crashlytics 的 Gradle plugin 會自動上傳 mapping.txt，所以混淆後的類別名
# 在後台會還原；但 SourceFile 與 LineNumberTable 屬性是另一回事，
# 沒有明確保留就會被丟掉。
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
