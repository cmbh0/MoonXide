import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final contentController = TextEditingController();
  final searchController = TextEditingController();
  final replaceController = TextEditingController();
  bool showFind = false;

  @override
  void dispose() {
    contentController.dispose();
    searchController.dispose();
    replaceController.dispose();
    super.dispose();
  }

  void _sync(EditorState state) {
    if (contentController.text != state.currentContent) {
      contentController.text = state.currentContent;
    }
  }

  Future<void> _save(BuildContext context, EditorState editor, AppState app) async {
    final owner = app.selectedOwner;
    final repo = app.selectedRepo;
    if (owner == null || repo == null || app.github == null || editor.currentPath.isEmpty) return;
    try {
      String? sha;
      try {
        final file = await app.github!.getFile(owner, repo, editor.currentPath);
        sha = file['sha'] as String?;
      } catch (_) {}
      await app.github!.putFile(
        owner: owner,
        repo: repo,
        path: editor.currentPath,
        message: 'Update ${editor.currentPath} by MoonXide',
        contentBase64: base64Encode(utf8.encode(contentController.text)),
        sha: sha,
      );
      editor.openFile(editor.currentPath, contentController.text);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存并提交到 GitHub')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  void _replace(EditorState editor) {
    if (searchController.text.isEmpty) return;
    final next = contentController.text.replaceAll(searchController.text, replaceController.text);
    contentController.text = next;
    editor.updateContent(next);
  }

  void _insert(String text, EditorState editor) {
    final value = contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final next = value.text.replaceRange(start, end, text);
    contentController.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: start + text.length));
    editor.updateContent(next);
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorState>();
    final app = context.watch<AppState>();
    _sync(editor);
    final lineCount = contentController.text.isEmpty ? 1 : contentController.text.split('\n').length;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        titleSpacing: 0,
        title: Text(editor.currentPath.isEmpty ? '没有文件' : editor.currentPath, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: '撤销', onPressed: () {}, icon: const Icon(Icons.undo_rounded)),
          IconButton(tooltip: '重做', onPressed: () {}, icon: const Icon(Icons.redo_rounded)),
          IconButton(tooltip: '保存', onPressed: () => _save(context, editor, app), icon: const Icon(Icons.save_rounded)),
          IconButton(tooltip: '查找替换', onPressed: () => setState(() => showFind = !showFind), icon: const Icon(Icons.search_rounded)),
          IconButton(tooltip: '运行/编译', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请到编译页执行云编译'))), icon: const Icon(Icons.play_arrow_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'format') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('格式化将接入项目工具链')));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'format', child: Text('格式化代码')),
              PopupMenuItem(value: 'readonly', child: Text('只读/编辑模式')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (showFind)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: searchController, decoration: const InputDecoration(isDense: true, hintText: '搜索'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: replaceController, decoration: const InputDecoration(isDense: true, hintText: '替换为'))),
                  IconButton(onPressed: () => _replace(editor), icon: const Icon(Icons.find_replace_rounded)),
                ],
              ),
            ),
          Expanded(
            child: editor.currentPath.isEmpty
                ? const _EmptyEditor()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 54,
                        color: const Color(0xFFEDEEEF),
                        child: ListView.builder(
                          itemCount: lineCount,
                          itemBuilder: (_, i) => Container(
                            height: 22,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 8),
                            color: i == 0 ? const Color(0xFFE1E1E1) : null,
                            child: Text('${i + 1}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF555555))),
                          ),
                        ),
                      ),
                      Container(width: 1, color: const Color(0xFFE1DDE8)),
                      Expanded(
                        child: TextField(
                          controller: contentController,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.55, color: Color(0xFF202124)),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFFFFBFF),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(0, 2, 12, 12),
                          ),
                          onChanged: editor.updateContent,
                        ),
                      ),
                    ],
                  ),
          ),
          _SymbolBar(onInsert: (text) => _insert(text, editor)),
        ],
      ),
    );
  }
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 54, color: const Color(0xFFEDEEEF), alignment: Alignment.topRight, padding: const EdgeInsets.only(top: 4, right: 8), child: const Text('1')),
        Container(width: 1, color: const Color(0xFFE1DDE8)),
        const Expanded(
          child: ColoredBox(
            color: Color(0xFFFFFBFF),
            child: Padding(
              padding: EdgeInsets.only(top: 3),
              child: Text('没有内容。请创建或打开项目。修改配置请编辑 webapp。', style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SymbolBar extends StatelessWidget {
  const _SymbolBar({required this.onInsert});
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    const symbols = ['web', 'fun', 'win', '<', '>', '{', '}', '[', ']', '(', ')', ';'];
    return SafeArea(
      top: false,
      child: Container(
        height: 46,
        color: const Color(0xFFF1F3F4),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemBuilder: (_, i) => TextButton(
            onPressed: () => onInsert(symbols[i]),
            child: Text(symbols[i], style: const TextStyle(fontSize: 18, color: Color(0xFF202124))),
          ),
          separatorBuilder: (_, __) => const SizedBox(width: 2),
          itemCount: symbols.length,
        ),
      ),
    );
  }
}
