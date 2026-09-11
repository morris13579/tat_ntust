import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/image_pick_service.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/other/components/user_profile.dart';
import 'package:flutter_app/ui/pages/other/other_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../helpers/fake_auth_session.dart';
import '../../helpers/fake_image_http.dart';
import '../../helpers/fake_image_pick_service.dart';
import '../../helpers/recording_ui.dart';
import '../../helpers/reset_statics.dart';
import '../../helpers/test_l10n.dart';

const String _customUrl =
    'https://moodle2.ntust.edu.tw/pluginfile.php/110/user/icon/boost/f1?rev=1';

/// 只給「載不出來」那一則用的網址。跟 [_customUrl] 分開是因為 ImageCache 是
/// 跨測試共用的：其他則用 withFakeImageHttp 把同一個網址載成功並留在快取裡，
/// 這一則就再也拿不到錯誤了。
const String _brokenUrl =
    'https://moodle2.ntust.edu.tw/pluginfile.php/110/user/icon/boost/f1?rev=x';
const String _defaultUrl =
    'https://moodle2.ntust.edu.tw/theme/image.php/boost/core/1/u/f1';

/// 不會自己去登入的 [MainController]，並記錄換頭貼被呼叫的次數與參數。
class _TestMainController extends MainController {
  int calls = 0;
  File? lastFile;

  /// changeAvatar 要回什麼。null 代表成功。
  String? nextError;

  // 刻意不呼叫 super.onInit()：那條路會去登入 Moodle，這一頁的測試不需要。
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}

  @override
  Future<String?> changeAvatar({File? file}) async {
    calls++;
    lastFile = file;
    return nextError;
  }
}

/// 「其他」頁上的頭貼：入口、動作選單、移除確認、各種提示。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestMainController controller;
  late RecordingUi ui;
  late FakeImagePickService picker;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    ConnectivityProbe.instance = FakeConnectivityProbe();
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    picker = FakeImagePickService();
    ImagePickService.instance = picker;
    controller = _TestMainController();
    Get.put<MainController>(controller);
  });

  tearDown(() async {
    Get.reset();
    AuthSession.instance = const UninstalledAuthSession();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ImagePickService.instance = const NoopImagePickService();
    await loadTestL10n();
  });

  void givenProfile(String pictureUrl) {
    controller.profile.value =
        MoodleProfileEntity(username: 'b11234567', userpictureurl: pictureUrl);
  }

  /// 換頭貼的入口移到「個人資訊」頁了（「更多」頁上的頭貼只是進去的入口，
  /// 沒有相機角標），所以這裡先從「更多」點進個人資訊再測。
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: OtherPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
  }

  Future<void> tapAvatar(WidgetTester tester) async {
    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
  }

  group('UserProfile', () {
    testWidgets('可點的頭貼帶著無障礙標籤與鉛筆角標', (tester) async {
      await withFakeImageHttp(() async {
        await tester.pumpWidget(GetMaterialApp(
          home: Scaffold(
            body: UserProfile(
              data: MoodleProfileEntity(userpictureurl: _customUrl),
              onAvatarTap: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.byType(InkWell)),
          matchesSemantics(
            label: R.current.avatarChange,
            isButton: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        expect(find.byIcon(LucideIcons.camera), findsOneWidget);
        // 圖載到了就不該再蓋一個預設圖示上去。
        expect(find.byIcon(LucideIcons.user), findsNothing);
      });
    });

    testWidgets('沒有 onAvatarTap 就不可點，也沒有角標（沿用舊行為）', (tester) async {
      await withFakeImageHttp(() async {
        await tester.pumpWidget(GetMaterialApp(
          home: Scaffold(
            body: UserProfile(
                data: MoodleProfileEntity(userpictureurl: _customUrl)),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(InkWell), findsNothing);
        expect(find.byIcon(LucideIcons.camera), findsNothing);
      });
    });

    testWidgets('進行中時不可點，並畫一個對應進度的轉圈', (tester) async {
      await withFakeImageHttp(() async {
        await tester.pumpWidget(GetMaterialApp(
          home: Scaffold(
            body: UserProfile(
              data: MoodleProfileEntity(userpictureurl: _customUrl),
              onAvatarTap: () {},
              progress: 0.4,
            ),
          ),
        ));
        await tester.pump();

        expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
        final ring = tester.widgetList<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        expect(ring, hasLength(1));
        expect(ring.single.value, 0.4);
      });
    });

    testWidgets('還沒有進度時是不定值的轉圈，不是一段長度為零的弧', (tester) async {
      await withFakeImageHttp(() async {
        await tester.pumpWidget(GetMaterialApp(
          home: Scaffold(
            body: UserProfile(
              data: MoodleProfileEntity(userpictureurl: _customUrl),
              onAvatarTap: () {},
              progress: 0,
            ),
          ),
        ));
        await tester.pump();

        final ring = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        expect(ring.value, isNull);
      });
    });

    testWidgets('圖載不出來時退回使用者圖示，而且不把例外丟出去', (tester) async {
      await withFailingImageHttp(() async {
        await tester.pumpWidget(GetMaterialApp(
          home: Scaffold(
            body: UserProfile(
                data: MoodleProfileEntity(userpictureurl: _brokenUrl)),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(LucideIcons.user), findsOneWidget);
        // onBackgroundImageError 有接住，畫面不會因為一張頭貼而紅屏。
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('動作選單', () {
    testWidgets('點頭貼會開出三個選項（有自訂頭貼時）', (tester) async {
      givenProfile(_customUrl);
      await withFakeImageHttp(() async {
        await pumpPage(tester);
        await tapAvatar(tester);

        expect(find.text(R.current.avatarFromGallery), findsOneWidget);
        expect(find.text(R.current.avatarTakePhoto), findsOneWidget);
        expect(find.text(R.current.avatarRemove), findsOneWidget);
        // dialog-spec §06-A 把「取消」那一列拿掉了：下滑與點遮罩都能關，
        // 再放一列取消是重複。
        expect(find.text(R.current.cancel), findsNothing);
      });
    });

    testWidgets('用主題預設圖時不顯示「移除」', (tester) async {
      givenProfile(_defaultUrl);
      await withFakeImageHttp(() async {
        await pumpPage(tester);
        await tapAvatar(tester);

        expect(find.text(R.current.avatarFromGallery), findsOneWidget);
        expect(find.text(R.current.avatarRemove), findsNothing);
      });
    });

    testWidgets('點遮罩關掉選單什麼都不做', (tester) async {
      givenProfile(_customUrl);
      await withFakeImageHttp(() async {
        await pumpPage(tester);
        await tapAvatar(tester);
        // 選單沒有「取消」列，所以從遮罩關——回傳 null 代表沒選。
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text(R.current.avatarFromGallery), findsNothing);
        expect(controller.calls, 0);
        expect(picker.calls, isEmpty);
        expect(ui.toasts, isEmpty);
      });
    });
  });

  group('移除', () {
    Future<void> openRemove(WidgetTester tester) async {
      givenProfile(_customUrl);
      await pumpPage(tester);
      await tapAvatar(tester);
      await tester.tap(find.text(R.current.avatarRemove));
      await tester.pumpAndSettle();
    }

    testWidgets('先問過才動手，按取消時一次都不呼叫', (tester) async {
      await withFakeImageHttp(() async {
        await openRemove(tester);
        expect(find.text(R.current.avatarRemoveConfirm), findsOneWidget);

        await tester.tap(find.text(R.current.cancel));
        await tester.pumpAndSettle();

        expect(controller.calls, 0);
      });
    });

    testWidgets('確認後以 file=null 呼叫，並提示已移除', (tester) async {
      await withFakeImageHttp(() async {
        await openRemove(tester);
        await tester.tap(find.text(R.current.sure));
        await tester.pumpAndSettle();

        expect(controller.calls, 1);
        expect(controller.lastFile, isNull);
        expect(ui.toasts, [R.current.avatarRemoved]);
      });
    });
  });

  group('挑圖', () {
    Future<void> chooseGallery(WidgetTester tester) async {
      givenProfile(_customUrl);
      await pumpPage(tester);
      await tapAvatar(tester);
      await tester.tap(find.text(R.current.avatarFromGallery));
      await tester.pumpAndSettle();
    }

    testWidgets('使用者取消挑圖不是錯誤：不呼叫也不提示', (tester) async {
      await withFakeImageHttp(() async {
        picker.next = null;
        await chooseGallery(tester);

        expect(picker.calls, [ImagePickSource.gallery]);
        expect(controller.calls, 0);
        expect(ui.toasts, isEmpty);
      });
    });

    testWidgets('挑到圖就換，成功時提示已更新', (tester) async {
      await withFakeImageHttp(() async {
        picker.next = File('${Directory.systemTemp.path}/x.jpg');
        await chooseGallery(tester);

        expect(controller.calls, 1);
        expect(controller.lastFile, isNotNull);
        expect(ui.toasts, [R.current.avatarUpdated]);
      });
    });

    testWidgets('換失敗時提示的是 controller 給的那句話', (tester) async {
      await withFakeImageHttp(() async {
        picker.next = File('${Directory.systemTemp.path}/x.jpg');
        controller.nextError = R.current.avatarProfileLocked;
        await chooseGallery(tester);

        expect(ui.toasts, [R.current.avatarProfileLocked]);
      });
    });

    testWidgets('相機權限被拒時提示，而且不呼叫 controller', (tester) async {
      await withFakeImageHttp(() async {
        picker.failure = ImagePickFailureReason.cameraDenied;
        givenProfile(_customUrl);
        await pumpPage(tester);
        await tapAvatar(tester);
        await tester.tap(find.text(R.current.avatarTakePhoto));
        await tester.pumpAndSettle();

        expect(picker.calls, [ImagePickSource.camera]);
        expect(controller.calls, 0);
        expect(ui.toasts, [R.current.avatarCameraDenied]);
      });
    });

    testWidgets('相簿權限被拒有自己的提示', (tester) async {
      await withFakeImageHttp(() async {
        picker.failure = ImagePickFailureReason.galleryDenied;
        await chooseGallery(tester);

        expect(ui.toasts, [R.current.avatarGalleryDenied]);
      });
    });
  });
}
