import 'dart:convert';
import 'package:flutter/foundation.dart';

class EditorDiagnostic {
  const EditorDiagnostic({required this.message, required this.severity, this.line});
  final String message;
  final String severity;
  final int? line;
}

class EditorState extends ChangeNotifier {
  String currentPath = '';
  
  // 完整内容按行存储
  List<String> _allLines = [];
  List<String> get allLines => _allLines;
  
  // 当前加载到屏幕上的内容（拼接了前 N 页）
  String currentContent = '';
  int _loadedLineCount = 0;
  int get loadedLineCount => _loadedLineCount;
  int get totalLineCount => _allLines.length;
  
  bool isLoadingMore = false;
  bool modified = false;
  bool readOnly = false;
  String? readOnlyReason;
  String searchText = '';
  String replaceText = '';
  final Map<String, String> _dirtyFiles = {};
  final List<String> _undo = [];
  final List<String> _redo = [];
  bool _internal = false; 
  int _treeRevision = 0;

  static const int _pageSize = 500; // 每页加载 500 行

  Map<String, String> get dirtyFiles => Map.unmodifiable(_dirtyFiles);
  int get dirtyCount => _dirtyFiles.length;
  int get treeRevision => _treeRevision;

  void requestTreeRefresh() {
    _treeRevision++;
    notifyListeners();
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void _trackDirty() {
    if (currentPath.isNotEmpty && !readOnly) {
      _dirtyFiles[currentPath] = currentContent;
    }
  }

  void markPathSaved(String path) {
    _dirtyFiles.remove(path);
    if (path == currentPath) modified = false;
    notifyListeners();
  }

  void markAllSaved() {
    _dirtyFiles.clear();
    modified = false;
    notifyListeners();
  }

  String get language {
    final name = currentPath.split('/').last.toLowerCase();
    if (name == 'dockerfile') return 'dockerfile';
    if (name.endsWith('.dart')) return 'dart';
    if (name.endsWith('.js') || name.endsWith('.mjs') || name.endsWith('.cjs')) return 'javascript';
    if (name.endsWith('.ts')) return 'typescript';
    if (name.endsWith('.py')) return 'python';
    if (name.endsWith('.java')) return 'java';
    if (name.endsWith('.kt') || name.endsWith('.kts')) return 'kotlin';
    if (name.endsWith('.cpp') || name.endsWith('.cc') || name.endsWith('.cxx')) return 'cpp';
    if (name.endsWith('.c')) return 'c';
    if (name.endsWith('.h') || name.endsWith('.hpp')) return 'cpp';
    if (name.endsWith('.json')) return 'json';
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return 'yaml';
    if (name.endsWith('.xml')) return 'xml';
    if (name.endsWith('.html')) return 'xml';
    if (name.endsWith('.css')) return 'css';
    if (name.endsWith('.md')) return 'markdown';
    if (name.endsWith('.sh')) return 'bash';
    return 'plaintext';
  }

  List<EditorDiagnostic> get diagnostics => _diagnose(currentContent);

  void openFile(String path, String content, {bool readOnlyFile = false, String? reason}) {
    currentPath = path;
    _allLines = content.split('\n');
    readOnly = readOnlyFile;
    readOnlyReason = reason;
    modified = false;
    _undo.clear();
    _redo.clear();
    _loadInitialPage();
  }

  /// 从 Base64 加载文件，支持分页
  Future<void> openFileFromBase64(String path, String base64Content) async {
    currentPath = path;
    readOnly = false;
    readOnlyReason = null;
    modified = false;
    _undo.clear();
    _redo.clear();
    
    // 分块解码，防止一次性占用过多内存
    final buffer = StringBuffer();
    try {
      final decoded = utf8.decode(base64Decode(base64Content), allowMalformed: true);
      buffer.write(decoded);
    } catch (e) {
      buffer.write('解码失败：$e');
      readOnly = true;
      readOnlyReason = '解码错误';
    }

    _allLines = buffer.toString().split('\n');
    _loadInitialPage();
  }

  void _loadInitialPage() {
    _loadedLineCount = _allLines.length < _pageSize ? _allLines.length : _pageSize;
    currentContent = _allLines.take(_loadedLineCount).join('\n');
    notifyListeners();
  }

  /// 加载下一页数据
  void loadNextPage() {
    if (isLoadingMore || _loadedLineCount >= _allLines.length) return;
    isLoadingMore = true;
    notifyListeners();

    // 异步加载，避免阻塞 UI
    Future.microtask(() {
      final nextCount = _allLines.length - _loadedLineCount < _pageSize 
          ? _allLines.length - _loadedLineCount 
          : _pageSize;
      
      final nextLines = _allLines.sublist(_loadedLineCount, _loadedLineCount + nextCount);
      _loadedLineCount += nextCount;
      
      // 追加到当前内容
      currentContent += '\n' + nextLines.join('\n');
      isLoadingMore = false;
      notifyListeners();
    });
  }

  /// 更新内容（用户编辑时触发）
  /// 注意：这会以用户编辑后的全文覆盖 _allLines
  void updateContent(String value) {
    if (_internal || value == currentContent) return;
    _undo.add(currentContent);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    currentContent = value;
    _allLines = value.split('\n');
    _loadedLineCount = _allLines.length; // 编辑后视为全部已加载
    modified = true;
    _trackDirty();
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _internal = true;
    _redo.add(currentContent);
    currentContent = _undo.removeLast();
    _allLines = currentContent.split('\n');
    _loadedLineCount = _allLines.length;
    modified = true;
    _trackDirty();
    _internal = false;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _internal = true;
    _undo.add(currentContent);
    currentContent = _redo.removeLast();
    _allLines = currentContent.split('\n');
    _loadedLineCount = _allLines.length;
    modified = true;
    _trackDirty();
    _internal = false;
    notifyListeners();
  }

  void markSaved() {
    if (currentPath.isNotEmpty) _dirtyFiles.remove(currentPath);
    modified = false;
    notifyListeners();
  }

  void setSearch(String value) {
    searchText = value;
    notifyListeners();
  }

  void setReplace(String value) {
    replaceText = value;
    notifyListeners();
  }

  List<EditorDiagnostic> _diagnose(String text) {
    final issues = <EditorDiagnostic>[];
    if (text.isEmpty) return issues;

    if (language == 'json') {
      final t = text.trim();
      if (!(t.startsWith('{') && t.endsWith('}')) && !(t.startsWith('[') && t.endsWith(']'))) {
        issues.add(const EditorDiagnostic(message: 'JSON 应以 { } 或 [ ] 包裹', severity: 'error', line: 1));
      }
    }

    if ((language == 'dart' ||
            language == 'java' ||
            language == 'javascript' ||
            language == 'typescript' ||
            language == 'kotlin') &&
        text.contains('\t')) {
      final line = text.split('\n').indexWhere((l) => l.contains('\t')) + 1;
      issues.add(EditorDiagnostic(message: '检测到 Tab 缩进，建议统一为空格', severity: 'info', line: line));
    }
    return issues;
  }
}