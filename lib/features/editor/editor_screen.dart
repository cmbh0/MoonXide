import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/build_center_state.dart';
import '../../core/services/editor_state.dart';
import '../../core/ai/ai_api_client.dart';
import '../../core/ai/ai_config_state.dart';

// ─── 错误波浪线 Painter ───────────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.text,
    required this.diagnostics,
    required this.baseStyle,
    required this.scrollOffset,
    required this.fontSize,
  });
  final String text;
  final List<EditorDiagnostic> diagnostics;
  final TextStyle baseStyle;
  final double scrollOffset;
  final double fontSize;

  double get _lineHeight => fontSize * (baseStyle.height ?? 1.55);

  @override
  void paint(Canvas canvas, Size size) {
    if (diagnostics.isEmpty || text.isEmpty) return;
    final lines = text.split('\n');
    const padTop = 2.0;
    const padLeft = 10.0;

    for (final d in diagnostics) {
      if (d.severity != 'error' && d.severity != 'warning') continue;
      final lineIndex = (d.line ?? 1) - 1;
      if (lineIndex < 0 || lineIndex >= lines.length) continue;
      final line = lines[lineIndex];
      if (line.trim().isEmpty) continue;

      final y = padTop - scrollOffset + (lineIndex + 1) * _lineHeight - 2;
      if (y < 0 || y > size.height) continue;
      final paint = Paint()
        ..color = (d.severity == 'error' ? Colors.red : Colors.orange).withOpacity(0.75)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final path = Path();
      const waveW = 4.0;
      const waveH = 2.0;
      final lineW = (line.length * 7.5).clamp(20.0, size.width - padLeft - 12);
      path.moveTo(padLeft, y);
      var x = padLeft;
      var up = true;
      while (x < padLeft + lineW) {
        path.relativeQuadraticBezierTo(waveW / 2, up ? -waveH : waveH, waveW, 0);
        x += waveW;
        up = !up;
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.text != text || old.diagnostics != diagnostics || old.scrollOffset != scrollOffset;
}

class _LineNumberGutter extends StatelessWidget {
  const _LineNumberGutter({
    required this.lineCount,
    required this.scrollController,
    required this.backgroundColor,
    required this.textColor,
    required this.textStyle,
    required this.fontSize,
  });

  final int lineCount;
  final ScrollController scrollController;
  final Color backgroundColor;
  final Color textColor;
  final TextStyle textStyle;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      color: backgroundColor,
      child: AnimatedBuilder(
        animation: scrollController,
        builder: (_, __) => CustomPaint(
          painter: _LineNumberPainter(
            lineCount: lineCount,
            scrollOffset: scrollController.hasClients ? scrollController.offset : 0,
            textColor: textColor,
            textStyle: textStyle,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}

class _LineNumberPainter extends CustomPainter {
  _LineNumberPainter({
    required this.lineCount,
    required this.scrollOffset,
    required this.textColor,
    required this.textStyle,
    required this.fontSize,
  });

  final int lineCount;
  final double scrollOffset;
  final Color textColor;
  final TextStyle textStyle;
  final double fontSize;

  double get _lineHeight => fontSize * (textStyle.height ?? 1.55);

  @override
  void paint(Canvas canvas, Size size) {
    final first = (scrollOffset / _lineHeight).floor().clamp(0, lineCount - 1);
    final visible = (size.height / _lineHeight).ceil() + 2;
    final painter = TextPainter(textAlign: TextAlign.right, textDirection: TextDirection.ltr);
    for (var i = first; i < lineCount && i < first + visible; i++) {
      painter.text = TextSpan(text: '${i + 1}', style: textStyle.copyWith(color: textColor));
      painter.layout(minWidth: 0, maxWidth: size.width - 6);
      final y = 2 - scrollOffset + i * _lineHeight;
      painter.paint(canvas, Offset(size.width - painter.width - 4, y));
    }
  }

  @override
  bool shouldRepaint(_LineNumberPainter old) =>
      old.lineCount != lineCount || old.scrollOffset != scrollOffset || old.textColor != textColor || old.textStyle != textStyle;
}
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  EditorScreenState createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen> {
  final contentController = _CodeController();
  final searchController  = TextEditingController();
  final replaceController = TextEditingController();
  final lineJumpController = TextEditingController();
  final _editorScroll     = ScrollController();
  bool showFind = false;
  double _editorFontSize = 13.0; // 默认字号

  @override
  void initState() {
    super.initState();
    _editorScroll.addListener(_onEditorScroll);
  }

  void _onEditorScroll() {
    if (mounted) {
      setState(() {});
      // 自动加载下一页：当滚动到距离底部 500 像素以内时触发
      if (_editorScroll.hasClients) {
        final maxScroll = _editorScroll.position.maxScrollExtent;
        final currentScroll = _editorScroll.offset;
        if (maxScroll - currentScroll < 500) {
          final editor = context.read<EditorState>();
          editor.loadNextPage();
        }
      }
    }
  }

  @override
  void dispose() {
    _editorScroll.removeListener(_onEditorScroll);
    contentController.dispose();
    searchController.dispose();
    replaceController.dispose();
    lineJumpController.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  void _sync(EditorState state) {
    if (contentController.text != state.currentContent) {
      contentController.text = state.currentContent;
    }
  }

  // ── 公开方法供 HomeScreen 调用 ──────────────────────────────────────────────
  void toggleFind() => setState(() => showFind = !showFind);

  Future<void> save(BuildContext ctx) async {
    final editor = ctx.read<EditorState>();
    final app    = ctx.read<AppState>();
    final owner  = app.selectedOwner;
    final repo   = app.selectedRepo;
    if (owner == null || repo == null || app.github == null ||
        editor.currentPath.isEmpty || editor.readOnly) return;
    try {
      String? sha;
      try {
        final f = await app.github!.getFile(owner, repo, editor.currentPath);
        sha = f['sha'] as String?;
      } catch (_) {}
      
      // 获取最终要保存的内容：
      // 如果用户编辑过，editor.currentContent 已经是最新的全文（因为 updateContent 会合并）
      // 如果用户只是浏览没有编辑，则保存完整的 allLines
      final contentToSave = editor.modified 
          ? editor.currentContent 
          : editor.allLines.join('\n');

      await app.github!.putFile(
        owner: owner,
        repo: repo,
        path: editor.currentPath,
        message: 'Update ${editor.currentPath} by MoonXide',
        contentBase64: base64Encode(utf8.encode(contentToSave)),
        sha: sha,
      );
      editor.openFile(editor.currentPath, contentToSave);
      editor.markSaved();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('已保存并提交到 GitHub')));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  Future<void> saveAll(BuildContext ctx) async {
    final editor = ctx.read<EditorState>();
    final app    = ctx.read<AppState>();
    final center = ctx.read<BuildCenterState>();
    final owner  = app.selectedOwner;
    final repo   = app.selectedRepo;
    if (owner == null || repo == null || app.github == null) return;

    final pending = Map<String, String>.from(editor.dirtyFiles);
    if (pending.isEmpty) {
      center.finish('没有待推送文件');
      return;
    }

    center.start('准备推送 ${pending.length} 个文件…');
    var done = 0;
    final failed = <String>[];

    for (final entry in pending.entries) {
      final path = entry.key;
      final content = entry.value;
      try {
        center.updateProgress(
          statusText: '推送中：$path',
          value: (done / pending.length).clamp(0.05, 0.95),
        );
        String? sha;
        try {
          final f = await app.github!.getFile(owner, repo, path);
          sha = f['sha'] as String?;
        } catch (_) {}
        await app.github!.putFile(
          owner: owner,
          repo: repo,
          path: path,
          message: 'Update $path by MoonXide',
          contentBase64: base64Encode(utf8.encode(content)),
          sha: sha,
        );
        done++;
        editor.markPathSaved(path);
        center.updateProgress(
          statusText: '已推送 $done / ${pending.length}：$path',
          value: (done / pending.length).clamp(0.05, 1.0),
        );
      } catch (e) {
        failed.add('$path：$e');
        center.updateProgress(
          statusText: '推送失败，继续处理剩余文件：$path',
          value: (done / pending.length).clamp(0.05, 0.95),
        );
      }
    }

    if (failed.isEmpty) {
      center.finish('全部文件已推送：$done / ${pending.length}');
      editor.markAllSaved(); // 清除所有脏标记，小点消失
    } else {
      center.fail('部分推送失败：成功 $done / ${pending.length}\n${failed.take(3).join('\n')}');
    }
  }

  void insertText(String text, EditorState editor) {
    final value     = contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end   = selection.isValid ? selection.end   : value.text.length;
    final next  = value.text.replaceRange(start, end, text);
    contentController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start + text.length));
    editor.updateContent(next);
  }

  void _find(EditorState editor) {
    final q = searchController.text;
    if (q.isEmpty) return;
    final idx = contentController.text.indexOf(q);
    if (idx < 0) return;
    contentController.selection = TextSelection(baseOffset: idx, extentOffset: idx + q.length);
    contentController.setHighlight(idx, idx + q.length, _CodeHighlightKind.search);
    _scrollToOffset(idx);
  }

  void _scrollToOffset(int offset) {
    final before = contentController.text.substring(0, offset.clamp(0, contentController.text.length));
    final line = '\n'.allMatches(before).length;
    final lineH = (contentController.baseStyle.fontSize ?? 13) * (contentController.baseStyle.height ?? 1.55);
    if (_editorScroll.hasClients) {
      _editorScroll.animateTo((line * lineH).clamp(0.0, _editorScroll.position.maxScrollExtent), duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    }
  }

  void _jumpToLine() {
    final text = lineJumpController.text.trim();
    if (text.isEmpty) return;
    final line = int.tryParse(text);
    if (line == null || line <= 0) return;
    final lines = contentController.text.split('\n');
    if (line > lines.length) return;
    var offset = 0;
    for (var i = 0; i < line - 1; i++) {
      offset += lines[i].length + 1; // +1 is for '\n'
    }
    contentController.selection = TextSelection.collapsed(offset: offset);
    _scrollToOffset(offset);
  }

  void _replace(EditorState editor) {
    if (searchController.text.isEmpty) return;
    final first = contentController.text.indexOf(searchController.text);
    final next = contentController.text
        .replaceAll(searchController.text, replaceController.text);
    contentController.text = next;
    if (first >= 0 && replaceController.text.isNotEmpty) {
      contentController.setHighlight(first, first + replaceController.text.length, _CodeHighlightKind.replace);
      _scrollToOffset(first);
    }
    editor.updateContent(next);
  }

  Future<void> _handleErrorTap(BuildContext context, EditorDiagnostic diag, EditorState editor) async {
    if (editor.readOnly) return;
    final confirmed = await MxDialog.show(
      context,
      title: '使用 AI 修复错误？',
      content: '${diag.severity}: ${diag.message}\n\n将调用 AI 分析并流式修复代码。',
      confirmLabel: '修复',
      cancelLabel: '取消',
    );
    if (!confirmed || !context.mounted) return;
    
    final appState = context.read<AppState>();
    final aiConfigState = context.read<AiConfigState>();
    final aiConfig = aiConfigState.config;
    if (aiConfig.baseUrl.trim().isEmpty || aiConfig.apiKey.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先配置 AI 接口设置')),
        );
      }
      return;
    }
    
    // 提取错误上下文：当前文件内容 + 错误信息
    final fileContent = editor.currentContent;
    final fileName = editor.currentPath.split('/').last;
    final language = editor.language;
    
    final prompt = '''请修复以下 $language 文件中的错误。

文件名: $fileName
错误信息: ${diag.severity}: ${diag.message}

当前代码:
```$language
$fileContent
```

请只返回修复后的完整代码，不要包含任何解释。''';
    
    // 显示修复动画 overlay
    setState(() => _showRepairOverlay = true);
    final stream = AiApiClient().sendStream(aiConfig, prompt);
    final buffer = StringBuffer();
    
    try {
      await for (final chunk in stream) {
        buffer.write(chunk);
        // 流式更新编辑器内容
        final newContent = _extractCode(buffer.toString(), language);
        if (newContent != null) {
          contentController.text = newContent;
          editor.updateContent(newContent);
        }
      }
      // 最终提取代码
      final finalContent = _extractCode(buffer.toString(), language) ?? buffer.toString();
      contentController.text = finalContent;
      editor.updateContent(finalContent);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text('AI 修复完成'),
            ]),
            backgroundColor: Color(0xFF1E8E3E),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 修复失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _showRepairOverlay = false);
    }
  }

  bool _showRepairOverlay = false;

  /// 从 AI 返回文本中提取代码块
  String? _extractCode(String text, String language) {
    // 尝试匹配 ```language ... ``` 格式
    final pattern = RegExp('```$language\\n(.+?)```', dotAll: true);
    final match = pattern.firstMatch(text);
    if (match != null) return match.group(1);
    // 尝试匹配 ``` ... ``` 格式
    final genericPattern = RegExp('```\\n(.+?)```', dotAll: true);
    final genericMatch = genericPattern.firstMatch(text);
    if (genericMatch != null) return genericMatch.group(1);
    return null;
  }

  // ── 构建 ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorState>();
    final appState = context.watch<AppState>();
    final hasBg = appState.customBackgroundPath != null;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _sync(editor);
    final lineCount = contentController.text.isEmpty
        ? 1
        : contentController.text.split('\n').length;

    final editorBg    = (isDark ? const Color(0xFF0A1929) : const Color(0xFFFAFDFF))
        .withOpacity(hasBg ? 0.78 : 1.0);
    final gutterBg    = (isDark ? const Color(0xFF0D1F2D) : const Color(0xFFEFF4F8))
        .withOpacity(hasBg ? 0.78 : 1.0);
    final gutterText  = isDark ? const Color(0xFF4A6A80) : const Color(0xFF8A9BAA);
    final editorText  = isDark ? const Color(0xFFD4E8F5) : const Color(0xFF1A2B38);
    contentController.baseStyle = TextStyle(
        fontFamily: 'monospace', fontSize: _editorFontSize, height: 1.55, color: editorText);
    contentController.keywordColor = isDark ? const Color(0xFF82AAFF) : const Color(0xFF245BCB);
  contentController.stringColor = isDark ? const Color(0xFFC3E88D) : const Color(0xFF22863A);
  contentController.commentColor = isDark ? const Color(0xFF637777) : const Color(0xFF6A737D);
  contentController.numberColor = isDark ? const Color(0xFFF78C6C) : const Color(0xFFB35900);
  contentController.symbolColor = isDark ? const Color(0xFF89DDFF) : const Color(0xFF0B7C9B);
    final diagnostics = editor.diagnostics;

    return Column(
      children: [
        // ── 查找替换栏（可选显示） ────────────────────────────────────────────
        if (showFind)
          Container(
            color: (isDark ? const Color(0xFF0F2230) : Colors.white)
                .withOpacity(0.95),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: MxTextField(
                            controller: searchController, hint: '搜索')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: MxTextField(
                            controller: replaceController, hint: '替换为')),
                    const SizedBox(width: 6),
                    MxIconBtn(
                        icon: Icons.search_rounded,
                        onPressed: () => _find(editor),
                        size: 36),
                    MxIconBtn(
                        icon: Icons.find_replace_rounded,
                        onPressed: () => _replace(editor),
                        size: 36),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: MxTextField(
                        controller: lineJumpController,
                        hint: '跳转到行号',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    MxButton(
                      label: '跳转',
                      icon: Icons.redo_rounded,
                      small: true,
                      filled: false,
                      onPressed: _jumpToLine,
                    ),
                    const Spacer(),
                    MxIconBtn(
                        icon: Icons.close_rounded,
                        onPressed: () => setState(() => showFind = false),
                        size: 36),
                  ],
                ),
              ],
            ),
          ),

        // ── 代码编辑区 ────────────────────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 行号栏
              _LineNumberGutter(
                lineCount: lineCount,
                scrollController: _editorScroll,
                backgroundColor: gutterBg,
                textColor: gutterText,
                textStyle: contentController.baseStyle,
                fontSize: _editorFontSize,
              ),

              // 代码区（横向可滚动 + 错误波浪线 overlay + 错误点击区域）
              Expanded(
                child: Stack(
                  children: [
                    RawScrollbar(
                      controller: _editorScroll,
                      thumbVisibility: true,
                      interactive: true,
                      thickness: 6,
                      radius: const Radius.circular(999),
                      thumbColor: scheme.primary.withOpacity(0.58),
                      minOverscrollLength: 20,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1200, // 足够宽，允许长行横向滚动
                          child: GestureDetector(
                            onTap: contentController.clearHighlight,
                            child: TextField(
                              controller: contentController,
                              readOnly: editor.readOnly,
                              scrollController: _editorScroll,
                              expands: true,
                              maxLines: null,
                              minLines: null,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              style: contentController.baseStyle,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: editorBg,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(10, 2, 12, 12),
                                hintText: null,
                              ),
                              onChanged: (v) { contentController.clearHighlight(); editor.updateContent(v); },
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 错误波浪线 overlay
                    if (diagnostics.isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _WavePainter(
                              text: contentController.text,
                              diagnostics: diagnostics,
                              baseStyle: contentController.baseStyle,
                              scrollOffset: _editorScroll.hasClients ? _editorScroll.offset : 0,
                              fontSize: _editorFontSize,
                            ),
                          ),
                        ),
                      ),
                    // 错误点击热区
                    if (diagnostics.isNotEmpty)
                      Positioned.fill(
                        child: _ErrorTapLayer(
                          text: contentController.text,
                          diagnostics: diagnostics,
                          scrollOffset: _editorScroll.hasClients ? _editorScroll.offset : 0,
                          baseStyle: contentController.baseStyle,
                          onTapError: (diag) => _handleErrorTap(context, diag, editor),
                        ),
                      ),

                    // ── 浮动快捷滚动滑块（极简无外框设计，类长方形微圆角滑块） ──
                    Positioned(
                      right: 2,
                      top: 40,
                      bottom: 40,
                      width: 12, // 窄身轨道，无宽大背景外框
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragUpdate: (details) {
                              if (!_editorScroll.hasClients) return;
                              final localY = details.localPosition.dy;
                              final totalH = constraints.maxHeight;
                              final pct = (localY / totalH).clamp(0.0, 1.0);
                              final targetScroll = pct * _editorScroll.position.maxScrollExtent;
                              _editorScroll.jumpTo(targetScroll);
                            },
                            child: AnimatedBuilder(
                              animation: _editorScroll,
                              builder: (context, _) {
                                double pct = 0.0;
                                if (_editorScroll.hasClients && _editorScroll.position.maxScrollExtent > 0) {
                                  pct = (_editorScroll.offset / _editorScroll.position.maxScrollExtent).clamp(0.0, 1.0);
                                }
                                final trackH = constraints.maxHeight;
                                final thumbH = 44.0; // 适当拉长的触摸高度
                                final topOffset = (pct * (trackH - thumbH)).clamp(0.0, trackH - thumbH);
                                return Stack(
                                  children: [
                                    Positioned(
                                      top: topOffset,
                                      left: 1,
                                      right: 1,
                                      height: thumbH,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          // 使用半透明主色，并在深浅色模式下完美适配
                                          color: scheme.primary.withOpacity(0.85),
                                          borderRadius: BorderRadius.circular(4), // 减小圆角，呈现更带劲、利落的现代类长方形
                                          boxShadow: [
                                            BoxShadow(
                                              color: scheme.primary.withOpacity(0.24),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            )
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Container(
                                          width: 2,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(1),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (editor.readOnly)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: isDark ? const Color(0xFF26313A) : const Color(0xFFEAF4FF),
            child: Text('只读：${editor.readOnlyReason ?? '预览模式'}', style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w800)),
          ),

        // 底部状态栏：分页加载状态与行数统计
        if (editor.totalLineCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: isDark ? const Color(0xFF0D1F2D) : const Color(0xFFEFF4F8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (editor.isLoadingMore)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      SizedBox(width: 6),
                      Text('加载中...', style: TextStyle(fontSize: 10)),
                    ],
                  )
                else if (editor.loadedLineCount < editor.totalLineCount)
                  Text(
                    '滚动加载更多 · ${editor.loadedLineCount}/${editor.totalLineCount} 行',
                    style: TextStyle(fontSize: 10, color: scheme.onSurface.withOpacity(0.5)),
                  )
                else
                  Text(
                    '已加载全部 · ${editor.totalLineCount} 行',
                    style: TextStyle(fontSize: 10, color: scheme.onSurface.withOpacity(0.5)),
                  ),
                Text(
                  editor.language,
                  style: TextStyle(fontSize: 10, color: scheme.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),

        if (diagnostics.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: isDark ? const Color(0xFF132536) : const Color(0xFFFFF8E8),
            child: Text(
              '${editor.language} · ${diagnostics.length} 个提示：${diagnostics.first.message}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: diagnostics.first.severity == 'error' ? Colors.red : const Color(0xFFE08A00),
              ),
            ),
          ),

        // ── 符号快捷栏 ────────────────────────────────────────────────────────
        _SymbolBar(
            isDark: isDark,
            onInsert: (text) => insertText(text, editor)),
      ],
    );
  }
}

// ─── 符号快捷栏 ───────────────────────────────────────────────────────────────
class _SymbolBar extends StatelessWidget {
  const _SymbolBar({required this.isDark, required this.onInsert});
  final bool isDark;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    const symbols = [
      '{', '}', '(', ')', '[', ']', ';', ':', '.', ',',
      '=>', '==', '!=', '&&', '||', '/', '_', '"', "'", '\t'
    ];
    final bg = isDark ? const Color(0xFF0D1F2D) : const Color(0xFFEFF4F8);
    final fg = isDark ? const Color(0xFF8ECFEE) : const Color(0xFF2F6A8C);
    return SafeArea(
      top: false,
      child: Container(
        height: 44,
        color: bg,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          itemCount: symbols.length,
          separatorBuilder: (_, __) => const SizedBox(width: 2),
          itemBuilder: (_, i) {
            final s = symbols[i];
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onInsert(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: fg.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s == '\t' ? '⇥' : s,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: fg),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── 错误点击热区层 ───────────────────────────────────────────────────────────
class _ErrorTapLayer extends StatelessWidget {
  const _ErrorTapLayer({
    required this.text,
    required this.diagnostics,
    required this.scrollOffset,
    required this.baseStyle,
    required this.onTapError,
  });
  final String text;
  final List<EditorDiagnostic> diagnostics;
  final double scrollOffset;
  final TextStyle baseStyle;
  final ValueChanged<EditorDiagnostic> onTapError;

  double get _lineHeight => (baseStyle.fontSize ?? 13) * (baseStyle.height ?? 1.55);

  @override
  Widget build(BuildContext context) {
    if (diagnostics.isEmpty || text.isEmpty) return const SizedBox.shrink();
    final lines = text.split('\n');
    const padTop = 2.0;

    return Stack(
      children: diagnostics.map((diag) {
        final lineIndex = (diag.line ?? 1) - 1;
        if (lineIndex < 0 || lineIndex >= lines.length) return const SizedBox.shrink();
        final y = padTop - scrollOffset + lineIndex * _lineHeight;
        return Positioned(
          left: 10,
          top: y,
          width: 600,
          height: _lineHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => onTapError(diag),
            child: Container(color: Colors.transparent),
          ),
        );
      }).toList(),
    );
  }
}

// ─── 修复动画 overlay ─────────────────────────────────────────────────────────
class _RepairOverlay extends StatefulWidget {
  const _RepairOverlay();
  @override
  State<_RepairOverlay> createState() => _RepairOverlayState();
}

class _RepairOverlayState extends State<_RepairOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          color: Colors.black.withOpacity(0.08),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1929).withOpacity(0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF54C5F8).withOpacity(0.45)),
                boxShadow: [BoxShadow(color: const Color(0xFF54C5F8).withOpacity(0.18), blurRadius: 16)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(const Color(0xFF54C5F8)))),
                const SizedBox(width: 12),
                Text('AI 正在修复…', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF54C5F8))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}


enum _CodeHighlightKind { search, replace }

class _CodeController extends TextEditingController {
  TextStyle baseStyle = const TextStyle(fontFamily: 'monospace', fontSize: 14);
  Color keywordColor = Colors.blue;
  Color stringColor = Colors.green;
  Color commentColor = Colors.grey;
  Color numberColor = Colors.orange;
  Color symbolColor = Colors.purple;
  TextRange highlightRange = TextRange.empty;
  _CodeHighlightKind? highlightKind;

  void setHighlight(int start, int end, _CodeHighlightKind kind) {
    highlightRange = TextRange(start: start, end: end);
    highlightKind = kind;
    notifyListeners();
  }

  void clearHighlight() {
    if (!highlightRange.isValid && highlightKind == null) return;
    highlightRange = TextRange.empty;
    highlightKind = null;
    notifyListeners();
  }

  // 支持更多主流语言的语法高亮匹配
  static final _kw = RegExp(r'\b(class|void|final|const|var|return|if|else|for|while|switch|case|break|continue|import|package|new|public|private|protected|static|fun|val|def|async|await|try|catch|throw|extends|implements|struct|enum|union|typedef|extern|register|volatile|inline|virtual|override|fn|let|mut|pub|use|mod|impl|trait|type|where|as|in|of|nil|undefined|null|true|false|bool|int|double|float|char|void|string|any|number|boolean|list|map|set)\b');
  static final _str = RegExp(r'''("[^"\n]*"|'[^'\n]*'|`[^`]*`)''');
  static final _comment = RegExp(r'(//.*|#.*|/\*[\s\S]*?\*/|--.*)');
  static final _color = RegExp(r'#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b');
  static final _num = RegExp(r'\b(0x[0-9a-fA-F]+|\d+\.?\d*)\b');
  static final _sym = RegExp(r'(\+|\-|\*|/|=|!|&|\||\^|~|<|>|\?|:)');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final text = value.text;
    final spans = <TextSpan>[];
    final matches = <_Match>[];
    
    void addMatches(RegExp reg, _TokenType type) {
      for (final m in reg.allMatches(text)) {
        matches.add(_Match(m.start, m.end, type));
      }
    }

    addMatches(_kw, _TokenType.keyword);
    addMatches(_str, _TokenType.string);
    addMatches(_comment, _TokenType.comment);
    addMatches(_color, _TokenType.color);
    addMatches(_num, _TokenType.number);
    addMatches(_sym, _TokenType.symbol);

    matches.sort((a, b) => a.start.compareTo(b.start));

    var i = 0;
    for (final m in matches) {
      if (m.start < i) continue;
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start), style: baseStyle));
      final token = text.substring(m.start, m.end);
      TextStyle tokenStyle;

      switch (m.type) {
        case _TokenType.color:
          final color = HexColor.fromHex(token);
          // 判断颜色亮度以决定文字颜色（黑或白）
          final isLight = color.computeLuminance() > 0.5;
          tokenStyle = baseStyle.copyWith(
            color: isLight ? Colors.black : Colors.white,
            backgroundColor: color,
            fontWeight: FontWeight.w700,
          );
          break;
        case _TokenType.number:
          tokenStyle = baseStyle.copyWith(color: numberColor);
          break;
        case _TokenType.symbol:
          tokenStyle = baseStyle.copyWith(color: symbolColor);
          break;
        case _TokenType.comment:
          tokenStyle = baseStyle.copyWith(color: commentColor, fontStyle: FontStyle.italic);
          break;
        case _TokenType.string:
          tokenStyle = baseStyle.copyWith(color: stringColor);
          break;
        case _TokenType.keyword:
          tokenStyle = baseStyle.copyWith(color: keywordColor, fontWeight: FontWeight.w700);
          break;
      }

      spans.add(_spanWithHighlight(token, m.start, tokenStyle));
      i = m.end;
    }
    if (i < text.length) spans.add(_spanWithHighlight(text.substring(i), i, baseStyle));
    return TextSpan(style: baseStyle, children: spans);
  }

  TextSpan _spanWithHighlight(String segment, int absoluteStart, TextStyle style) {
    if (!highlightRange.isValid || highlightRange.isCollapsed) return TextSpan(text: segment, style: style);
    final start = highlightRange.start;
    final end = highlightRange.end;
    final segEnd = absoluteStart + segment.length;
    if (segEnd <= start || absoluteStart >= end) return TextSpan(text: segment, style: style);
    final children = <TextSpan>[];
    final localStart = (start - absoluteStart).clamp(0, segment.length);
    final localEnd = (end - absoluteStart).clamp(0, segment.length);
    if (localStart > 0) children.add(TextSpan(text: segment.substring(0, localStart), style: style));
    final bg = highlightKind == _CodeHighlightKind.replace
        ? const Color(0xFFB7F7C8)
        : const Color(0xFFB8D7FF);
    children.add(TextSpan(text: segment.substring(localStart, localEnd), style: style.copyWith(backgroundColor: bg)));
    if (localEnd < segment.length) children.add(TextSpan(text: segment.substring(localEnd), style: style));
    return TextSpan(children: children, style: style);
  }
}

enum _TokenType { keyword, string, comment, color, number, symbol }

class _Match {
  final int start;
  final int end;
  final _TokenType type;
  _Match(this.start, this.end, this.type);
}

class HexColor extends Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('FF');
    }
    buffer.write(hexString.replaceFirst('#', '').replaceAll('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  const HexColor(super.value);
}