import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/other/input_dialog.dart';
import 'package:flutter_app/ui/other/listview_animator.dart';
import 'package:get/get.dart';
import 'package:pretty_json/pretty_json.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreEditPage extends StatefulWidget {
  const StoreEditPage({Key? key}) : super(key: key);

  @override
  _StoreEditPageState createState() => _StoreEditPageState();
}

class _StoreEditPageState extends State<StoreEditPage> {
  SharedPreferences? pref;
  List<String> keyList = [];

  @override
  void initState() {
    super.initState();
  }

  Future<List<String>> initPref() async {
    pref = await SharedPreferences.getInstance();
    List<String> filter = [];
    List<String> cache = [];
    for (var i in pref!.getKeys().toList()) {
      if (!i.contains("cache_")) {
        filter.add(i);
      } else {
        cache.add(i);
      }
    }
    filter.addAll(cache);
    return filter;
  }

  @override
  void dispose() {
    Model.instance.getInstance();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Page"),
      ),
      body: FutureBuilder<List<String>>(
        future: initPref(),
        builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else {
            keyList = snapshot.data!;
            return ListView.separated(
              itemCount: keyList.length,
              itemBuilder: (context, index) {
                String key = keyList[index];
                String value;
                try {
                  value = prettyJson(json.decode(pref!.get(key).toString()),
                      indent: 2);
                } catch (e) {
                  value = pref!.get(key).toString();
                }
                return Container(
                  padding: const EdgeInsets.only(top: 5, left: 20, right: 20),
                  child: WidgetAnimator(
                    SizedBox(
                      height: 50,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(key),
                          ),
                          IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                Get.dialog(CustomInputDialog(
                                  title: key,
                                  initText: value,
                                  maxLine: 20,
                                  onCancel: (String value) {},
                                  onOk: (String value) async {
                                    if (pref!.get(key).runtimeType.toString() ==
                                        'String') {
                                      await pref!.setString(key, value);
                                    }
                                    if (pref!.get(key).runtimeType.toString() ==
                                        'int') {
                                      await pref!.setInt(key, int.parse(value));
                                    }
                                  },
                                ));
                              }),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              keyList.removeAt(index);
                              pref!.remove(key);
                              setState(() {});
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) {
                // 顯示格線
                return Container(
                  color: Colors.black12,
                  height: 1,
                );
              },
            );
          }
        },
      ),
    );
  }
}
