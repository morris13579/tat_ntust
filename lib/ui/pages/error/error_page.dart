import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/route_utils.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        const Center(
          child: Icon(
            Icons.warning_amber_outlined,
            size: 150,
          ),
        ),
        Center(
          child: Text(
            Model.instance.getAccount().isEmpty
                ? R.current.pleaseLoginWarning
                : "Opps something Error",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
          ),
        ),
        const SizedBox(
          height: 30,
        ),
        if (Model.instance.getAccount().isEmpty)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.2,
            child: ElevatedButton(
              child: Text(R.current.login),
              onPressed: () {
                RouteUtils.toLoginScreen();
              },
            ),
          )
      ],
    );
  }
}
