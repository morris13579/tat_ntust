import 'dart:collection';

import 'package:flutter_app/debug/log/console_output.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

import 'ansi_parser.dart';

class LogConsole extends StatefulWidget {
  final bool dark;

  LogConsole({super.key, this.dark = false})
      : assert(LogBuffer.isInitialized, "Please call LogBuffer.init() first.");

  @override
  State<StatefulWidget> createState() => _LogConsoleState();
}

class RenderedEvent {
  final int id;
  final Level level;
  final TextSpan span;
  final String lowerCaseText;

  RenderedEvent(this.id, this.level, this.span, this.lowerCaseText);
}

class _LogConsoleState extends State<LogConsole> {
  final ListQueue<RenderedEvent> _renderedBuffer = ListQueue();
  List<RenderedEvent> _filteredBuffer = [];

  final _scrollController = ScrollController();
  final _filterController = TextEditingController();

  Level _filterLevel = Level.trace;
  double _logFontSize = 14;

  var _currentId = 0;
  bool _scrollListenerEnabled = true;
  bool _followBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrollListenerEnabled) return;
      var scrolledToBottom = _scrollController.offset >=
          _scrollController.position.maxScrollExtent;
      setState(() {
        _followBottom = scrolledToBottom;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _renderedBuffer.clear();
    for (var event in LogBuffer.events) {
      _renderedBuffer.add(_renderEvent(event));
    }
    _refreshFilter();
  }

  void _refreshFilter() {
    var newFilteredBuffer = _renderedBuffer.where((it) {
      var logLevelMatches = it.level.index >= _filterLevel.index;
      if (!logLevelMatches) {
        return false;
      } else if (_filterController.text.isNotEmpty) {
        var filterText = _filterController.text.toLowerCase();
        return it.lowerCaseText.contains(filterText);
      } else {
        return true;
      }
    }).toList();
    setState(() {
      _filteredBuffer = newFilteredBuffer;
    });

    if (_followBottom) {
      Future.delayed(Duration.zero, _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.dark
          ? ThemeData(
              brightness: Brightness.dark,
            )
          : ThemeData(
              brightness: Brightness.light,
            ),
      home: Scaffold(
        appBar: AppBar(
          // Builder 不能拿掉：這一頁自己起了一個 MaterialApp，build 參數裡的
          // context 在那個 MaterialApp 之上，直接拿去呼叫
          // MaterialLocalizations.of() 會往外找 App 的 localizations，讓這個自成
          // 一格的頁面多出一個祖先需求（沒有 Material 祖先時直接 assert 失敗）。
          // 包一層 Builder 取到的是 DefaultMaterialLocalizations 的英文 "Back"。
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => Get.back(),
            ),
          ),
          title: const Text("Log Console"),
          actions: [
            // 以下三顆刻意寫死英文，不走 R.current：這是 vendor 進來的 debug log
            // console，整頁沒有一個字翻譯過。整頁要在地化時這三個字串一起處理。
            IconButton(
              tooltip: "Clear log",
              icon: const Icon(LucideIcons.x),
              onPressed: () {
                LogBuffer.clear();
                didChangeDependencies();
              },
            ),
            IconButton(
              tooltip: "Increase font size",
              icon: const Icon(LucideIcons.plus),
              onPressed: () {
                setState(() {
                  _logFontSize++;
                });
              },
            ),
            IconButton(
              tooltip: "Decrease font size",
              icon: const Icon(LucideIcons.minus),
              onPressed: () {
                setState(() {
                  _logFontSize--;
                });
              },
            )
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _buildLogContent(),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
        floatingActionButton: AnimatedOpacity(
          opacity: _followBottom ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 60),
            child: FloatingActionButton(
              // 同上，刻意保持英文。
              tooltip: "Scroll to bottom",
              mini: true,
              clipBehavior: Clip.antiAlias,
              onPressed: _scrollToBottom,
              child: Icon(
                LucideIcons.arrowDown,
                color: widget.dark ? Colors.white : Colors.lightBlue[900],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogContent() {
    return Container(
      color: widget.dark ? Colors.black : Colors.grey[150],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1600,
          child: ListView.builder(
            shrinkWrap: true,
            controller: _scrollController,
            itemBuilder: (context, index) {
              var logEntry = _filteredBuffer[index];
              return Text.rich(
                logEntry.span,
                key: Key(logEntry.id.toString()),
                style: TextStyle(fontSize: _logFontSize),
              );
            },
            itemCount: _filteredBuffer.length,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: TextField(
              style: const TextStyle(fontSize: 20),
              controller: _filterController,
              onChanged: (s) => _refreshFilter(),
              decoration: const InputDecoration(
                labelText: "Filter log output",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          DropdownButton<Level>(
            value: _filterLevel,
            // 預設的下拉箭頭是 Material 的 arrow_drop_down，整包 App 裡唯一
            // 一顆非 Lucide 的圖示。
            icon: const Icon(LucideIcons.chevronDown),
            items: const [
              DropdownMenuItem(
                value: Level.trace,
                child: Text("Trace"),
              ),
              DropdownMenuItem(
                value: Level.debug,
                child: Text("Debug"),
              ),
              DropdownMenuItem(
                value: Level.info,
                child: Text("Info"),
              ),
              DropdownMenuItem(
                value: Level.warning,
                child: Text("Warning"),
              ),
              DropdownMenuItem(
                value: Level.error,
                child: Text("Error"),
              ),
              DropdownMenuItem(
                value: Level.fatal,
                child: Text("Fatal"),
              ),
              DropdownMenuItem(
                value: Level.off,
                child: Text("Off"),
              )
            ],
            onChanged: (value) {
              _filterLevel = value!;
              _refreshFilter();
            },
          )
        ],
      ),
    );
  }

  void _scrollToBottom() async {
    _scrollListenerEnabled = false;

    setState(() {
      _followBottom = true;
    });

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    _scrollListenerEnabled = true;
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    var parser = AnsiParser(widget.dark);
    var text = event.lines.join('\n');
    parser.parse(text);
    return RenderedEvent(
      _currentId++,
      event.level,
      TextSpan(children: parser.spans),
      text.toLowerCase(),
    );
  }

  @override
  void dispose() {
    // log console 可以反覆開關，不 dispose 的話每開一次就漏一組。
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }
}

class LogBar extends StatelessWidget {
  final bool dark;
  final Widget child;

  const LogBar({
    required this.dark,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!dark)
              BoxShadow(
                color: Colors.grey.shade400,
                blurRadius: 3,
              ),
          ],
        ),
        child: Material(
          color: dark ? Colors.blueGrey.shade900 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
            child: child,
          ),
        ),
      ),
    );
  }
}
