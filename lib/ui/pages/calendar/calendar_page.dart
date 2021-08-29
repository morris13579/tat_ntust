import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(R.current.calendar),
      ),
      body: Center(
        child: Text("目前尚未開放功能"),
      ),
    );
  }
}
