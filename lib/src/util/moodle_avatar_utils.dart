/// 頭貼相關的純判斷。放在 util 是為了給 repository 與 UI 共用而不必互相 import。
class MoodleAvatarUtils {
  const MoodleAvatarUtils._();

  /// 這個 userpictureurl 是不是使用者自己上傳的頭貼。
  ///
  /// 有頭貼時 user_picture::get_url 回的是
  /// `/pluginfile.php/<usercontextid>/user/icon/<theme>/f1?rev=<picture>`；
  /// 沒有的話回主題預設圖 `/theme/image.php/...`（或 gravatar）。
  /// 「移除目前的頭貼」只在這個回 true 時才該出現——對著預設圖按移除，
  /// 伺服器會因為 picture 沒有變而回 success:false，看起來像失敗。
  static bool hasCustomPicture(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    // 只看路徑：query 裡也可能出現這些字串，那不算。
    final path = uri.path;
    return path.contains('/pluginfile.php/') && path.contains('/user/icon/');
  }

  /// 上傳前的本地大小檢查。[maxBytes] 直接吃 site_info 的
  /// usermaxuploadfilesize：-1 是「不限」（USER_CAN_IGNORE_FILE_SIZE_LIMITS），
  /// 0 或負數是「不知道」，兩者都放行、交給伺服器判。
  static bool exceedsLimit(int sizeBytes, int maxBytes) =>
      maxBytes > 0 && sizeBytes > maxBytes;
}
