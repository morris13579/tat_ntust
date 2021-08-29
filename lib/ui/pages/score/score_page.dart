import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';

class ScoreViewerPage extends StatefulWidget {
  @override
  _ScoreViewerPageState createState() => _ScoreViewerPageState();
}

class _ScoreViewerPageState extends State<ScoreViewerPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(R.current.searchScore),
      ),
      body: Center(
        child: Text("目前尚未開放功能"),
      ),
    );
  }
}
