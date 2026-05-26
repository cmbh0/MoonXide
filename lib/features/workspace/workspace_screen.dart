import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';
import '../../core/services/local_file_upload_service.dart';

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

  final _scrollH = ScrollController();
  final _scrollV = ScrollController();

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
  final _newFileCtrl = TextEditingController();
  final _newFolderCtrl = TextEditingController();
  bool _private = true;
  bool _autoInit = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapWorkspace());
  }

  @override
  void didUpdateWidget(covariant WorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.github != widget.state.github ||
        oldWidget.state.selectedRepo != widget.state.selectedRepo ||
        oldWidget.state.selectedOwner != widget.state.selectedOwner) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapWorkspace());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _renameCtrl.dispose();
    _newFileCtrl.dispose();
    _newFolderCtrl.dispose();
    _scrollH.dispose();
    _scrollV.dispose();
    super.dispose();
  }

  Future<void> _bootstrapWorkspace() async {
    if (!mounted || widget.state.github == null) return;
    await _fetchRepos(force: _repos.isEmpty);
    if (!mounted) return;
    final selectedRepo = widget.state.selectedRepo;
    final selectedOwner = widget.state.selectedOwner;
    if (selectedRepo != null && selectedOwner != null && selectedRepo.isNotEmpty) {
      await _selectRepo(selectedOwner, selectedRepo);
    } else if (_repos.isNotEmpty) {
      final first = _repos.first;
      await _selectRepo(first['owner']['login'] as String, first['name'] as String);
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
      final ext = name.contains('.') ? name.split('.').last : '';
      final binaryExt = ['png','jpg','jpeg','webp','gif','pdf','zip','apk','jar','so','a','dex','exe','bin','keystore','jks','exe','dll','sys','obj','lib','o','out','app','dmg','iso','tar','gz','bz2','7z','rar','tgz'];
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
      if (size > 1024 * 1024 || content.length > 1200000) {
        context.read<EditorState>().openFile(
          node.path,
          '${content.substring(0, content.length > 250000 ? 250000 : content.length)}\n\n/* 大文件已截断预览，仅展示前 250KB */',
          readOnlyFile: true,
          reason: '大文件预览模式',
        );
      } else {
        context.read<EditorState>().openFile(node.path, content);
      }
      // 在打开/保存文件时，同步更新该文件的语法错误处理（此处由编辑器核心逻辑在 EditorScreen build 中更新 diagnostics 表现）
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
        autoInit: _autoInit,
        description: _descCtrl.text.trim(),
      );
      final owner = r['owner']['login'] as String;
      final name  = r['name'] as String;
      widget.state.selectRepository(owner, name);
      _nameCtrl.clear();
      _descCtrl.clear();


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

  Future<void> _safePopOverlay() async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  Future<void> _invalidateAndRefresh([String path = '']) async {
    _treeCache.clear();
    _cachedTree.clear();
    await _fetchTree(path, force: true);
  }

  String _joinPath(String parent, String name) => parent.isEmpty ? name : '$parent/$name';

  Future<void> _createFileAt(String parentPath, String name) async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null || name.trim().isEmpty) return;
    final path = _joinPath(parentPath, name.trim());
    try {
      await widget.state.github!.putFile(
        owner: owner,
        repo: repo,
        path: path,
        message: 'Create $path',
        contentBase64: base64Encode(utf8.encode('')),
      );
      await _invalidateAndRefresh('');
    } catch (e) {
      setState(() => _error = '新建文件失败：$e');
    }
  }

  Future<void> _createFolderAt(String parentPath, String name) async {
    final folder = name.trim().replaceAll(RegExp(r'/+$'), '');
    if (folder.isEmpty) return;
    await _createFileAt(_joinPath(parentPath, folder), '.gitkeep');
  }

  void _showNewItemSheet({_TreeNode? parent}) {
    final parentPath = parent?.path ?? '';
    _newFileCtrl.clear();
    _newFolderCtrl.clear();
    _showSheet(title: parent == null ? '新建' : '在 ${parent.name} 中新建', children: [
      MxTextField(controller: _newFileCtrl, hint: '新文件名，例如 lib/main.dart', prefix: const Icon(Icons.note_add_rounded, size: 17)),
      const SizedBox(height: 8),
      MxButton(label: '新建文件', icon: Icons.note_add_rounded, onPressed: () async {
        await _safePopOverlay();
        await _createFileAt(parentPath, _newFileCtrl.text);
      }),
      const SizedBox(height: 14),
      MxTextField(controller: _newFolderCtrl, hint: '新文件夹名，例如 src', prefix: const Icon(Icons.create_new_folder_rounded, size: 17)),
      const SizedBox(height: 8),
      MxButton(label: '新建文件夹', icon: Icons.create_new_folder_rounded, filled: false, onPressed: () async {
        await _safePopOverlay();
        await _createFolderAt(parentPath, _newFolderCtrl.text);
      }),
    ]);
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
      if (node.isDir) ...[
        MxButton(
          label: '在此新建文件 / 文件夹',
          icon: Icons.add_rounded,
          filled: false,
          onPressed: () async { await _safePopOverlay(); _showNewItemSheet(parent: node); },
        ),
        const SizedBox(height: 8),
      ],
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
          onNewItem: () => _showNewItemSheet(),
          onManage: _showManageSheet,
          canManage: selected != null && selected.isNotEmpty,
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
                  : Scrollbar(
                      controller: _scrollV,
                      child: SingleChildScrollView(
                        controller: _scrollV,
                        child: Scrollbar(
                          controller: _scrollH,
                          notificationPredicate: (n) => n.depth == 1,
                          child: SingleChildScrollView(
                            controller: _scrollH,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 600, // 足够宽，允许左右滚动长文件名
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
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
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _RepoBar extends StatelessWidget {
  const _RepoBar({required this.repos, required this.selected, required this.loading, required this.onSelect, required this.onRefresh, required this.onNew, required this.onUpload, required this.onNewItem, required this.onManage, required this.canManage});
  final List<Map<String, dynamic>> repos;
  final String? selected;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onNew;
  final VoidCallback onUpload;
  final VoidCallback onNewItem;
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
        MxIconBtn(icon: Icons.note_add_rounded, onPressed: canManage ? onNewItem : null, tooltip: '新建文件/文件夹', size: 30),
        MxIconBtn(icon: Icons.refresh_rounded, onPressed: onRefresh, tooltip: '刷新', size: 30),
        MxIconBtn(icon: Icons.create_new_folder_outlined, onPressed: onNew, tooltip: '新建仓库', size: 30),
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
        : repos.where((r) => r['name'] == selected || r['full_name'] == selected).firstOrNull;
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
        final active = name == selected || r['full_name'] == selected;
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

class _FileGlyph extends StatelessWidget {
  const _FileGlyph({required this.icon, required this.color, this.badge, this.ext});

  final IconData icon;
  final Color color;
  final String? badge;
  final String? ext;

  static const _devicon = {
    'dart': 'dart', 'js': 'javascript', 'mjs': 'javascript', 'cjs': 'javascript',
    'ts': 'typescript', 'jsx': 'react', 'tsx': 'react', 'py': 'python', 'pyw': 'python',
    'java': 'java', 'kt': 'kotlin', 'kts': 'kotlin', 'c': 'c', 'h': 'c',
    'cpp': 'cplusplus', 'cc': 'cplusplus', 'cxx': 'cplusplus', 'hpp': 'cplusplus',
    'cs': 'csharp', 'rs': 'rust', 'go': 'go', 'swift': 'swift', 'rb': 'ruby',
    'php': 'php', 'lua': 'lua', 'r': 'r', 'html': 'html5', 'css': 'css3',
    'vue': 'vuejs', 'svg': 'svg', 'md': 'markdown', 'json': 'json', 'yml': 'yaml',
    'yaml': 'yaml', 'sh': 'bash', 'bash': 'bash', 'zsh': 'bash', 'bat': 'windows',
    'cmd': 'windows', 'ps1': 'powershell', 'gradle': 'gradle', 'properties': 'java',
    'xml': 'html5', 'toml': 'toml', 'sql': 'mysql', 'dockerfile': 'docker',
  };

  @override
  Widget build(BuildContext context) {
    final key = ext == null ? null : _devicon[ext!.toLowerCase()];
    if (key != null) {
      return SizedBox(
        width: 16,
        height: 16,
        child: SvgPicture.network(
          'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/$key/$key-original.svg',
          placeholderBuilder: (_) => Icon(icon, size: 15, color: color),
        ),
      );
    }
    if (badge == null) return Icon(icon, size: 15, color: color);
    return Container(
      width: 20,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.62), width: 0.8),
      ),
      child: Text(
        badge!,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: color,
          fontSize: badge!.length > 3 ? 6.2 : 7.4,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.35,
        ),
      ),
    );
  }
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

  String? _languageBadge() {
    if (widget.node.isDir) return null;
    final lower = widget.node.name.toLowerCase();
    final ext = lower.contains('.') ? lower.split('.').last : '';
    switch (ext) {
      case 'dart': return 'D';
      case 'js': case 'mjs': case 'cjs': return 'JS';
      case 'ts': return 'TS';
      case 'jsx': return 'JSX';
      case 'tsx': return 'TSX';
      case 'py': case 'pyw': case 'pyi': return 'PY';
      case 'java': return 'JV';
      case 'kt': case 'kts': return 'KT';
      case 'c': return 'C';
      case 'h': return 'H';
      case 'cpp': case 'cc': case 'cxx': return 'C++';
      case 'hpp': case 'hxx': return 'H++';
      case 'cs': return 'C#';
      case 'rs': return 'RS';
      case 'go': return 'GO';
      case 'swift': return 'SW';
      case 'rb': return 'RB';
      case 'php': return 'PHP';
      case 'lua': return 'LUA';
      case 'r': return 'R';
      case 'scala': return 'SC';
      case 'sql': return 'SQL';
      case 'sh': case 'bash': case 'zsh': case 'fish': return 'SH';
      case 'ps1': case 'psm1': return 'PS';
      case 'bat': case 'cmd': return 'BAT';
      case 'html': case 'htm': return 'HTML';
      case 'css': return 'CSS';
      case 'scss': return 'SCSS';
      case 'sass': return 'SASS';
      case 'less': return 'LESS';
      case 'vue': return 'VUE';
      case 'svelte': return 'SV';
      default: return null;
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
          borderRadius: BorderRadius.circular(6),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => node.isDir ? widget.onToggle(node) : widget.onOpen(node),
          onLongPress: () => widget.onLongPress(node),
          child: SizedBox(
            height: rowH,
            child: Row(children: [
              SizedBox(width: indent),
              SizedBox(width: 16, child: node.isDir
                ? node.loading
                  ? Center(
                      child: SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: scheme.primary),
                      ),
                    )
                  : Icon(node.expanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, size: 16, color: scheme.onSurface.withOpacity(0.45))
                : isOpening
                  ? Center(
                      child: SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: scheme.primary),
                      ),
                    )
                  : null),
              const SizedBox(width: 2),
              _FileGlyph(icon: _icon(), color: _iconColor(), badge: _languageBadge(), ext: node.name.contains('.') ? node.name.toLowerCase().split('.').last : null),
              const SizedBox(width: 6),
              Expanded(child: Text(node.name, maxLines: 1, overflow: TextOverflow.visible,
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
