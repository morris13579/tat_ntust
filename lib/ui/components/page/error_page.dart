import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/adaptive_button.dart';
import 'package:get/get.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, this.errorMsg});

  final String? errorMsg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            alertIcon(),
            const SizedBox(height: 16),
            errorContent(),
            const SizedBox(height: 12),
            loginBtn(),
            const SizedBox(height: 24)
          ],
        ),
      ),
    );
  }

  Widget errorContent() {
    if (errorMsg != null) {
      return Text(
        errorMsg?.isEmpty == true
            ? R.current.error
            : (errorMsg ?? R.current.error),
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
        maxLines: 5,
        overflow: TextOverflow.fade,
      );
    }
    return FutureBuilder(
        future: (Connectivity().checkConnectivity()),
        builder:
            (BuildContext context, AsyncSnapshot<ConnectivityResult> snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data == ConnectivityResult.none) {
              return Text(
                R.current.networkError,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              );
            }
          }
          return Text(
            Model.instance.getAccount().isEmpty
                ? R.current.pleaseLoginWarning
                : R.current.somethingError,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          );
        });
  }

  Widget alertIcon() {
    return const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 32);
  }

  Widget loginBtn() {
    if (Model.instance.getAccount().isEmpty) {
      return AdaptiveButton(
        width: Get.context!.width * 0.2,
        onPressed: RouteUtils.toLoginScreen,
        borderRadius: BorderRadius.circular(999),
        child: Text(R.current.login),
      );
    }
    return const SizedBox();
  }
}
