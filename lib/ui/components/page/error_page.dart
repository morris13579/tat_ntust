import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, required this.errorMsg, required this.onRetry});

  final String? errorMsg;
  final Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            alertIcon(),
            Text(
              errorMsg?.isEmpty == true
                  ? ("error.someError".tr)
                  : (errorMsg ?? ("error.someError".tr)),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.fade,
            ),
            TextButton(
                onPressed: onRetry, child: Text("common.retry".tr)),
            const SizedBox(height: 32)
          ],
        ),
      ),
    );
  }

  Widget alertIcon() {
    return const Padding(
      padding: EdgeInsets.only(left: 36.0),
      child: Icon(CupertinoIcons.exclamationmark_triangle_fill)
    );
  }
}
