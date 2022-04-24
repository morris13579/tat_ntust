import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/constants.dart';
import 'package:flutter_app/src/providers/category_provider.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class SortSheet extends StatelessWidget {
  const SortSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(
              height: 15,
            ),
            Text(
              R.current.sortBy,
              style: const TextStyle(
                fontSize: 12.0,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Flexible(
              child: ListView.builder(
                itemCount: Constants.sortList.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    onTap: () async {
                      await Provider.of<CategoryProvider>(context,
                              listen: false)
                          .setSort(index);
                      Navigator.pop(context);
                    },
                    contentPadding: const EdgeInsets.all(0),
                    trailing: index ==
                            Provider.of<CategoryProvider>(context,
                                    listen: false)
                                .sort
                        ? const Icon(
                            FontAwesome5.check,
                            color: Colors.blue,
                            size: 16,
                          )
                        : const SizedBox(),
                    title: Text(
                      Constants.sortList[index],
                      style: TextStyle(
                        fontSize: 14.0,
                        color: index ==
                                Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .sort
                            ? Colors.blue
                            : Theme.of(context).textTheme.headline6!.color,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
