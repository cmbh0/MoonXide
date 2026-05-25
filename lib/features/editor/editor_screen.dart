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
  _WavePainter({required this.text, required this.diagnostics, required this.baseStyle});
  final String text;
  final List<EditorDiagnostic> diagnostics;
  final TextStyle baseStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (diagnostics.isEmpty || text.isEmpty) return;
    final lines = text.split('\n');
    const lineH = 21.7; // 与行号栏行高一致
    const padTop = 2.0;
    const padLeft = 10.0;

    for (final d in diagnostics) {
      if (d.severity != 'error' && d.severity != 'warning') continue;
      final color = d.severity == 'error' ? Colors.red : Colors.orange;
      // 简单策略：在每行底部画波浪线（对有问题的行）
      // 这里对所有行画，实际可按行号精确定位
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;
        // 只对包含问题关键词的行画波浪线
        final hasIssue = d.message.contains('{') || d.message.contains('(') || d.message.contains('[');
        if (!hasIssue) continue;
        final y = padTop + (i + 1) * lineH - 2;
        if (y > size.height) break;
        final paint = Paint()
          ..color = color.withOpacity(0.75)
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
        break; // 每个诊断只画一行
      }
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.text != text || old.diagnostics != diagnostics;
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
  final _editorScroll     = ScrollController();
  bool showFind = false;

  @override
  void dispose() {
    contentController.dispose();
    searchController.dispose();
    replaceController.dispose();
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
      await app.github!.putFile(
        owner: owner,
        repo: repo,
        path: editor.currentPath,
        message: 'Update ${editor.currentPath} by MoonXide',
        contentBase64: base64Encode(utf8.encode(contentController.text)),
        sha: sha,
      );
      editor.openFile(editor.currentPath, contentController.text);
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

  void _replace(EditorState editor) {
    if (searchController.text.isEmpty) return;
    final next = contentController.text
        .replaceAll(searchController.text, replaceController.text);
    contentController.text = next;
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
        fontFamily: 'monospace', fontSize: 13, height: 1.55, color: editorText);
    contentController.keywordColor = isDark ? const Color(0xFF82AAFF) : const Color(0xFF245BCB);
    contentController.stringColor = isDark ? const Color(0xFFC3E88D) : const Color(0xFF22863A);
    contentController.commentColor = isDark ? const Color(0xFF637777) : const Color(0xFF6A737D);
    final diagnostics = editor.diagnostics;

    return Column(
      children: [
        // ── 查找替换栏（可选显示） ────────────────────────────────────────────
        if (showFind)
          Container(
            color: (isDark ? const Color(0xFF0F2230) : Colors.white)
                .withOpacity(0.95),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
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
                    icon: Icons.find_replace_rounded,
                    onPressed: () => _replace(editor),
                    size: 36),
                MxIconBtn(
                    icon: Icons.close_rounded,
                    onPressed: () => setState(() => showFind = false),
                    size: 36),
// ── 代码编辑区 ────────────────────────────────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 行号栏
              Container(
                width: 36,
                color: gutterBg,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: lineCount,
                  itemBuilder: (_, i) => SizedBox(
                    height: 21.7,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.55,
                                color: gutterText)),
                      ),
                    ),
                  ),
                ),
              ),
              
              // 代码区（横向可滚动 + 错误波浪线 overlay + 错误点击区域）
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1200, // 足够宽，允许长行横向滚动
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
                          onChanged: editor.updateContent,
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
                          onTapError: (diag) => _handleErrorTap(context, diag, editor),
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
    required this.onTapError,
  });
  final String text;
  final List<EditorDiagnostic> diagnostics;
  final ValueChanged<EditorDiagnostic> onTapError;

  @override
  Widget build(BuildContext context) {
    if (diagnostics.isEmpty || text.isEmpty) return const SizedBox.shrink();
    final lines = text.split('\n');
    const lineH = 21.7;
    const padTop = 2.0;
    
    return Stack(
      children: diagnostics.asMap().entries.map((entry) {
        final idx = entry.key;
        final diag = entry.value;
        // 简单策略：为每个诊断在第一行创建点击区域
        if (idx >= lines.length) return const SizedBox.shrink();
        final y = padTop + idx * lineH;
        return Positioned(
          left: 10,
          top: y,
          width: 600,
          height: lineH,
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


class _CodeController extends TextEditingController {
  TextStyle baseStyle = const TextStyle(fontFamily: 'monospace', fontSize: 14);
  Color keywordColor = Colors.blue;
  Color stringColor = Colors.green;
  Color commentColor = Colors.grey;

  static final _kw = RegExp(r'\b(class|void|final|const|var|return|if|else|for|while|switch|case|break|continue|import|package|new|public|private|static|fun|val|def|async|await|try|catch|throw|extends|implements)\b');
  static final _str = RegExp(r'''("[^"\n]*"|'[^'\n]*')''');
  static final _comment = RegExp(r'(//.*|#.*)');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final text = value.text;
    final spans = <TextSpan>[];
    final matches = <RegExpMatch>[];
    matches.addAll(_kw.allMatches(text));
    matches.addAll(_str.allMatches(text));
    matches.addAll(_comment.allMatches(text));
    matches.sort((a, b) => a.start.compareTo(b.start));
    var i = 0;
    for (final m in matches) {
      if (m.start < i) continue;
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start), style: baseStyle));
      final token = text.substring(m.start, m.end);
      final color = _comment.hasMatch(token) ? commentColor : (_str.hasMatch(token) ? stringColor : keywordColor);
      spans.add(TextSpan(text: token, style: baseStyle.copyWith(color: color, fontWeight: _kw.hasMatch(token) ? FontWeight.w700 : null)));
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i), style: baseStyle));
    return TextSpan(style: baseStyle, children: spans);
  }
}

