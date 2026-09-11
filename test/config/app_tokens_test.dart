import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 相對亮度。語意色是自己推導出來的，M3 那套保證不涵蓋它們，
/// 所以對比要自己量。
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// 每個欄位攤平成一個列表，用來確認 copyWith / lerp 沒有漏掉哪一個。
List<Object> _fields(TatTokens t) => [
      t.warning,
      t.onWarning,
      t.warningContainer,
      t.info,
      t.onInfo,
      t.infoContainer,
      t.success,
      t.onSuccess,
      t.successContainer,
      t.scoreFail,
      t.scoreFailContainer,
      t.statusPending,
      t.statusLate,
      t.statusGraded,
      t.statusStale,
    ];

/// 同樣攤平，但把 record 拆成顏色，好做有容差的比較。
List<Color> _colors(TatTokens t) => [
      t.warning,
      t.onWarning,
      t.warningContainer,
      t.info,
      t.onInfo,
      t.infoContainer,
      t.success,
      t.onSuccess,
      t.successContainer,
      t.scoreFail,
      t.scoreFailContainer,
      t.statusPending.bg,
      t.statusPending.fg,
      t.statusLate.bg,
      t.statusLate.fg,
      t.statusGraded.bg,
      t.statusGraded.fg,
      t.statusStale.bg,
      t.statusStale.fg,
    ];

/// 8-bit 通道差 1 以內就算同一色，避開 lerp 的浮點誤差。
bool _sameColor(Color a, Color b) =>
    ((a.a - b.a).abs() * 255 <= 1) &&
    ((a.r - b.r).abs() * 255 <= 1) &&
    ((a.g - b.g).abs() * 255 <= 1) &&
    ((a.b - b.b).abs() * 255 <= 1);

const _seeds = <String, Color>{
  'fallback blue': Color(0xFF1565C0),
  'm3 purple': Color(0xFF6750A4),
  'green': Color(0xFF386A20),
  'red': Color(0xFFB3261E),
};

TatTokens _tokensFor(Color seed, Brightness brightness) => TatTokens.from(
      ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    );

void main() {
  group('TatTokens 對比', () {
    for (final entry in _seeds.entries) {
      for (final brightness in Brightness.values) {
        final label = '${entry.key} / ${brightness.name}';
        final tokens = _tokensFor(entry.value, brightness);

        test('$label：語意色對自己的 container 至少 4.5:1', () {
          final pairs = <String, (Color, Color)>{
            'warning': (tokens.warning, tokens.warningContainer),
            'info': (tokens.info, tokens.infoContainer),
            'success': (tokens.success, tokens.successContainer),
            'scoreFail': (tokens.scoreFail, tokens.scoreFailContainer),
          };
          pairs.forEach((name, pair) {
            expect(
              _contrast(pair.$1, pair.$2),
              greaterThanOrEqualTo(4.5),
              reason: '$label $name 對 container 的對比不足',
            );
          });
        });

        test('$label：on 色對語意色至少 4.5:1', () {
          final pairs = <String, (Color, Color)>{
            'onWarning': (tokens.onWarning, tokens.warning),
            'onInfo': (tokens.onInfo, tokens.info),
            'onSuccess': (tokens.onSuccess, tokens.success),
          };
          pairs.forEach((name, pair) {
            expect(
              _contrast(pair.$1, pair.$2),
              greaterThanOrEqualTo(4.5),
              reason: '$label $name 對比不足',
            );
          });
        });

        test('$label：StatusPill 每一組前景對底色至少 4.5:1', () {
          final pairs = <String, ({Color bg, Color fg})>{
            'statusPending': tokens.statusPending,
            'statusLate': tokens.statusLate,
            'statusGraded': tokens.statusGraded,
            'statusStale': tokens.statusStale,
          };
          pairs.forEach((name, pair) {
            expect(
              _contrast(pair.fg, pair.bg),
              greaterThanOrEqualTo(4.5),
              reason: '$label $name 對比不足',
            );
          });
        });
      }
    }
  });

  group('TatTokens 推導', () {
    test('換一個 seed 就換一組顏色，不是寫死的色票', () {
      final a = _tokensFor(_seeds['fallback blue']!, Brightness.light);
      final b = _tokensFor(_seeds['green']!, Brightness.light);
      expect(a.warning, isNot(b.warning));
      expect(a.info, isNot(b.info));
      expect(a.success, isNot(b.success));
      // scoreFail 不在這裡比：它的色相取自 scheme.error，而 M3 的 error 不管
      // 種子是什麼都是同一個紅。它跟著 scheme 走這件事由下一個測試守。
    });

    test('scoreFail 跟著 scheme 的 error 色相走', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: _seeds['m3 purple']!,
        brightness: Brightness.light,
      );
      final tokens = TatTokens.from(scheme);
      final errorHue = HSLColor.fromColor(scheme.error).hue;
      final failHue = HSLColor.fromColor(tokens.scoreFail).hue;
      expect((failHue - errorHue).abs(), lessThan(6));
    });
  });

  group('TatTokens copyWith / lerp', () {
    final a = _tokensFor(_seeds['fallback blue']!, Brightness.light);
    final b = _tokensFor(_seeds['green']!, Brightness.dark);

    test('先確認兩組每個欄位都不一樣，下面的檢查才有意義', () {
      final fa = _fields(a);
      final fb = _fields(b);
      for (var i = 0; i < fa.length; i++) {
        expect(fa[i], isNot(fb[i]), reason: '第 $i 個欄位兩組相同');
      }
    });

    test('copyWith 不給參數就原樣回來', () {
      expect(_fields(a.copyWith()), _fields(a));
    });

    test('copyWith 涵蓋每一個欄位', () {
      final copied = a.copyWith(
        warning: b.warning,
        onWarning: b.onWarning,
        warningContainer: b.warningContainer,
        info: b.info,
        onInfo: b.onInfo,
        infoContainer: b.infoContainer,
        success: b.success,
        onSuccess: b.onSuccess,
        successContainer: b.successContainer,
        scoreFail: b.scoreFail,
        scoreFailContainer: b.scoreFailContainer,
        statusPending: b.statusPending,
        statusLate: b.statusLate,
        statusGraded: b.statusGraded,
        statusStale: b.statusStale,
      );
      expect(_fields(copied), _fields(b));
    });

    test('lerp(null) 回自己', () {
      expect(_fields(a.lerp(null, 0.5)), _fields(a));
    });

    test('lerp 涵蓋每一個欄位：t=0 是 a、t=1 是 b', () {
      final ca = _colors(a);
      final cb = _colors(b);
      final at0 = _colors(a.lerp(b, 0));
      final at1 = _colors(a.lerp(b, 1));
      for (var i = 0; i < ca.length; i++) {
        expect(_sameColor(at0[i], ca[i]), isTrue, reason: '第 $i 個欄位 t=0 不是 a');
        expect(_sameColor(at1[i], cb[i]), isTrue, reason: '第 $i 個欄位沒有被 lerp');
      }
    });

    test('lerp 中間值每一個欄位都真的動了', () {
      final ca = _colors(a);
      final cb = _colors(b);
      final mid = _colors(a.lerp(b, 0.5));
      for (var i = 0; i < mid.length; i++) {
        expect(_sameColor(mid[i], ca[i]), isFalse, reason: '第 $i 個欄位停在 a');
        expect(_sameColor(mid[i], cb[i]), isFalse, reason: '第 $i 個欄位停在 b');
      }
    });
  });
}
