import 'dart:convert';

import 'package:flutter_app/src/util/rich_editor_bridge_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// 編輯器橋接的純函式規格。這一支守的是「貼文 HTML 進到 WebView 的那一步」，
/// 而貼文是別人寫的——所有例子都要當成惡意輸入看。
void main() {
  group('jsStringLiteral', () {
    const corpus = [
      '</script><script>alert(1)</script>',
      '\u2028',
      '\u2029',
      '"',
      r'\',
      '\n',
      '&amp;',
      '\u{1F600}',
      // 落單的高位代理：jsonEncode 也要能原樣還原。
      '\uD800',
      '',
      '<p>期中考範圍如圖 <b>重要</b></p>',
    ];

    test('每一個輸入都 round-trip 得回來', () {
      for (final s in corpus) {
        expect(jsonDecode(RichEditorBridgeUtils.jsStringLiteral(s)), s,
            reason: '無法還原：${s.codeUnits}');
      }
    });

    test('輸出裡沒有原始的 < > & U+2028 U+2029，也沒有原始換行', () {
      for (final s in corpus) {
        final out = RichEditorBridgeUtils.jsStringLiteral(s);
        for (final forbidden in ['<', '>', '&', '\u2028', '\u2029', '\n']) {
          expect(out.contains(forbidden), isFalse,
              reason: '$out 裡出現了 $forbidden');
        }
      }
    });
  });

  group('buildSetContentCall', () {
    test('內容想跳出字串常值也跳不出去', () {
      const evil = '");window.x=1;//';
      final call = RichEditorBridgeUtils.buildSetContentCall(evil);

      expect('window.__tatEditor.setContent('.allMatches(call).length, 1);
      final argument =
          call.substring(call.indexOf('(') + 1, call.lastIndexOf(')'));
      expect(jsonDecode(argument), evil);
    });
  });

  group('buildCommandCall', () {
    test('每一個指令都只組得出固定的字面值，呼叫端的字串永遠進不來', () {
      final calls = {
        for (final c in EditorCommand.values)
          RichEditorBridgeUtils.buildCommandCall(c),
      };
      expect(calls.length, EditorCommand.values.length);
      for (final call in calls) {
        expect(
            RegExp(r'^window\.__tatEditor\.exec\("[A-Za-z0-9]+"\);$')
                .hasMatch(call),
            isTrue,
            reason: call);
      }
    });
  });

  group('parseEditorState', () {
    test('任何壞掉的 payload 都回空集合而不是拋', () {
      for (final raw in <Object?>[
        null,
        42,
        'bold',
        <Object?>[],
        {'bold': 'yes'},
        {'nope': true},
        {'block': 'script'},
        {1: true},
        {
          'a': {
            'b': {'c': true}
          }
        },
      ]) {
        expect(RichEditorBridgeUtils.parseEditorState(raw), isEmpty,
            reason: '$raw');
      }
    });

    test('只留白名單內的 key，block 也要在白名單裡', () {
      expect(
        RichEditorBridgeUtils.parseEditorState({
          'bold': true,
          'italic': false,
          'block': 'h3',
          'somethingElse': true,
        }),
        {'bold', 'h3'},
      );
    });
  });

  group('buildThemeCall', () {
    test('深淺各對到一個 data-theme', () {
      expect(RichEditorBridgeUtils.buildThemeCall(dark: true),
          contains('"data-theme", "dark"'));
      expect(RichEditorBridgeUtils.buildThemeCall(dark: false),
          contains('"data-theme", "light"'));
    });

    // 底色由 Flutter 畫在透明的 WebView 後面，會跟著系統換深色立刻重畫；
    // 字色在頁面裡，所以這一句一定要能重推，不是握手時推一次就算了。
    test('是一句可以重複執行的 setAttribute', () {
      expect(RichEditorBridgeUtils.buildThemeCall(dark: true),
          startsWith('document.documentElement.setAttribute('));
      expect(RichEditorBridgeUtils.buildThemeCall(dark: true), endsWith(');'));
    });
  });
}
