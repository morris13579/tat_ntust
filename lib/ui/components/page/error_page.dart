import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:get/get.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, required this.errorMsg});

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
            Text(
              errorMsg?.isEmpty == true
                  ? R.current.error
                  : (errorMsg ?? R.current.error),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.fade,
            ),
            const SizedBox(height: 32)
          ],
        ),
      ),
    );
  }

  Widget alertIcon() {
    return const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 32);
  }
}
