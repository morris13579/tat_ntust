import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/sub_system_pins.dart';

/// 原生版的資訊系統。整棵樹一次拿回來，搜尋在原生端做，同 `SubSystemController`。
class SubSystemBridge implements TatSubSystemApi {
  static void install() => TatSubSystemApi.setUp(SubSystemBridge());

  @override
  Future<ServiceTree> tree() async {
    final result = await NtustRepository.instance.getSubSystemTree();
    return ServiceTree(
      categories: [
        for (final category in result.dataOrNull ?? const <APTreeJson>[])
          ServiceCategory(
            serviceId: category.serviceId,
            pinsClassroom: category.serviceId == classroomPinnedCategory,
            services: [
              for (final ap in category.apList)
                ServiceLink(name: ap.name, url: ap.url),
            ],
          ),
      ],
      error: switch (result) {
        Failed(:final reason) => reason.message,
        _ => null,
      },
      notice: switch (result) {
        Stale(:final reason) => reason.message,
        _ => null,
      },
      signedIn: AuthSession.instance.isSignedIn,
    );
  }
}
