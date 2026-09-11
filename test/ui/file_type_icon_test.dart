import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_app/ui/components/file_type_icon.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SvgAssetLoader loaderOf(WidgetTester tester) =>
      tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
          as SvgAssetLoader;

  testWidgets('依檔名挑對應的 SVG', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FileTypeIcon(filename: 'week1.pdf')),
    );

    expect(loaderOf(tester).assetName, 'assets/image/files/pdf.svg');
  });

  testWidgets('mimetype 優先於檔名', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FileTypeIcon(filename: 'a.txt', mimetype: 'application/pdf'),
      ),
    );

    expect(loaderOf(tester).assetName, 'assets/image/files/pdf.svg');
  });

  testWidgets('認不得的檔案畫 unknown', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FileTypeIcon(filename: 'data.bin')),
    );

    expect(loaderOf(tester).assetName, 'assets/image/files/unknown.svg');
  });

  testWidgets('顏色預設跟 IconTheme 走，跟 Icon 一樣', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(color: Colors.red),
          child: FileTypeIcon(filename: 'a.pdf'),
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
        svg.colorFilter, const ColorFilter.mode(Colors.red, BlendMode.srcIn));
    expect(svg.width, 24);
    expect(svg.height, 24);
  });

  testWidgets('指定 color / size 時蓋掉預設', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FileTypeIcon(filename: 'a.pdf', color: Colors.blue, size: 32),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
        svg.colorFilter, const ColorFilter.mode(Colors.blue, BlendMode.srcIn));
    expect(svg.width, 32);
  });

  test('assets/image/files/ 裡每一個 SVG 都能被 flutter_svg 解析', () async {
    for (final name in FileIconUtils.iconNames) {
      final file = File(FileIconUtils.assetPath(name));
      expect(file.existsSync(), isTrue, reason: file.path);
      final bytes = await SvgFileLoader(file).loadBytes(null);
      expect(bytes.lengthInBytes, greaterThan(0), reason: file.path);
    }
  });
}
