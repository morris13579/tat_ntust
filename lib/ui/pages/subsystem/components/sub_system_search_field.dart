import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 資訊系統的搜尋欄。過濾在記憶體裡做，[onChanged] 不會發任何請求。
///
/// 刻意不 autofocus：這一頁一進來就有東西可看，彈鍵盤會把清單推到畫面外。
class SubSystemSearchField extends StatefulWidget {
  const SubSystemSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<SubSystemSearchField> createState() => _SubSystemSearchFieldState();
}

class _SubSystemSearchFieldState extends State<SubSystemSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    // 外框、填色與高度全部交給 InputDecorationTheme，不要自己用 Container +
    // Row 疊一個：那樣圖示會被 Row 置中、而文字被 InputDecorator 依自己的
    // 盒子排版，兩者對不齊。
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: context.text.bodyLarge?.copyWith(height: 1.2),
      decoration: InputDecoration(
        hintText: R.current.searchService,
        prefixIcon: const Icon(LucideIcons.search, size: 18),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 42, minHeight: 24),
        // 只在有字的時候才出現，空欄位上放一顆清除鈕沒有意義。
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: R.current.cancel,
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: _clear,
                ),
        ),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 42, minHeight: 24),
      ),
    );
  }
}
