import 'package:flutter/foundation.dart';

class EditorDiagnostic {
  const EditorDiagnostic({required this.message, required this.severity});
  final String message;
  final String severity;
}

class EditorState extends ChangeNotifier {
  String currentPath = '';
  String currentContent = '';
  bool modified = false;
  bool readOnly = false;
  String? readOnlyReason;
  String searchText = '';
  String replaceText = '';

  final List<String> _undo = [];
  final List<String> _redo = [];
  bool _internal = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

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
    currentContent = content;
    readOnly = readOnlyFile;
    readOnlyReason = reason;
    modified = false;
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }

  void updateContent(String value) {
    if (_internal || value == currentContent) return;
    _undo.add(currentContent);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    currentContent = value;
    modified = true;
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _internal = true;
    _redo.add(currentContent);
    currentContent = _undo.removeLast();
    modified = true;
    _internal = false;
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _internal = true;
    _undo.add(currentContent);
    currentContent = _redo.removeLast();
    modified = true;
    _internal = false;
    notifyListeners();
  }

  void markSaved() {
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
    final pairs = {'(': ')', '[': ']', '{': '}'};
    for (final e in pairs.entries) {
      final a = RegExp(RegExp.escape(e.key)).allMatches(text).length;
      final b = RegExp(RegExp.escape(e.value)).allMatches(text).length;
      if (a != b) issues.add(EditorDiagnostic(message: '${e.key}${e.value} 数量不匹配：$a / $b', severity: 'warning'));
    }
    if (language == 'json') {
      final t = text.trim();
      if (!(t.startsWith('{') && t.endsWith('}')) && !(t.startsWith('[') && t.endsWith(']'))) {
        issues.add(const EditorDiagnostic(message: 'JSON 应以 { } 或 [ ] 包裹', severity: 'error'));
      }
    }
    if ((language == 'dart' || language == 'java' || language == 'javascript' || language == 'typescript' || language == 'kotlin') && text.contains('\t')) {
      issues.add(const EditorDiagnostic(message: '检测到 Tab 缩进，建议统一为空格', severity: 'info'));
    }
    return issues;
  }
}