import 'dart:convert';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';
import 'ai_tool_call.dart';

/// MoonXide AI 工具执行器
/// 支持的工具：read_file / write_file / list_files / github_api / search_code
class AiToolExecutor {
  final AppState appState;
  final EditorState editorState;

  AiToolExecutor({required this.appState, required this.editorState});

  // 工具定义（发给 AI 的 system prompt 附加部分）
  static const String toolsDescription = '''
你可以调用以下真实工具，格式必须是单个 JSON 代码块：
```json
{"tool": "<工具名>", "args": {<参数>}}
```

重要规则：
- 不要编造文件、编译结果、接口结果或执行结果；需要事实时必须先调用工具读取/列出/搜索。
- 写文件前先 read_file 或 list_files 确认路径和现状；不知道路径时先 list_files。
- 工具调用只描述要执行的真实操作，不要把自然语言说明混进 JSON。
- 如果没有足够信息，先调用 list_files / read_file / search_code。

可用工具：
- read_file: 读取仓库文件内容。args: {"path": "文件路径"}
- write_file: 写入/更新仓库文件。args: {"path": "文件路径", "content": "文件内容", "message": "提交信息"}
- list_files: 列出仓库目录内容。args: {"path": "目录路径，根目录传空字符串"}
- github_api: 调用 GitHub REST API。args: {"method": "GET/POST/...", "endpoint": "/repos/...", "body": {}}
- search_code: 在当前编辑器内容中搜索。args: {"query": "搜索关键词"}
- get_editor_content: 获取当前编辑器内容。args: {}
''';

  /// 从 AI 回复中解析工具调用
  static List<AiToolCall> parseFromText(String text) {
    final calls = <AiToolCall>[];
    // 匹配 ```json ... ``` 代码块
    final jsonBlockReg = RegExp(r'```(?:json)?\s*(\{.*?\})\s*```', dotAll: true);
    for (final m in jsonBlockReg.allMatches(text)) {
      try {
        final j = jsonDecode(m.group(1)!) as Map<String, dynamic>;
        final tool = j['tool'] as String?;
        if (tool == null) continue;
        final args = (j['args'] as Map<String, dynamic>?) ?? {};
        calls.add(AiToolCall(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: tool,
          args: args,
        ));
      } catch (_) {}
    }
    return calls;
  }

  /// 执行工具调用，返回结果字符串
  Future<String> execute(AiToolCall call) async {
    final owner = appState.selectedOwner;
    final repo  = appState.selectedRepo;
    final gh    = appState.github;

    switch (call.name) {
      case 'read_file':
        if (owner == null || repo == null || gh == null) return '错误：未选择仓库';
        final path = call.args['path'] as String? ?? '';
        try {
          final f = await gh.getFile(owner, repo, path);
          final raw = (f['content'] as String).replaceAll('\n', '');
          return utf8.decode(base64Decode(raw), allowMalformed: true);
        } catch (e) { return '读取失败：$e'; }

      case 'write_file':
        if (owner == null || repo == null || gh == null) return '错误：未选择仓库';
        final path    = call.args['path']    as String? ?? '';
        final content = call.args['content'] as String? ?? '';
        final message = call.args['message'] as String? ?? 'Update $path by MoonXide AI';
        try {
          String? sha;
          var oldLines = 0;
          try {
            final f = await gh.getFile(owner, repo, path);
            sha = f['sha'] as String?;
            final raw = (f['content'] as String).replaceAll('\n', '');
            final oldContent = utf8.decode(base64Decode(raw), allowMalformed: true);
            oldLines = oldContent.isEmpty ? 0 : oldContent.split('\n').length;
          } catch (_) {}
          await gh.putFile(
            owner: owner, repo: repo, path: path,
            message: message,
            contentBase64: base64Encode(utf8.encode(content)),
            sha: sha,
          );
          // 如果是当前打开的文件，同步编辑器
          if (editorState.currentPath == path) {
            editorState.openFile(path, content);
            editorState.markSaved();
          }
          // 刷新工作区文件树缓存，使变更立即可见
          editorState.requestTreeRefresh();
          final newLines = content.isEmpty ? 0 : content.split('\n').length;
          return '已写入并提交：$path\n变更统计：+$newLines -$oldLines';
        } catch (e) { return '写入失败：$e'; }

      case 'list_files':
        if (owner == null || repo == null || gh == null) return '错误：未选择仓库';
        final path = call.args['path'] as String? ?? '';
        try {
          final items = await gh.getContents(owner, repo, path: path);
          return items.map((e) => '${e['type'] == 'dir' ? '📁' : '📄'} ${e['path']}').join('\n');
        } catch (e) { return '列目录失败：$e'; }

      case 'github_api':
        if (gh == null) return '错误：未登录 GitHub';
        final method   = (call.args['method'] as String? ?? 'GET').toUpperCase();
        final endpoint = call.args['endpoint'] as String? ?? '';
        final body     = call.args['body'] as Map<String, dynamic>?;
        try {
          final result = await gh.rawRequest(method, endpoint, body: body);
          return jsonEncode(result).length > 2000
              ? '${jsonEncode(result).substring(0, 2000)}…（已截断）'
              : jsonEncode(result);
        } catch (e) { return 'GitHub API 失败：$e'; }

      case 'search_code':
        final query = call.args['query'] as String? ?? '';
        if (query.isEmpty) return '请提供搜索关键词';
        final content = editorState.currentContent;
        if (content.isEmpty) return '编辑器为空';
        final lines = content.split('\n');
        final results = <String>[];
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(query)) {
            results.add('第 ${i + 1} 行：${lines[i].trim()}');
          }
        }
        return results.isEmpty ? '未找到匹配内容' : results.take(20).join('\n');

      case 'get_editor_content':
        return editorState.currentContent.isEmpty
            ? '编辑器为空'
            : editorState.currentContent;

      default:
        return '未知工具：${call.name}';
    }
  }
}