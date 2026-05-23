import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';
import '../../core/services/local_file_upload_service.dart';
import '../project_identity/project_identity_screen.dart';

class _TreeNode {
  final String name;
  final String path;
  final bool isDir;
  final String? sha;
  final String? downloadUrl;
  bool expanded;
  bool loading;
  bool selected;
  List<_TreeNode> children;

  _TreeNode({
    required this.name,
    required this.path,
    required this.isDir,
    this.sha,
    this.downloadUrl,
    this.expanded = false,
    this.loading = false,
    this.selected = false,
    this.children = const [],
  });
}

class WorkspaceScreen extends StatefulWidget {
  final AppState state;
  const WorkspaceScreen({super.key, required this.state});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  static List<Map<String, dynamic>> _cachedRepos = [];
  static final Map<String, List<_TreeNode>> _cachedTree = {};
  static String? _cachedRepoKey;
  static final Map<String, String> _selectedPathByRepo = {};

  List<Map<String, dynamic>> _repos = _cachedRepos;
  List<_TreeNode> _roots = [];
  final Map<String, List<_TreeNode>> _treeCache = _cachedTree;
  String? _loadedRepoKey = _cachedRepoKey;
  bool _loadingRepos = false;
  bool _loadingTree = false;
  String? _openingPath;   // 正在加载的文件路径
  String? _selectedPath;  // 当前选中文件路径
  String? _error;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _renameCtrl = TextEditingController();
  bool _private = true;
  bool _autoInit = true;
  String _selectedTemplate = 'none';

  // ── 内置模板定义 ──────────────────────────────────────────────────────────
  static const _templates = {
    'none': {'label': '空仓库（不推送模板）', 'icon': Icons.folder_outlined},
    'flutter': {'label': 'Flutter / Dart 应用', 'icon': Icons.flutter_dash},
    'android_kotlin': {'label': 'Android Kotlin 应用', 'icon': Icons.android_rounded},
    'android_java': {'label': 'Android Java 应用', 'icon': Icons.local_cafe_rounded},
    'cpp_native': {'label': 'C/C++ 原生可执行', 'icon': Icons.memory_rounded},
  };
// GitHub Actions 工作流模板：按项目类型生成，不能所有模板都走 Flutter
  String _workflowPathForTemplate(String tpl) {
    switch (tpl) {
      case 'cpp_native':
        return '.github/workflows/cmake.yml';
      case 'flutter':
      case 'android_kotlin':
      case 'android_java':
        return '.github/workflows/android-apk.yml';
      default:
        return '.github/workflows/build.yml';
    }
  }

  String _workflowForTemplate(String tpl, String repoName) {
    switch (tpl) {
      case 'android_kotlin':
      case 'android_java':
        return _androidGradleWorkflow(repoName);
      case 'cpp_native':
        return _cppWorkflow(repoName);
      case 'flutter':
      default:
        return _flutterWorkflow(repoName);
    }
  }

  String _flutterWorkflow(String repoName) => '''
name: Build APK
on:
  push:
    branches: [main, master]
  workflow_dispatch:
    inputs:
      build_type:
        description: 'Build type (debug/release)'
        required: false
        default: 'debug'
        type: choice
        options: [debug, release]
      publish_release:
        description: 'Publish as GitHub Release'
        required: false
        default: 'false'
        type: choice
        options: ['false', 'true']
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: stable
      - name: Generate Android platform
        run: flutter create --platforms=android . || true
      - name: Install dependencies
        run: flutter pub get
      - name: Build APK
        run: |
          if [ "\${{ github.event.inputs.build_type }}" = "release" ]; then
            flutter build apk --release --no-tree-shake-icons
          else
            flutter build apk --debug --no-tree-shake-icons
          fi
      - uses: actions/upload-artifact@v4
        with:
          name: $repoName-apk
          path: build/app/outputs/flutter-apk/*.apk
''';

  String _androidGradleWorkflow(String repoName) => '''
name: Build APK
on:
  push:
    branches: [main, master]
  workflow_dispatch:
    inputs:
      build_type:
        description: 'Build type (debug/release)'
        required: false
        default: 'debug'
        type: choice
        options: [debug, release]
      publish_release:
        description: 'Publish as GitHub Release'
        required: false
        default: 'false'
        type: choice
        options: ['false', 'true']
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: '8.7'
      - name: Build APK
        run: |
          if [ "\${{ github.event.inputs.build_type }}" = "release" ]; then
            gradle assembleRelease
          else
            gradle assembleDebug
          fi
      - uses: actions/upload-artifact@v4
        with:
          name: $repoName-apk
          path: app/build/outputs/apk/**/*.apk
''';

  String _cppWorkflow(String repoName) => '''
name: Build Native
on:
  push:
    branches: [main, master]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure CMake
        run: cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
      - name: Build
        run: cmake --build build --config Release
      - name: Package executable only
        run: |
          set -e
          mkdir -p dist
          BIN="build/$repoName"
          if [ ! -f "\$BIN" ]; then
            BIN="\$(find build -maxdepth 3 -type f -executable ! -path '*/CMakeFiles/*' | head -n 1)"
          fi
          if [ -z "\$BIN" ] || [ ! -f "\$BIN" ]; then
            echo "No executable binary found under build/"
            find build -maxdepth 4 -type f | sort
            exit 1
          fi
          cp "\$BIN" "dist/$repoName-linux-x64"
          chmod +x "dist/$repoName-linux-x64"
          file "dist/$repoName-linux-x64"
      - uses: actions/upload-artifact@v4
        with:
          name: $repoName-linux-x64
          path: dist/$repoName-linux-x64
          if-no-files-found: error
''';


  // 模板文件内容
  Map<String, String> _templateFiles(String tpl, String repoName) {
    switch (tpl) {
      case 'flutter':
        return {
          'pubspec.yaml': '''name: ${repoName.replaceAll('-', '_').toLowerCase()}
description: A Flutter application.
version: 1.0.0+1
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''',
          'lib/main.dart': '''import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$repoName',
      home: Scaffold(
        appBar: AppBar(title: const Text('$repoName')),
        body: const Center(child: Text('Hello, World!')),
      ),
    );
  }
}
''',
          'README.md': '# $repoName\n\nA Flutter application.\n',
        };
      case 'android_kotlin':
        return {
          'settings.gradle': '''pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = '${repoName.replaceAll("'", "")}'
include ':app'
''',
          'build.gradle': '''plugins {
    id 'com.android.application' version '8.5.2' apply false
    id 'org.jetbrains.kotlin.android' version '1.9.24' apply false
}
''',
          'app/build.gradle': '''plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    namespace 'com.example.app'
    compileSdk 35

    defaultConfig {
        applicationId 'com.example.app'
        minSdk 23
        targetSdk 35
        versionCode 1
        versionName '1.0'
    }
}
''',
          'app/src/main/AndroidManifest.xml': '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:theme="@style/AppTheme" android:label="$repoName" android:allowBackup="true" android:supportsRtl="true">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
''',
          'app/src/main/res/values/styles.xml': '''<resources>
    <style name="AppTheme" parent="android:style/Theme.Material.Light.NoActionBar" />
</resources>
''',
          'app/src/main/java/com/example/app/MainActivity.kt': '''package com.example.app

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = TextView(this)
        text.text = "Hello, $repoName!"
        text.textSize = 22f
        text.gravity = android.view.Gravity.CENTER
        setContentView(text)
    }
}
''',
          'README.md': '# $repoName\n\nAn Android Kotlin application.\n',
        };
      case 'android_java':
        return {
          'settings.gradle': '''pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = '${repoName.replaceAll("'", "")}'
include ':app'
''',
          'build.gradle': '''plugins {
    id 'com.android.application' version '8.5.2' apply false
}
''',
          'app/build.gradle': '''plugins {
    id 'com.android.application'
}

android {
    namespace 'com.example.app'
    compileSdk 35

    defaultConfig {
        applicationId 'com.example.app'
        minSdk 23
        targetSdk 35
        versionCode 1
        versionName '1.0'
    }
}
''',
          'app/src/main/AndroidManifest.xml': '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:theme="@style/AppTheme" android:label="$repoName" android:allowBackup="true" android:supportsRtl="true">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
''',
          'app/src/main/res/values/styles.xml': '''<resources>
    <style name="AppTheme" parent="android:style/Theme.Material.Light.NoActionBar" />
</resources>
''',
          'app/src/main/java/com/example/app/MainActivity.java': '''package com.example.app;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TextView text = new TextView(this);
        text.setText("Hello, $repoName!");
        text.setTextSize(22f);
        text.setGravity(android.view.Gravity.CENTER);
        setContentView(text);
    }
}
''',
          'README.md': '# $repoName\n\nAn Android Java application.\n',
        };
      case 'cpp_native':
        return {
          'main.cpp': '''#include <iostream>

int main() {
    std::cout << "Hello, $repoName!" << std::endl;
    return 0;
}
''',
          'CMakeLists.txt': '''cmake_minimum_required(VERSION 3.10)
project($repoName)
set(CMAKE_CXX_STANDARD 17)
add_executable(\${PROJECT_NAME} main.cpp)
''',
          'README.md': '# $repoName\n\nA C++ native application.\n',
        };
      default:
        return {};
    }
  }

  @override
  void initState() {
    super.initState();
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    final key = owner != null && repo != null ? '$owner/$repo' : null;
    if (key != null && key == _cachedRepoKey && _cachedTree.containsKey('')) {
      _roots = _cachedTree['']!;
      _loadedRepoKey = key;
      _selectedPath = _selectedPathByRepo[key];
    }
    _fetchRepos();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _renameCtrl.dispose();
    super.dispose();
  }

  Future<void> _safePopOverlay() async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      await nav.maybePop();
    }
  }

  Future<void> _fetchRepos({bool force = false}) async {
    if (widget.state.github == null) return;
    if (!force && _repos.isNotEmpty) return;
    setState(() { _loadingRepos = true; _error = null; });
    try {
      _repos = await widget.state.github!.listRepositories();
      _cachedRepos = _repos;
    } catch (e) {
      _error = '仓库加载失败：$e';
    }
    if (mounted) setState(() => _loadingRepos = false);
  }

  Future<void> _selectRepo(String owner, String name) async {
    final key = '$owner/$name';
    widget.state.selectRepository(owner, name);
    if (_loadedRepoKey == key && _treeCache.containsKey('')) {
      setState(() {
        _roots = _treeCache['']!;
        _selectedPath = _selectedPathByRepo[key];
      });
      return;
    }
    setState(() { _roots = []; _selectedPath = _selectedPathByRepo[key]; });
    _loadedRepoKey = key;
    _cachedRepoKey = key;
    await _fetchTree('', force: false);
  }

  Future<void> _fetchTree(String path, {bool force = false}) async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    final repoKey = '$owner/$repo';
    if (_loadedRepoKey != repoKey) {
      _treeCache.clear();
      _cachedTree.clear();
      _loadedRepoKey = repoKey;
      _cachedRepoKey = repoKey;
    }
    if (!force && _treeCache.containsKey(path)) {
      if (path.isEmpty) {
        setState(() => _roots = _treeCache[path]!);
      } else {
        _insertChildren(_roots, path, _treeCache[path]!);
        setState(() {});
      }
      return;
    }
    setState(() { _loadingTree = true; _error = null; });
    try {
      final data = await widget.state.github!.getContents(owner, repo, path: path);
      final nodes = data.map((e) => _TreeNode(
        name: e['name'] as String,
        path: e['path'] as String,
        isDir: e['type'] == 'dir',
        sha: e['sha'] as String?,
        downloadUrl: e['download_url'] as String?,
      )).toList()
        ..sort((a, b) {
          if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      if (path.isEmpty) {
        _roots = nodes;
      } else {
        _insertChildren(_roots, path, nodes);
      }
      _treeCache[path] = nodes;
    } catch (e) {
      _error = '文件树加载失败：$e';
    }
    if (mounted) setState(() => _loadingTree = false);
  }

  void _insertChildren(List<_TreeNode> nodes, String path, List<_TreeNode> children) {
    for (final n in nodes) {
      if (n.path == path) {
        n.children = children;
        n.loading = false;
        return;
      }
      if (n.isDir && n.children.isNotEmpty) _insertChildren(n.children, path, children);
    }
  }

  Future<void> _toggleDir(_TreeNode node) async {
    if (!node.isDir) return;
    if (node.expanded) {
      setState(() => node.expanded = false);
      return;
    }
    if (node.children.isEmpty) {
      setState(() => node.loading = true);
      await _fetchTree(node.path);
    }
    if (mounted) setState(() { node.expanded = true; node.loading = false; });
  }

  Future<void> _openFile(_TreeNode node) async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null || node.isDir) return;
    final repoKey = '$owner/$repo';
    _selectedPathByRepo[repoKey] = node.path;
    setState(() { _openingPath = node.path; _selectedPath = node.path; });
    try {
      final name = node.name.toLowerCase();
      final binaryExt = ['png','jpg','jpeg','webp','gif','pdf','zip','apk','jar','so','a','dex','exe','bin','keystore','jks'];
      final ext = name.contains('.') ? name.split('.').last : '';
      if (binaryExt.contains(ext)) {
        if (!mounted) return;
        context.read<EditorState>().openFile(node.path, '二进制/资源文件无法在文本编辑器中直接编辑。\n\n文件：${node.path}\n类型：$ext', readOnlyFile: true, reason: '二进制文件');
        setState(() => _openingPath = null);
        return;
      }
      final file = await widget.state.github!.getFile(owner, repo, node.path);
      final size = (file['size'] as num?)?.toInt() ?? 0;
      final raw = (file['content'] as String).replaceAll('\n', '');
      final content = utf8.decode(base64Decode(raw), allowMalformed: true);
      if (!mounted) return;
      if (size > 512 * 1024 || content.length > 600000) {
        context.read<EditorState>().openFile(
          node.path,
          '${content.substring(0, content.length > 120000 ? 120000 : content.length)}\n\n/* 大文件已截断预览，仅展示前 120KB */',
          readOnlyFile: true,
          reason: '大文件预览模式',
        );
      } else {
        context.read<EditorState>().openFile(node.path, content);
      }
    } catch (e) {
      setState(() => _error = '打开失败：$e');
    }
    if (mounted) setState(() => _openingPath = null);
  }

  Future<void> _upload() async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    try {
      final svc = LocalFileUploadService();
      final file = await svc.pickOne();
      if (file == null) return;
      final bytes = await svc.bytesOf(file);
      await widget.state.github!.putFile(
        owner: owner,
        repo: repo,
        path: file.name,
        message: 'Upload ${file.name}',
        contentBase64: base64Encode(bytes),
      );
      await _fetchTree('', force: true);
    } catch (e) {
      setState(() => _error = '上传失败：$e');
    }
  }

  Future<void> _createRepo() async {
    final repoName = _nameCtrl.text.trim();
    if (repoName.isEmpty || widget.state.github == null) return;
    // GitHub 仓库名规则：只允许字母、数字、连字符、下划线、点
    final nameReg = RegExp(r'^[a-zA-Z0-9._-]+$');
    if (!nameReg.hasMatch(repoName)) {
      setState(() => _error = '仓库名只能包含字母、数字、连字符(-)、下划线(_)、点(.)，不支持中文或空格');
      return;
    }
    if (repoName.length > 100) {
      setState(() => _error = '仓库名不能超过 100 个字符');
      return;
    }
    setState(() { _loadingRepos = true; _error = null; });
    try {
      setState(() => _error = '正在创建仓库…');
      final r = await widget.state.github!.createRepository(
        name: repoName,
        private: _private,
        autoInit: _autoInit || _selectedTemplate != 'none',
        description: _descCtrl.text.trim(),
      );
      final owner = r['owner']['login'] as String;
      final name  = r['name'] as String;
      widget.state.selectRepository(owner, name);
      _nameCtrl.clear();
      _descCtrl.clear();

      // 推送模板文件
      if (_selectedTemplate != 'none') {
        final files = _templateFiles(_selectedTemplate, repoName);
        var pushed = 0;
        for (final entry in files.entries) {
          pushed++;
          if (mounted) setState(() => _error = '推送模板 $pushed/${files.length}：${entry.key}');
          try {
            await widget.state.github!.putFile(
              owner: owner,
              repo: name,
              path: entry.key,
              message: 'Init: add ${entry.key}',
              contentBase64: base64Encode(utf8.encode(entry.value)),
            );
          } catch (_) {}
        }
        // 推送 GitHub Actions workflow
        if (mounted) setState(() => _error = '推送 CI/CD 工作流…');
        try {
          final wf = _workflowForTemplate(_selectedTemplate, name);
          await widget.state.github!.putFile(
            owner: owner,
            repo: name,
            path: _workflowPathForTemplate(_selectedTemplate),
            message: 'Init: add GitHub Actions workflow',
            contentBase64: base64Encode(utf8.encode(wf)),
          );
        } catch (_) {}
      }

      await _fetchRepos(force: true);
      await _fetchTree('', force: true);
      await _safePopOverlay();
    } catch (e) {
      setState(() => _error = '创建失败：$e');
    }
    if (mounted) setState(() => _loadingRepos = false);
  }

  Future<void> _renameRepo() async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    final next = _renameCtrl.text.trim();
    if (owner == null || repo == null || next.isEmpty || widget.state.github == null) return;
    try {
      final r = await widget.state.github!.renameRepository(owner, repo, next);
      final newName = r['name'] as String;
      widget.state.selectRepository(owner, newName);
      await _fetchRepos(force: true);
      await _fetchTree('', force: true);
      await _safePopOverlay();
    } catch (e) {
      setState(() => _error = '重命名失败：$e');
    }
  }

  Future<void> _deleteRepo() async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    try {
      await widget.state.github!.deleteRepository(owner, repo);
      widget.state.clearRepositorySelection();
      setState(() => _roots = []);
      _treeCache.clear();
      await _fetchRepos(force: true);
      await _safePopOverlay();
    } catch (e) {
      setState(() => _error = '删除失败：$e');
    }
  }

  void _showFileMenu(_TreeNode node) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final renameCtrl = TextEditingController(text: node.name);
    _showSheet(title: node.isDir ? '文件夹操作' : '文件操作', children: [
      // 文件名预览
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(node.isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
              size: 15, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(node.path, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.7)), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      const SizedBox(height: 12),
      // 复制路径
      MxButton(
        label: '复制路径',
        icon: Icons.copy_rounded,
        filled: false,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: node.path));
          if (mounted) {
            await _safePopOverlay();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制路径'), duration: Duration(seconds: 1)));
          }
        },
      ),
      const SizedBox(height: 8),
      // 重命名（仅文件）
      if (!node.isDir) ...[
        MxTextField(controller: renameCtrl, hint: '新文件名', prefix: const Icon(Icons.drive_file_rename_outline_rounded, size: 17)),
        const SizedBox(height: 8),
        MxButton(
          label: '重命名并推送',
          icon: Icons.edit_rounded,
          onPressed: () async {
            final newName = renameCtrl.text.trim();
            if (newName.isEmpty || newName == node.name) { await _safePopOverlay(); return; }
            await _safePopOverlay();
            await _renameFile(node, newName);
          },
        ),
        const SizedBox(height: 8),
      ],
      // 删除
      MxButton(
        label: '删除文件',
        icon: Icons.delete_forever_rounded,
        color: Colors.red,
        onPressed: () async {
          await _safePopOverlay();
          final ok = await MxDialog.show(context,
            title: '确认删除？',
            content: '将删除 ${node.name}，此操作不可恢复。',
            confirmLabel: '删除',
            cancelLabel: '取消',
            confirmColor: Colors.red,
          );
          if (ok) await _deleteFile(node);
        },
      ),
    ]);
  }

  Future<void> _renameFile(_TreeNode node, String newName) async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    try {
      // GitHub 没有直接重命名 API，需要读取内容 → 新路径写入 → 删除旧路径
      final file = await widget.state.github!.getFile(owner, repo, node.path);
      final sha = file['sha'] as String?;
      final raw = (file['content'] as String).replaceAll('\n', '');
      final dir = node.path.contains('/') ? node.path.substring(0, node.path.lastIndexOf('/') + 1) : '';
      final newPath = '$dir$newName';
      await widget.state.github!.putFile(
        owner: owner, repo: repo, path: newPath,
        message: 'Rename ${node.name} to $newName',
        contentBase64: raw,
      );
      // 删除旧文件
      await widget.state.github!.deleteFile(owner: owner, repo: repo, path: node.path, sha: sha ?? '', message: 'Remove ${node.name} after rename');
      await _fetchTree('', force: true);
    } catch (e) {
      setState(() => _error = '重命名失败：$e');
    }
  }

  Future<void> _deleteFile(_TreeNode node) async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    try {
      if (node.isDir) {
        // 目录：递归列出并删除所有文件
        await _deleteDirRecursive(owner, repo, node.path);
      } else {
        final file = await widget.state.github!.getFile(owner, repo, node.path);
        final sha = file['sha'] as String?;
        await widget.state.github!.deleteFile(
          owner: owner, repo: repo, path: node.path,
          sha: sha ?? '', message: 'Delete ${node.name}',
        );
      }
      await _fetchTree('', force: true);
    } catch (e) {
      setState(() => _error = '删除失败：$e');
    }
  }

  Future<void> _deleteDirRecursive(String owner, String repo, String dirPath) async {
    final items = await widget.state.github!.getContents(owner, repo, path: dirPath);
    for (final item in items) {
      final itemPath = item['path'] as String;
      final itemType = item['type'] as String?;
      if (itemType == 'dir') {
        await _deleteDirRecursive(owner, repo, itemPath);
      } else {
        final sha = item['sha'] as String?;
        await widget.state.github!.deleteFile(
          owner: owner, repo: repo, path: itemPath,
          sha: sha ?? '', message: 'Delete $itemPath',
        );
      }
    }
  }

  void _showCreateSheet() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _selectedTemplate = 'none';
    _showSheet(title: '新建仓库', children: [
      MxTextField(controller: _nameCtrl, hint: '仓库名称', prefix: const Icon(Icons.folder_rounded, size: 17)),
      const SizedBox(height: 8),
      MxTextField(controller: _descCtrl, hint: '描述（可选）', prefix: const Icon(Icons.notes_rounded, size: 17)),
      const SizedBox(height: 10),
      StatefulBuilder(builder: (ctx, setSt) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchRow(label: '私有仓库', value: _private, onChanged: (v) => setSt(() => _private = v)),
          const SizedBox(height: 10),
          // 模板选择
          Text('项目模板', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 6),
          ..._templates.entries.map((e) {
            final selected = _selectedTemplate == e.key;
            final scheme = Theme.of(ctx).colorScheme;
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return GestureDetector(
              onTap: () => setSt(() => _selectedTemplate = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withOpacity(0.12)
                      : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? scheme.primary.withOpacity(0.5) : scheme.onSurface.withOpacity(0.10),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(e.value['icon'] as IconData, size: 16,
                      color: selected ? scheme.primary : scheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value['label'] as String,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected ? scheme.primary : scheme.onSurface.withOpacity(0.8)))),
                  if (selected) Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary),
                ]),
              ),
            );
          }),
        ],
      )),
      const SizedBox(height: 12),
      MxButton(label: '创建仓库', icon: Icons.add_rounded, onPressed: _createRepo),
    ]);
  }

  void _showManageSheet() {
    final repo = widget.state.selectedRepo;
    final owner = widget.state.selectedOwner;
    if (repo == null || repo.isEmpty) return;
    _renameCtrl.text = repo;
    _showSheet(title: '仓库管理', children: [
      if (owner != null) ...[
        MxButton(label: '复制仓库链接', icon: Icons.link_rounded, filled: false, onPressed: () async {
          await Clipboard.setData(ClipboardData(text: 'https://github.com/$owner/$repo.git'));
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制仓库链接')));
        }),
        const SizedBox(height: 10),
      ],
      MxTextField(controller: _renameCtrl, hint: '新仓库名称', prefix: const Icon(Icons.drive_file_rename_outline_rounded, size: 17)),
      const SizedBox(height: 10),
      MxButton(label: '重命名仓库', icon: Icons.edit_rounded, onPressed: _renameRepo),
      const SizedBox(height: 10),
      MxButton(label: '删除仓库', icon: Icons.delete_forever_rounded, color: Colors.red, onPressed: () async {
        final ok = await _confirmDelete(repo);
        if (ok) _deleteRepo();
      }),
      
    ]);
  }

  Future<bool> _confirmDelete(String repo) async {
    return MxDialog.show(context,
      title: '确认删除仓库？',
      content: '将永久删除 $repo，此操作不可恢复。',
      confirmLabel: '删除',
      cancelLabel: '取消',
      confirmColor: Colors.red,
    );
  }

  void _showSheet({required String title, required List<Widget> children}) {
    MxBottomSheet.show(context, title: title, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.state.selectedRepo;
    final editorPath = context.watch<EditorState>().currentPath;
    final effectiveSelectedPath = editorPath.isNotEmpty ? editorPath : _selectedPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RepoBar(
          repos: _repos,
          selected: selected,
          loading: _loadingRepos,
          onSelect: (r) => _selectRepo(r['owner']['login'] as String, r['name'] as String),
          onRefresh: () async { _treeCache.clear(); await _fetchRepos(force: true); if (selected != null && selected.isNotEmpty) await _fetchTree('', force: true); },
          onNew: _showCreateSheet,
          onUpload: _upload,
          onManage: _showManageSheet,
          canManage: selected != null && selected.isNotEmpty,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: MxCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProjectIdentityScreen())),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('项目配置', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              Icon(Icons.chevron_right_rounded, size: 16, color: scheme.onSurface.withOpacity(0.35)),
            ]),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        if (_loadingTree) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: selected == null || selected.isEmpty
              ? const MxEmpty(icon: Icons.folder_off_rounded, label: '未选择仓库', hint: '从上方选择、创建或管理 GitHub 仓库')
              : _roots.isEmpty && !_loadingTree
                  ? const MxEmpty(icon: Icons.description_outlined, label: '仓库为空', hint: '上传文件或等待初始化')
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _roots.length,
itemBuilder: (_, i) => _TreeTile(
                         node: _roots[i],
                         depth: 0,
                         onToggle: _toggleDir,
                         onOpen: _openFile,
                         scheme: scheme,
                         isDark: isDark,
                         selectedPath: effectiveSelectedPath,
                         openingPath: _openingPath,
                         onLongPress: _showFileMenu,
                       ),
                    ),
        ),
      ],
    );
  }
}

class _RepoBar extends StatelessWidget {
  const _RepoBar({required this.repos, required this.selected, required this.loading, required this.onSelect, required this.onRefresh, required this.onNew, required this.onUpload, required this.onManage, required this.canManage});
  final List<Map<String, dynamic>> repos;
  final String? selected;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onNew;
  final VoidCallback onUpload;
  final VoidCallback onManage;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0A1C2C) : const Color(0xFFEAF4FF)).withOpacity(0.95),
        border: Border(bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.06))),
      ),
      child: Row(children: [
        // 紧凑仓库选择器
        Expanded(
          child: repos.isEmpty
              ? Text(loading ? '加载中…' : '暂无仓库',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.4)))
              : _CompactRepoSelector(
                  repos: repos,
                  selected: selected,
                  isDark: isDark,
                  scheme: scheme,
                  onSelect: onSelect,
                ),
        ),
        const SizedBox(width: 2),
        MxIconBtn(icon: Icons.upload_file_rounded, onPressed: onUpload, tooltip: '上传', size: 30),
        MxIconBtn(icon: Icons.refresh_rounded, onPressed: onRefresh, tooltip: '刷新', size: 30),
        MxIconBtn(icon: Icons.create_new_folder_outlined, onPressed: onNew, tooltip: '新建', size: 30),
        MxIconBtn(icon: Icons.more_vert_rounded,
            onPressed: canManage ? onManage : null, tooltip: '管理', size: 30),
      ]),
    );
  }
}

// ─── 紧凑仓库选择器 ───────────────────────────────────────────────────────────
class _CompactRepoSelector extends StatelessWidget {
  const _CompactRepoSelector({
    required this.repos, required this.selected,
    required this.isDark, required this.scheme, required this.onSelect,
  });
  final List<Map<String, dynamic>> repos;
  final String? selected;
  final bool isDark;
  final ColorScheme scheme;
  final ValueChanged<Map<String, dynamic>> onSelect;

  @override
  Widget build(BuildContext context) {
    final current = selected == null || selected!.isEmpty ? null
        : repos.where((r) => r['name'] == selected).firstOrNull;
    final isPrivate = current?['private'] == true;

    return PopupMenuButton<String>(
      tooltip: '选择仓库',
      offset: const Offset(0, 32),
      color: isDark ? const Color(0xFF0A1C2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06)),
      ),
      onSelected: (name) {
        final r = repos.firstWhere((e) => e['name'] == name);
        onSelect(r);
      },
      itemBuilder: (_) => repos.map((r) {
        final name = r['name'] as String;
        final priv = r['private'] == true;
        final active = name == selected;
        return PopupMenuItem<String>(
          value: name,
          height: 36,
          child: Row(children: [
            Icon(priv ? Icons.lock_rounded : Icons.folder_open_rounded,
                size: 13,
                color: active ? scheme.primary : scheme.onSurface.withOpacity(0.5)),
            const SizedBox(width: 8),
            Expanded(child: Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? scheme.primary : scheme.onSurface.withOpacity(0.85)))),
          ]),
        );
      }).toList(),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: isDark
              ? Colors.white.withOpacity(0.10)
              : Colors.black.withOpacity(0.08)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            current == null ? Icons.folder_off_rounded
                : (isPrivate ? Icons.lock_rounded : Icons.folder_open_rounded),
            size: 12,
            color: current == null
                ? scheme.onSurface.withOpacity(0.3)
                : scheme.primary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              current == null ? '选择仓库' : (current['name'] as String),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: current == null
                      ? scheme.onSurface.withOpacity(0.4)
                      : scheme.onSurface.withOpacity(0.85)),
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.expand_more_rounded, size: 13,
              color: scheme.onSurface.withOpacity(0.4)),
        ]),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    MxSwitch(value: value, onChanged: onChanged),
  ]);
}

class _TreeTile extends StatefulWidget {
  const _TreeTile({required this.node, required this.depth, required this.onToggle, required this.onOpen, required this.scheme, required this.isDark, required this.selectedPath, required this.openingPath, required this.onLongPress});
  final _TreeNode node;
  final int depth;
  final Future<void> Function(_TreeNode) onToggle;
  final Future<void> Function(_TreeNode) onOpen;
  final ColorScheme scheme;
  final bool isDark;
  final String? selectedPath;
  final String? openingPath;
  final void Function(_TreeNode) onLongPress;

  @override
  State<_TreeTile> createState() => _TreeTileState();
}

class _TreeTileState extends State<_TreeTile> {
  IconData _icon() {
    final node = widget.node;
    if (node.isDir) return node.expanded ? Icons.folder_open_rounded : Icons.folder_rounded;
    final lower = node.name.toLowerCase();
    // 文件名级映射（精确）
    if (lower == 'package.json' || lower == 'package-lock.json' || lower == 'pnpm-lock.yaml' || lower == 'yarn.lock') return Icons.inventory_2_rounded;
    if (lower == 'dockerfile' || lower.endsWith('.dockerfile') || lower == '.dockerignore') return Icons.directions_boat_filled_rounded;
    if (lower == '.gitignore' || lower == '.gitattributes' || lower == '.gitmodules') return Icons.source_rounded;
    if (lower == 'pubspec.yaml' || lower == 'pubspec.yml' || lower == 'pubspec.lock') return Icons.flutter_dash_rounded;
    if (lower == 'cargo.toml' || lower == 'cargo.lock') return Icons.settings_rounded;
    if (lower == 'go.mod' || lower == 'go.sum') return Icons.hub_rounded;
    if (lower == 'cmakelists.txt' || lower.endsWith('.cmake')) return Icons.architecture_rounded;
    if (lower == 'makefile' || lower == 'gnumakefile') return Icons.build_rounded;
    if (lower.startsWith('readme')) return Icons.menu_book_rounded;
    if (lower.startsWith('license') || lower.startsWith('licence')) return Icons.gavel_rounded;
    if (lower.startsWith('changelog') || lower == 'history.md') return Icons.history_edu_rounded;
    if (lower.endsWith('.gradle') || lower.endsWith('.gradle.kts') || lower == 'gradle.properties' || lower == 'settings.gradle' || lower == 'build.gradle') return Icons.precision_manufacturing_rounded;
    if (lower == 'androidmanifest.xml') return Icons.android_rounded;
    if (lower.endsWith('.env') || lower == '.env' || lower.startsWith('.env.')) return Icons.vpn_key_rounded;
    if (lower == '.editorconfig' || lower.startsWith('.eslint') || lower.startsWith('.prettier')) return Icons.tune_rounded;
    if (lower.endsWith('.workflow.yml') || lower.endsWith('.workflow.yaml') ||
        lower.startsWith('.github/workflows/')) return Icons.play_circle_outline_rounded;

    final ext = lower.contains('.') ? lower.split('.').last : '';
    switch (ext) {
      // Dart / Flutter
      case 'dart': return Icons.bolt_rounded;
      // Web
      case 'js': case 'mjs': case 'cjs': return Icons.javascript_rounded;
      case 'ts': case 'tsx': return Icons.code_rounded;
      case 'jsx': return Icons.code_rounded;
      case 'vue': return Icons.layers_rounded;
      case 'svelte': return Icons.layers_outlined;
      case 'html': case 'htm': return Icons.html_rounded;
      case 'css': case 'scss': case 'sass': case 'less': return Icons.css_rounded;
      // 数据/配置
      case 'json': case 'json5': case 'jsonc': return Icons.data_object_rounded;
      case 'yaml': case 'yml': return Icons.list_alt_rounded;
      case 'toml': case 'ini': case 'cfg': case 'conf': case 'properties': return Icons.tune_rounded;
      case 'xml': case 'plist': return Icons.account_tree_rounded;
      case 'csv': case 'tsv': return Icons.table_chart_rounded;
      // 文档
      case 'md': case 'markdown': case 'mdx': return Icons.description_rounded;
      case 'txt': case 'log': return Icons.article_rounded;
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.description_outlined;
      case 'xls': case 'xlsx': return Icons.grid_on_rounded;
      case 'ppt': case 'pptx': return Icons.slideshow_rounded;
      // 编程语言
      case 'py': case 'pyw': case 'pyi': return Icons.psychology_rounded;
      case 'java': return Icons.coffee_rounded;
      case 'kt': case 'kts': return Icons.android_rounded;
      case 'c': case 'h': return Icons.memory_rounded;
      case 'cpp': case 'cc': case 'cxx': case 'hpp': case 'hxx': return Icons.developer_board_rounded;
      case 'cs': return Icons.tag_rounded;
      case 'rs': return Icons.settings_suggest_rounded;
      case 'go': return Icons.hub_outlined;
      case 'swift': return Icons.flight_rounded;
      case 'rb': return Icons.diamond_rounded;
      case 'php': return Icons.php_rounded;
      case 'lua': return Icons.dark_mode_rounded;
      case 'r': return Icons.bar_chart_rounded;
      case 'scala': return Icons.terrain_rounded;
      case 'sql': return Icons.storage_rounded;
      case 'dart_tool': return Icons.build_circle_rounded;
      // Shell / 脚本
      case 'sh': case 'bash': case 'zsh': case 'fish': return Icons.terminal_rounded;
      case 'ps1': case 'psm1': return Icons.terminal_rounded;
      case 'bat': case 'cmd': return Icons.terminal_rounded;
      // 图片
      case 'png': case 'jpg': case 'jpeg': case 'gif': case 'webp': case 'bmp': case 'tiff': return Icons.image_rounded;
      case 'svg': return Icons.brush_rounded;
      case 'ico': return Icons.app_shortcut_rounded;
      // 字体
      case 'ttf': case 'otf': case 'woff': case 'woff2': return Icons.font_download_rounded;
      // 视频
      case 'mp4': case 'mov': case 'avi': case 'mkv': case 'webm': case 'flv': return Icons.movie_rounded;
      // 音频
      case 'mp3': case 'wav': case 'ogg': case 'flac': case 'm4a': case 'aac': return Icons.music_note_rounded;
      // 压缩 / 包
      case 'zip': case 'rar': case '7z': case 'tar': case 'gz': case 'bz2': case 'xz': return Icons.archive_rounded;
      case 'apk': case 'aab': return Icons.android_rounded;
      case 'ipa': return Icons.apple_rounded;
      case 'jar': case 'war': case 'aar': return Icons.coffee_outlined;
      case 'so': case 'dll': case 'dylib': return Icons.memory_rounded;
      case 'exe': case 'msi': return Icons.terminal_rounded;
      case 'deb': case 'rpm': case 'dmg': case 'pkg': return Icons.inventory_rounded;
      case 'keystore': case 'jks': case 'pem': case 'p12': case 'pfx': case 'cer': case 'crt': case 'key': return Icons.lock_rounded;
      // 构建
      case 'gradle': return Icons.precision_manufacturing_rounded;
      case 'cmake': return Icons.architecture_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _iconColor() {
    final node = widget.node;
    if (node.isDir) return const Color(0xFFF5A623);
    final lower = node.name.toLowerCase();
    // 文件名级
    if (lower == 'package.json' || lower == 'package-lock.json' || lower == 'pnpm-lock.yaml' || lower == 'yarn.lock') return const Color(0xFFCB3837);
    if (lower == 'dockerfile' || lower.endsWith('.dockerfile') || lower == '.dockerignore') return const Color(0xFF2496ED);
    if (lower == '.gitignore' || lower == '.gitattributes' || lower == '.gitmodules') return const Color(0xFFF05032);
    if (lower.startsWith('pubspec')) return const Color(0xFF54C5F8);
    if (lower == 'cargo.toml' || lower == 'cargo.lock') return const Color(0xFFCE422B);
    if (lower == 'go.mod' || lower == 'go.sum') return const Color(0xFF00ADD8);
    if (lower == 'cmakelists.txt' || lower.endsWith('.cmake')) return const Color(0xFF064F8C);
    if (lower == 'makefile' || lower == 'gnumakefile') return const Color(0xFF6D4C41);
    if (lower.startsWith('readme')) return const Color(0xFF42A5F5);
    if (lower.startsWith('license') || lower.startsWith('licence')) return const Color(0xFF8E63CE);
    if (lower.endsWith('.gradle') || lower.endsWith('.gradle.kts') || lower == 'gradle.properties' || lower == 'settings.gradle' || lower == 'build.gradle') return const Color(0xFF02303A);
    if (lower == 'androidmanifest.xml') return const Color(0xFF3DDC84);
    if (lower.endsWith('.env') || lower == '.env' || lower.startsWith('.env.')) return const Color(0xFFFFD54F);

    final ext = lower.contains('.') ? lower.split('.').last : '';
    switch (ext) {
      case 'dart': return const Color(0xFF02569B);
      case 'js': case 'mjs': case 'cjs': return const Color(0xFFF7DF1E);
      case 'ts': case 'tsx': return const Color(0xFF3178C6);
      case 'jsx': return const Color(0xFF61DAFB);
      case 'vue': return const Color(0xFF42B883);
      case 'svelte': return const Color(0xFFFF3E00);
      case 'html': case 'htm': return const Color(0xFFE34F26);
      case 'css': return const Color(0xFF1572B6);
      case 'scss': case 'sass': return const Color(0xFFCC6699);
      case 'less': return const Color(0xFF1D365D);
      case 'json': case 'json5': case 'jsonc': return const Color(0xFFFAB005);
      case 'yaml': case 'yml': return const Color(0xFFCB171E);
      case 'toml': case 'ini': case 'cfg': case 'conf': case 'properties': return const Color(0xFF8E63CE);
      case 'xml': case 'plist': return const Color(0xFFFF8A50);
      case 'csv': case 'tsv': return const Color(0xFF1E8E3E);
      case 'md': case 'markdown': case 'mdx': return const Color(0xFF519ABA);
      case 'txt': case 'log': return const Color(0xFF9E9E9E);
      case 'pdf': return const Color(0xFFE53935);
      case 'doc': case 'docx': return const Color(0xFF2B579A);
      case 'xls': case 'xlsx': return const Color(0xFF217346);
      case 'ppt': case 'pptx': return const Color(0xFFD24726);
      case 'py': case 'pyw': case 'pyi': return const Color(0xFF3776AB);
      case 'java': return const Color(0xFFED8B00);
      case 'kt': case 'kts': return const Color(0xFF7F52FF);
      case 'c': case 'h': return const Color(0xFFA8B9CC);
      case 'cpp': case 'cc': case 'cxx': case 'hpp': case 'hxx': return const Color(0xFF00599C);
      case 'cs': return const Color(0xFF512BD4);
      case 'rs': return const Color(0xFFCE422B);
      case 'go': return const Color(0xFF00ADD8);
      case 'swift': return const Color(0xFFF05138);
      case 'rb': return const Color(0xFFCC342D);
      case 'php': return const Color(0xFF777BB4);
      case 'lua': return const Color(0xFF000080);
      case 'r': return const Color(0xFF276DC3);
      case 'scala': return const Color(0xFFDC322F);
      case 'sql': return const Color(0xFF00758F);
      case 'sh': case 'bash': case 'zsh': case 'fish': return const Color(0xFF4EAA25);
      case 'ps1': case 'psm1': return const Color(0xFF012456);
      case 'bat': case 'cmd': return const Color(0xFF888888);
      case 'png': case 'jpg': case 'jpeg': case 'gif': case 'webp': case 'bmp': case 'tiff': return const Color(0xFF26A69A);
      case 'svg': return const Color(0xFFFFB300);
      case 'ico': return const Color(0xFF7E57C2);
      case 'ttf': case 'otf': case 'woff': case 'woff2': return const Color(0xFF6A1B9A);
      case 'mp4': case 'mov': case 'avi': case 'mkv': case 'webm': case 'flv': return const Color(0xFFE91E63);
      case 'mp3': case 'wav': case 'ogg': case 'flac': case 'm4a': case 'aac': return const Color(0xFF8E24AA);
      case 'zip': case 'rar': case '7z': case 'tar': case 'gz': case 'bz2': case 'xz': return const Color(0xFFFFA000);
      case 'apk': case 'aab': return const Color(0xFF3DDC84);
      case 'ipa': return const Color(0xFF666666);
      case 'jar': case 'war': case 'aar': return const Color(0xFFED8B00);
      case 'so': case 'dll': case 'dylib': return const Color(0xFF607D8B);
      case 'exe': case 'msi': return const Color(0xFF455A64);
      case 'deb': case 'rpm': case 'dmg': case 'pkg': return const Color(0xFF6D4C41);
      case 'keystore': case 'jks': case 'pem': case 'p12': case 'pfx': case 'cer': case 'crt': case 'key': return const Color(0xFFD32F2F);
      case 'gradle': return const Color(0xFF02303A);
      case 'cmake': return const Color(0xFF064F8C);
      default: return widget.scheme.onSurface.withOpacity(0.50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final scheme = widget.scheme;
    final isDark = widget.isDark;
    const rowH = 30.0;
    final indent = 10.0 + widget.depth * 15.0;
    final isSelected = widget.selectedPath == node.path;
    final isOpening  = widget.openingPath  == node.path;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withOpacity(isDark ? 0.20 : 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: scheme.primary.withOpacity(isDark ? 0.45 : 0.34), width: 0.8)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withOpacity(isDark ? 0.28 : 0.20),
                    blurRadius: 14,
                    spreadRadius: -1,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => node.isDir ? widget.onToggle(node) : widget.onOpen(node),
          onLongPress: () => widget.onLongPress(node),
          child: SizedBox(
            height: rowH,
            child: Row(children: [
              SizedBox(width: indent),
              SizedBox(width: 16, child: node.isDir
                ? node.loading
                  ? SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: scheme.primary),
                    )
                  : Icon(node.expanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, size: 16, color: scheme.onSurface.withOpacity(0.45))
                : isOpening
                  ? SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: scheme.primary),
                    )
                  : null),
              const SizedBox(width: 2),
              Icon(_icon(), size: 15, color: _iconColor()),
              const SizedBox(width: 6),
              Expanded(child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13,
                      fontWeight: node.isDir ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? scheme.primary
                          : scheme.onSurface.withOpacity(0.85)))),
            ]),
          ),
        ),
      ),
      if (node.isDir && node.expanded)
        ...node.children.map((child) => _TreeTile(
          node: child, depth: widget.depth + 1,
          onToggle: widget.onToggle, onOpen: widget.onOpen,
          scheme: scheme, isDark: isDark,
          selectedPath: widget.selectedPath,
          openingPath: widget.openingPath,
          onLongPress: widget.onLongPress,
        )),
    ]);
  }
}
