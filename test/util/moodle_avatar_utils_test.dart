import 'package:flutter_app/src/util/moodle_avatar_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// 頭貼的兩個純判斷。
void main() {
  group('hasCustomPicture', () {
    test('自己上傳的頭貼是 pluginfile 的 user/icon', () {
      expect(
        MoodleAvatarUtils.hasCustomPicture(
            'https://moodle2.ntust.edu.tw/pluginfile.php/12345/user/icon/boost/f1?rev=987654'),
        isTrue,
      );
    });

    test('主題預設圖不是自訂頭貼', () {
      // 這串就是 fixtures 裡沒有頭貼的使用者拿到的網址。
      expect(
        MoodleAvatarUtils.hasCustomPicture(
            'https://moodle2.ntust.edu.tw/theme/image.php/boost/core/1/u/f1'),
        isFalse,
      );
    });

    test('gravatar 與空字串都不是', () {
      expect(
        MoodleAvatarUtils.hasCustomPicture(
            'https://secure.gravatar.com/avatar/abc?s=100&d=mm'),
        isFalse,
      );
      expect(MoodleAvatarUtils.hasCustomPicture(''), isFalse);
    });

    test('別的 pluginfile 網址不算——不能只看 /pluginfile.php/', () {
      expect(
        MoodleAvatarUtils.hasCustomPicture(
            'https://moodle2.ntust.edu.tw/pluginfile.php/9/mod_forum/attachment/3/hw1.pdf'),
        isFalse,
      );
    });

    test('只看路徑，query 裡出現同樣的字串不算', () {
      expect(
        MoodleAvatarUtils.hasCustomPicture(
            'https://moodle2.ntust.edu.tw/theme/image.php/boost/core/1/u/f1?from=/pluginfile.php/1/user/icon/'),
        isFalse,
      );
    });
  });

  group('exceedsLimit', () {
    test('-1 是 USER_CAN_IGNORE_FILE_SIZE_LIMITS，永遠不超過', () {
      expect(MoodleAvatarUtils.exceedsLimit(999999999, -1), isFalse);
    });

    test('0 是「不知道」，一律放行交給伺服器判', () {
      expect(MoodleAvatarUtils.exceedsLimit(999999999, 0), isFalse);
    });

    test('剛好等於上限不算超過，多一個 byte 才算', () {
      expect(MoodleAvatarUtils.exceedsLimit(1048576, 1048576), isFalse);
      expect(MoodleAvatarUtils.exceedsLimit(1048577, 1048576), isTrue);
    });
  });
}
