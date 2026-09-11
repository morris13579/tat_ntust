import 'package:flutter/material.dart';

/// `ColorScheme` 表達不了的語意色與形狀常數。
///
/// 所有顏色都從當下的 scheme 推導，不寫死色票——配色要跟著使用者的桌布走，
/// 寫死一組 hex 等於把 dynamic_color 廢掉。設計稿上的圓點色只當作「色相從哪裡
/// 起算」的基準，明度與彩度由下面的配方決定，才守得住對比。
@immutable
class TatTokens extends ThemeExtension<TatTokens> {
  const TatTokens({
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.scoreFail,
    required this.scoreFailContainer,
    required this.page,
    required this.card,
    required this.statusPending,
    required this.statusLate,
    required this.statusGraded,
    required this.statusStale,
  });

  final Color warning, onWarning, warningContainer;
  final Color info, onInfo, infoContainer;
  final Color success, onSuccess, successContainer;
  final Color scoreFail, scoreFailContainer;

  /// 頁面底色與卡片底色。
  ///
  /// 不能直接用 M3 的 surface / surfaceContainer：亮色模式下 surfaceContainer
  /// 比 surface **深**，卡片就變成白底上的一塊灰，正好和設計稿相反（設計稿是
  /// 灰底上的白卡）。所以兩個色階自己指定，暗色模式才沿用 M3 的方向。
  final Color page, card;

  /// StatusPill 的 (底色, 前景) 配對。集中在這裡，呼叫端就不必各自發明一組。
  final ({Color bg, Color fg}) statusPending,
      statusLate,
      statusGraded,
      statusStale;

  factory TatTokens.from(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final primaryHue = HSLColor.fromColor(scheme.primary).hue;

    final warningHue = _rotateToward(_warningHue, primaryHue);
    final infoHue = _rotateToward(_infoHue, primaryHue);
    final successHue = _rotateToward(_successHue, primaryHue);
    // 不及格直接沿用 scheme 的 error 色相，它本來就跟著裝置。
    final failHue = HSLColor.fromColor(scheme.error).hue;

    final main = isLight ? _mainLight : _mainDark;
    final container = isLight ? _containerLight : _containerDark;
    final on = isLight ? _onLight : _onDark;

    final success = main.of(successHue);
    final successContainer = container.of(successHue);
    final warning = main.of(warningHue);
    final warningContainer = container.of(warningHue);

    return TatTokens(
      page: isLight ? scheme.surfaceContainer : scheme.surface,
      card: isLight ? scheme.surfaceContainerLowest : scheme.surfaceContainer,
      warning: warning,
      onWarning: on.of(warningHue),
      warningContainer: warningContainer,
      info: main.of(infoHue),
      onInfo: on.of(infoHue),
      infoContainer: container.of(infoHue),
      success: success,
      onSuccess: on.of(successHue),
      successContainer: successContainer,
      scoreFail: main.of(failHue),
      scoreFailContainer: container.of(failHue),
      statusPending: (
        bg: scheme.surfaceContainerHighest,
        fg: scheme.onSurfaceVariant,
      ),
      statusLate: (bg: scheme.errorContainer, fg: scheme.onErrorContainer),
      statusGraded: (bg: successContainer, fg: success),
      statusStale: (bg: warningContainer, fg: warning),
    );
  }

  @override
  TatTokens copyWith({
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? scoreFail,
    Color? scoreFailContainer,
    Color? page,
    Color? card,
    ({Color bg, Color fg})? statusPending,
    ({Color bg, Color fg})? statusLate,
    ({Color bg, Color fg})? statusGraded,
    ({Color bg, Color fg})? statusStale,
  }) {
    return TatTokens(
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      scoreFail: scoreFail ?? this.scoreFail,
      scoreFailContainer: scoreFailContainer ?? this.scoreFailContainer,
      page: page ?? this.page,
      card: card ?? this.card,
      statusPending: statusPending ?? this.statusPending,
      statusLate: statusLate ?? this.statusLate,
      statusGraded: statusGraded ?? this.statusGraded,
      statusStale: statusStale ?? this.statusStale,
    );
  }

  @override
  TatTokens lerp(TatTokens? other, double t) {
    if (other == null) return this;
    return TatTokens(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      scoreFail: Color.lerp(scoreFail, other.scoreFail, t)!,
      scoreFailContainer:
          Color.lerp(scoreFailContainer, other.scoreFailContainer, t)!,
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      statusPending: _lerpPair(statusPending, other.statusPending, t),
      statusLate: _lerpPair(statusLate, other.statusLate, t),
      statusGraded: _lerpPair(statusGraded, other.statusGraded, t),
      statusStale: _lerpPair(statusStale, other.statusStale, t),
    );
  }

  static ({Color bg, Color fg}) _lerpPair(
    ({Color bg, Color fg}) a,
    ({Color bg, Color fg}) b,
    double t,
  ) =>
      (bg: Color.lerp(a.bg, b.bg, t)!, fg: Color.lerp(a.fg, b.fg, t)!);

  // 形狀與尺寸。散在各檔案的裸數字集中在這裡。
  static const double radiusCard = 12;
  static const double radiusDialog = 16; // dialog-spec §01 刻意不用 M3 的 28
  static const double radiusSheet = 20;
  static const double radiusField = 14;
  static const double radiusButton = 8;
  static const double heightField = 48;
  static const double heightButton = 44;
  static const double heightRow = 52;
  static const double iconColumn = 28;
  static const double dialogPadding = 20;
  static const double dialogMaxWidth = 400;
  static const double scrimOpacity = 0.48;
  static const double sheetMaxHeightFactor = 0.72;
}

/// 設計稿圓點色的色相：警告 #7B4E00、資訊 #195B96、成功 #186A34。
const double _warningHue = 38;
const double _infoHue = 208;
const double _successHue = 140;

/// 固定色相往 primary 轉一小段，語意還認得出來，但整組會偏向裝置配色。
const double _harmonizeAmount = 0.15;

double _rotateToward(double base, double target) {
  final diff = ((target - base + 540) % 360) - 180;
  return (base + diff * _harmonizeAmount) % 360;
}

/// 一組固定的彩度／明度。數值是掃過 0–359 全色相挑出來的，最差的色相
/// （亮色 h60、暗色 h240）也還有 5.4:1 / 6.8:1，不會有某個桌布色相踩雷。
@immutable
class _Tone {
  const _Tone(this.saturation, this.lightness);

  final double saturation;
  final double lightness;

  Color of(double hue) =>
      HSLColor.fromAHSL(1, hue % 360, saturation, lightness).toColor();
}

const _Tone _mainLight = _Tone(0.70, 0.24);
const _Tone _containerLight = _Tone(0.60, 0.93);
const _Tone _onLight = _Tone(0.35, 0.99);
const _Tone _mainDark = _Tone(0.60, 0.76);
const _Tone _containerDark = _Tone(0.45, 0.17);
const _Tone _onDark = _Tone(0.65, 0.09);
