//  listview_animator.dart
//  北科課程助手
//  用於顯示動畫
//  Created by morris13579 on 2020/02/12.
//  Copyright © 2020 morris13579 All rights reserved.
//

import 'dart:async';

import 'package:flutter/cupertino.dart';

class Animator extends StatefulWidget {
  final Widget child;
  final Duration time;

  const Animator(
    this.child,
    this.time, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _AnimatorState();
}

class _AnimatorState extends State<Animator>
    with SingleTickerProviderStateMixin {
  Timer? timer;
  late AnimationController animationController;
  late Animation animation;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
        duration: const Duration(milliseconds: 290), vsync: this);
    animation =
        CurvedAnimation(parent: animationController, curve: Curves.easeInOut);
    timer = Timer(widget.time, animationController.forward);
  }

  @override
  void dispose() {
    timer!.cancel();
    animationController.dispose();
    super.dispose(); //需要先dispose上面兩個才不會出錯
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0.0, (1 - animation.value) * 20),
            child: child,
          ),
        );
      },
    );
  }
}

/// 進場動畫的錯開排程：同一批出現的項目，一項比一項多等 [_stagger]，
/// 讓清單看起來是由上往下一項一項浮出來。
///
/// 兩件事不能省：累加值以 frame 為界重設（用計時器猜 build 邊界，在跨 frame 建構
/// ——等非同步資料、捲動時延遲建構、兩個清單同時在畫面上——就會對不上），以及
/// 延遲要有上限（沒有上限時，一個 frame 建二十項的清單，最後一項要等兩秒才淡入）。
class _EntryDelay {
  /// 每一項比前一項多等多久。
  static const Duration _stagger = Duration(milliseconds: 100);

  /// 延遲上限。超過的項目一律用這個值——動畫是為了「進場」，等超過半秒才淡入
  /// 只會讓人以為畫面卡住。
  static const Duration _maxDelay = Duration(milliseconds: 500);

  static Duration _accumulated = Duration.zero;
  static bool _resetScheduled = false;

  /// 取得下一個項目的進場延遲，並確保這個 frame 結束後累加值歸零。
  static Duration next() {
    if (!_resetScheduled) {
      _resetScheduled = true;
      // 以 post-frame callback（而不是計時器）歸零：ListView 會在同一個 frame 內把
      // 可視區加上 cacheExtent 的項目一次建好，需要互相錯開的正好是這一批。
      // addPostFrameCallback 自己不排新 frame，但這裡只在 build 期間被呼叫，必有一
      // 個進行中的 frame，callback 保證會在該 frame 收尾時跑到。
      WidgetsBinding.instance.addPostFrameCallback((_) => reset());
    }
    _accumulated += _stagger;
    return _accumulated > _maxDelay ? _maxDelay : _accumulated;
  }

  static void reset() {
    _accumulated = Duration.zero;
    _resetScheduled = false;
  }
}

/// 讓測試在每個案例開始前把錯開累加值歸零。
///
/// 正式程式碼不需要呼叫：累加值本來就會在每個 frame 結束時自己歸零。
@visibleForTesting
void debugResetEntryDelay() => _EntryDelay.reset();

class WidgetAnimator extends StatefulWidget {
  final Widget child;

  const WidgetAnimator(
    this.child, {
    super.key,
  });

  @override
  State<WidgetAnimator> createState() => _WidgetAnimatorState();
}

class _WidgetAnimatorState extends State<WidgetAnimator> {
  /// 延遲只在第一次建構時決定，之後的 rebuild 沿用同一個值。
  ///
  /// 不可以在 build() 裡取號：內層 Animator 的 State 早就建好、不會採用新值，卻
  /// 會白白吃掉一個名額，把同一個 frame 裡真正新出現的項目往後推。
  late final Duration _delay = _EntryDelay.next();

  @override
  Widget build(BuildContext context) => Animator(widget.child, _delay);
}
