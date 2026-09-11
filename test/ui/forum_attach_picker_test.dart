import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/file_pick_service.dart';
import 'package:flutter_app/src/service/image_pick_service.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_attach_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_image_pick_service.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 討論區附件的來源選單。
///
/// 為什麼一定要有它：iOS 上 `FileType.any` 是 UIDocumentPickerViewController，
/// 相機膠卷不是「檔案」的 provider——只留檔案挑選器的話，剛拍的白板照片在
/// App 內**看不到**，使用者得先離開 App 把它匯出到「檔案」；相機更是完全
/// 沒有入口。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingUi ui;
  late FakeImagePickService images;
  late _RecordingFilePickService files;
  late Directory temp;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    temp = Directory.systemTemp.createTempSync('tat_forum_pick');
    images = FakeImagePickService();
    files = _RecordingFilePickService();
    ImagePickService.instance = images;
    FilePickService.instance = files;
  });

  tearDown(() {
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ImagePickService.instance = const NoopImagePickService();
    FilePickService.instance = const NoopFilePickService();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File local(String name) {
    final f = File('${temp.path}/$name')..writeAsBytesSync(const [65]);
    return f;
  }

  /// 開一頁只有一顆鈕的畫面，按下去就叫 [pickForumAttachments]。
  Future<List<File>?> open(WidgetTester tester, {int remaining = 2}) async {
    List<File>? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked =
                  await pickForumAttachments(context, remaining: remaining);
            },
            child: const Text('attach'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('attach'));
    await tester.pumpAndSettle();
    return picked;
  }

  Future<List<File>?> choose(WidgetTester tester, String label,
      {int remaining = 2}) async {
    final picked = await open(tester, remaining: remaining);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('三個來源都在：相機、相簿、檔案', (tester) async {
    await open(tester);

    expect(find.text(R.current.forumAttachFromCamera), findsOneWidget);
    expect(find.text(R.current.forumAttachFromGallery), findsOneWidget);
    expect(find.text(R.current.forumAttachFromFiles), findsOneWidget);
  });

  testWidgets('拍照走 image_picker 的相機，而且**不縮圖**——白板照片縮到 1024 就讀不出字了',
      (tester) async {
    images.next = local('photo.jpg');

    await choose(tester, R.current.forumAttachFromCamera);
    await tester.pumpAndSettle();

    expect(images.calls, [ImagePickSource.camera]);
    expect(images.lastMaxEdge, isNull);
    expect(images.lastQuality, isNull);
    expect(files.limits, isEmpty);
  });

  testWidgets('從相簿選擇走 image_picker 的相簿', (tester) async {
    images.next = local('photo.jpg');

    await choose(tester, R.current.forumAttachFromGallery);
    await tester.pumpAndSettle();

    expect(images.calls, [ImagePickSource.gallery]);
  });

  testWidgets('選擇檔案走檔案挑選器，還能挑幾個照樣傳下去', (tester) async {
    files.next = [local('a.pdf')];

    await choose(tester, R.current.forumAttachFromFiles, remaining: 3);
    await tester.pumpAndSettle();

    expect(files.limits, [3]);
    expect(images.calls, isEmpty);
  });

  testWidgets('按取消：兩個挑選器都不叫，也不吐訊息', (tester) async {
    await choose(tester, R.current.cancel);

    expect(images.calls, isEmpty);
    expect(files.limits, isEmpty);
    expect(ui.toasts, isEmpty);
  });

  testWidgets('相機權限被拒：吐一句話，回空清單（不是丟例外給呼叫端）', (tester) async {
    images.failure = ImagePickFailureReason.cameraDenied;

    await choose(tester, R.current.forumAttachFromCamera);
    await tester.pumpAndSettle();

    expect(ui.toasts, [R.current.avatarCameraDenied]);
  });

  testWidgets('已經滿了（remaining 0）連選單都不開', (tester) async {
    await open(tester, remaining: 0);

    expect(find.text(R.current.forumAttachFromCamera), findsNothing);
  });
}

class _RecordingFilePickService implements FilePickService {
  List<File> next = const [];
  final limits = <int>[];

  @override
  Future<List<File>> pick({
    required int limit,
    List<String> extensions = const [],
  }) async {
    limits.add(limit);
    return next;
  }
}
