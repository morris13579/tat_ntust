import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({
    super.key,
    required this.data,
    this.onAvatarTap,
    this.progress,
    this.radius = 24,
    this.badgeBorderColor,
    this.stacked = false,
  });

  final MoodleProfileEntity data;

  /// null 代表頭貼不可點（沿用舊行為）。
  final VoidCallback? onAvatarTap;

  /// 換頭貼的送出進度，0..1。非 null 代表正在換，這時頭貼不可點。
  final double? progress;

  final double radius;

  /// 相機角標外圈的顏色，預設是 surface。頭貼放在別的底色上時要傳進來，
  /// 那圈縫才會跟背景同色。
  final Color? badgeBorderColor;

  /// 個人資訊頁把頭貼與姓名疊成一直排並置中；「更多」頁維持橫排。
  final bool stacked;

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  /// 這張網址的圖載不出來。`CircleAvatar` 的 child 是畫在 backgroundImage
  /// **上面**的，不是它的退路，所以載得到的時候必須不給 child。
  bool _imageFailed = false;

  @override
  void didUpdateWidget(UserProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 換了一張圖就重新給它一次機會，否則失敗過一次會永遠停在預設圖示。
    if (oldWidget.data.userpictureurl != widget.data.userpictureurl) {
      _imageFailed = false;
    }
  }

  void _onImageError() {
    if (_imageFailed) return;
    _imageFailed = true;
    if (!mounted) return;
    // 這個回呼可能是在 paint 期間送來的（DecorationImagePainter 解圖時），
    // 當場 setState 會炸；那時排到這一格結束後再重畫。
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final name = Text(
      widget.data.firstname,
      style: text.titleMedium?.copyWith(color: scheme.onSurface),
    );
    final account = Text(
      widget.data.username.toUpperCase(),
      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    );

    if (widget.stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(),
          const SizedBox(height: 12),
          name,
          const SizedBox(height: 4),
          account,
        ],
      );
    }

    return Row(
      children: [
        _buildAvatar(),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            name,
            const SizedBox(height: 4),
            account,
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final scheme = context.scheme;
    final progress = widget.progress;
    final busy = progress != null;
    final url = widget.data.userpictureurl;
    final showPlaceholder = url.isEmpty || _imageFailed;
    // 角標與預設圖示跟著頭貼一起放大，不然大頭貼上會掛一顆迷你鉛筆。
    final badgeSize = widget.radius * 0.75;
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: busy ? 0.5 : 1,
          child: CircleAvatar(
            radius: widget.radius,
            backgroundColor: scheme.surfaceContainerHigh,
            // onBackgroundImageError 是必要的：少了它，404 或離線的頭貼會把
            // 例外丟進 FlutterError.onError。
            backgroundImage: url.isEmpty ? null : NetworkImage(url),
            onBackgroundImageError: url.isEmpty
                ? null
                : (_, __) {
                    _onImageError();
                  },
            child: showPlaceholder
                ? Icon(LucideIcons.user,
                    size: widget.radius * 0.92, color: scheme.onSurfaceVariant)
                : null,
          ),
        ),
        if (busy)
          Positioned.fill(
            // 還沒有真的進度（移除頭貼整趟都沒有上傳）時給不定值：
            // 傳 0 進去畫的是一段長度為零的弧，等於什麼都沒有。
            child: CircularProgressIndicator(
                value: progress > 0 ? progress : null, strokeWidth: 2),
          )
        else if (widget.onAvatarTap != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
                // 外框用底下那塊的底色，角標和頭貼之間才會留出一圈縫，
                // 而不是直接黏在頭貼邊上。
                border: Border.all(
                    color: widget.badgeBorderColor ?? scheme.surface, width: 3),
              ),
              child: Icon(LucideIcons.camera,
                  size: badgeSize * 0.5, color: scheme.onPrimary),
            ),
          ),
      ],
    );

    if (widget.onAvatarTap == null) return avatar;

    return Semantics(
      button: true,
      label: R.current.avatarChange,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : widget.onAvatarTap,
        child: avatar,
      ),
    );
  }
}
