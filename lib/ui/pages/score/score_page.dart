import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/score/score_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class ScoreViewerPage extends StatefulWidget {
  const ScoreViewerPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ScoreViewerPageState();
}

class _ScoreViewerPageState extends State<ScoreViewerPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool isLoading = true;
  List<SemesterScoreJson> semesterScoreList = [];
  final ScrollController _scrollController = ScrollController();
  int _currentTabIndex = 0;
  List<Widget> tabLabelList = [];
  List<Widget> tabChildList = [];

  @override
  void initState() {
    super.initState();
    loadScore();
  }

  void loadScore() async {
    await Model.instance.loadScore();
    semesterScoreList = Model.instance.getScore().info;
    if (semesterScoreList.isEmpty) {
      _addScoreRankTask();
    } else {
      _buildTabBar();
      setState(() {
        isLoading = false;
      });
    }
  }

  void _addScoreRankTask() async {
    semesterScoreList = [];
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    var scoreTask = ScoreTask();
    taskFlow.addTask(scoreTask);
    if (await taskFlow.start()) {
      semesterScoreList = scoreTask.result.info;
      Model.instance.setScore(scoreTask.result);
      await Model.instance.saveScore();
    }
    _buildTabBar();
    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabLabelList.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(R.current.searchScore),
          actions: [
            if (semesterScoreList.isNotEmpty)
              IconButton(
                onPressed: () {
                  _addScoreRankTask();
                },
                icon: const Icon(Icons.refresh),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.mainColor,
            unselectedLabelColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.label,
//      labelPadding: EdgeInsets.symmetric(horizontal: 8),
            indicator: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              color: Colors.white,
            ),
            isScrollable: true,
            tabs: tabLabelList,
            onTap: (int index) {
              _currentTabIndex = index;
              setState(() {});
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              if (!isLoading)
                (tabChildList.isNotEmpty)
                    ? tabChildList[_currentTabIndex]
                    : Container(),
            ],
          ),
        ),
      ),
    );
  }

  void _buildTabBar() {
    tabLabelList = [];
    tabChildList = [];
    for (int i = 0; i < semesterScoreList.length; i++) {
      var semester = semesterScoreList[i].semester;
      tabLabelList.add(_buildTabLabel("${semester.year}-${semester.semester}"));
      tabChildList.add(_buildSemesterScores(semesterScoreList[i].item));
    }
    if (_tabController != null) {
      if (tabChildList.length != _tabController?.length) {
        _tabController?.dispose();
        _tabController =
            TabController(length: tabChildList.length, vsync: this);
      }
    } else {
      _tabController = TabController(length: tabChildList.length, vsync: this);
    }
    _currentTabIndex = 0;
    _tabController?.animateTo(_currentTabIndex);
    setState(() {});
  }

  Widget _buildTabLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
      ),
      child: Tab(
        text: title,
      ),
    );
  }

  Widget _buildSemesterScores(List<ScoreItemJson> courseScore) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: AnimationLimiter(
        child: Column(
          children: AnimationConfiguration.toStaggeredList(
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: <Widget>[
              ..._buildCourseScores(courseScore),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCourseScores(List<ScoreItemJson> courseScore) {
    return [
      _buildTitle(R.current.resultsOfVariousSubjects),
      for (var score in courseScore) _buildScoreItem(score),
    ];
  }

  Widget _buildScoreItem(ScoreItemJson score) {
    return StatefulBuilder(
      builder: (BuildContext context, void Function(void Function()) setState) {
        return Column(
          children: <Widget>[
            SizedBox(
              height: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: AutoSizeText(
                      score.name,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: GestureDetector(
                      child: Text(
                        score.score,
                        style: const TextStyle(fontSize: 16.0),
                        textAlign: TextAlign.end,
                      ),
                      onTap: () {
                        MyToast.show(score.score);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 8.0,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
