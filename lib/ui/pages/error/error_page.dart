import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/route_utils.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

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
          child: FutureBuilder(
            future: (Connectivity().checkConnectivity()),
            builder: (BuildContext context,
                AsyncSnapshot<ConnectivityResult> snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data == ConnectivityResult.none) {
                  return Text(
                    R.current.networkError,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 30),
                  );
                }
              }
              return Text(
                Model.instance.getAccount().isEmpty
                    ? R.current.pleaseLoginWarning
                    : R.current.somethingError,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
              );
            },
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
