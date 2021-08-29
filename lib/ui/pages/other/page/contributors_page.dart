
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/model/github/repository_contributors.dart';
import 'package:flutter_app/ui/other/listview_animator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';

class ContributorsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(R.current.Contribution),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.only(top: 10, bottom: 10),
                child: Text(
                  R.current.projectLink,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  child: InkWell(
                    onTap: () {
                      final url = AppLink.gitHub;
                      launch(url);
                    },
                    child: Container(
                      padding: EdgeInsets.only(left: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                R.current.github,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              )
                            ],
                          ),
                          Row(
                            children: [Text(AppLink.gitHub)],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: EdgeInsets.only(top: 10, bottom: 10),
                child: Text(
                  R.current.Contributors,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          FutureBuilder<Response>(
            future: Connector.getDataByGetResponse(ConnectorParameter(
                "https://api.github.com/repos/${AppLink.githubOwner}/${AppLink.githubName}/contributors")),
            builder: (BuildContext context, AsyncSnapshot<Response> snapshot) {
              if (snapshot.hasData) {
                List<RepositoryContributor> contributorList =
                    (snapshot.data.data as List)
                        .map((e) => RepositoryContributor.fromJson(e))
                        .toList();

                return ListView.builder(
                  itemCount: contributorList.length,
                  shrinkWrap: true,
                  itemBuilder: (BuildContext context, int index) {
                    RepositoryContributor contributor = contributorList[index];
                    return InkWell(
                      onTap: () {
                        launch(contributor.htmlUrl);
                      },
                      child: WidgetAnimator(
                        Container(
                          padding: EdgeInsets.only(top: 5, bottom: 5, left: 10),
                          child: Row(
                            children: [
                              Container(
                                height: 50,
                                width: 50,
                                child: CachedNetworkImage(
                                  imageUrl: contributor.avatarUrl,
                                  imageBuilder: (context, imageProvider) =>
                                      CircleAvatar(
                                    radius: 15.0,
                                    backgroundImage: imageProvider,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(left: 10),
                              ),
                              Text(contributor.login)
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Icon(Icons.error),
                );
              }
              return Center(
                child: SpinKitDoubleBounce(
                  color: AppColors.mainColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
