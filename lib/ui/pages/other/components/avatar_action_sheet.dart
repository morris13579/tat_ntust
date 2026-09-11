import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// 頭貼可以做的三件事。
enum AvatarAction { gallery, camera, remove }

/// 頭貼的動作選單。回 null 代表使用者沒選（下滑、點遮罩、按返回都算）。
///
/// 沒有標題也沒有「取消」那一列：開它的按鈕就叫「更換頭貼」，再寫一次是重複，
/// 而下滑與點遮罩都能關（dialog-spec §06-A）。
///
/// [canRemove] 為 false 時不顯示「移除」：使用者用的是主題預設圖，
/// core_user::update_picture 會因為 picture 沒有變而回 success:false，
/// 看起來像失敗，但他其實什麼都沒做錯。
Future<AvatarAction?> showAvatarActionSheet(
  BuildContext context, {
  required bool canRemove,
}) {
  return showTatActionSheet<AvatarAction>(
    context: context,
    items: [
      TatSheetItem(
        icon: LucideIcons.camera,
        label: R.current.avatarTakePhoto,
        value: AvatarAction.camera,
      ),
      TatSheetItem(
        icon: LucideIcons.images,
        label: R.current.avatarFromGallery,
        value: AvatarAction.gallery,
      ),
      if (canRemove)
        TatSheetItem(
          icon: LucideIcons.trash2,
          label: R.current.avatarRemove,
          value: AvatarAction.remove,
          destructive: true,
        ),
    ],
  );
}
