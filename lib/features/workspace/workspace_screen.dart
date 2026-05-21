import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';
import '../../core/services/local_file_upload_service.dart';
import '../package_editor/package_editor_screen.dart';

class _TreeNode {
  final String name;
  final String path;
  final bool isDir;
  final String? sha;
  final String? downloadUrl;
  bool expanded;
  bool loading;
  List<_TreeNode> children;

  _TreeNode({
    required this.name,
    required this.path,
    required this.isDir,
    this.sha,
    this.downloadUrl,
    this.expanded = false,
    this.loading = false,
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

  List<Map<String, dynamic>> _repos = _cachedRepos;
  List<_TreeNode> _roots = [];
  final Map<String, List<_TreeNode>> _treeCache = _cachedTree;
  String? _loadedRepoKey = _cachedRepoKey;
  bool _loadingRepos = false;
  bool _loadingTree = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _renameCtrl = TextEditingController();
  bool _private = true;
  bool _autoInit = true;

  @override
  void initState() {
    super.initState();
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    final key = owner != null && repo != null ? '$owner/$repo' : null;
    if (key != null && key == _cachedRepoKey && _cachedTree.containsKey('')) {
      _roots = _cachedTree['']!;
      _loadedRepoKey = key;
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
      setState(() => _roots = _treeCache['']!);
      return;
    }
    setState(() => _roots = []);
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
    try {
      final name = node.name.toLowerCase();
      final binaryExt = ['png','jpg','jpeg','webp','gif','pdf','zip','apk','jar','so','a','dex','exe','bin','keystore','jks'];
      final ext = name.contains('.') ? name.split('.').last : '';
      if (binaryExt.contains(ext)) {
        if (!mounted) return;
        context.read<EditorState>().openFile(node.path, '二进制/资源文件无法在文本编辑器中直接编辑。\n\n文件：${node.path}\n类型：$ext', readOnlyFile: true, reason: '二进制文件');
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
          '${content.substring(0, content.length > 120000 ? 120000 : content.length)}\n\n/* 大文件已分页截断预览，仅展示前 120KB，避免移动端渲染卡顿。请使用 AI 或下载后处理完整文件。 */',
          readOnlyFile: true,
          reason: '大文件预览模式',
        );
      } else {
        context.read<EditorState>().openFile(node.path, content);
      }
    } catch (e) {
      setState(() => _error = '打开失败：$e');
    }
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
    if (_nameCtrl.text.trim().isEmpty || widget.state.github == null) return;
    setState(() => _loadingRepos = true);
    try {
      final r = await widget.state.github!.createRepository(
        name: _nameCtrl.text.trim(),
        private: _private,
        autoInit: _autoInit,
        description: _descCtrl.text.trim(),
      );
      final owner = r['owner']['login'] as String;
      final name = r['name'] as String;
      widget.state.selectRepository(owner, name);
      _nameCtrl.clear();
      _descCtrl.clear();
      await _fetchRepos(force: true);
      await _fetchTree('', force: true);
      if (mounted) Navigator.pop(context);
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
      if (mounted) Navigator.pop(context);
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '删除失败：$e');
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
      StatefulBuilder(builder: (ctx, setSt) => Column(children: [
_SwitchRow(label: '私有仓库', value: _private, onChanged: (v) => setSt(() => _private = v)),
        _SwitchRow(label: '初始化 README', value: _autoInit, onChanged: (v) => setSt(() => _autoInit = v)),
      ])),
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
      const SizedBox(height: 8),
      Text('删除仓库不可恢复，需要 GitHub Token 拥有 delete_repo 权限。', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A1C2C) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
              boxShadow: [BoxShadow(color: const Color(0xFF3B8FC7).withOpacity(0.16), blurRadius: 28, offset: const Offset(0, -6))],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 34, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: scheme.onSurface.withOpacity(0.16), borderRadius: BorderRadius.circular(2)))),
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  ...children,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.state.selectedRepo;

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
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackageEditorScreen())),
            child: Row(children: [
              Icon(Icons.apps_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('安装包编辑 / 编译模板', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0A1C2C) : const Color(0xFFEAF4FF)).withOpacity(0.95),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.06))),
      ),
      child: Row(children: [
        Expanded(
          child: repos.isEmpty
              ? Text(loading ? '加载仓库中…' : '暂无仓库', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.45)))
              : MxDropdown<String>(
                  value: selected == null || selected!.isEmpty ? null : selected,
                  hint: '点击选择仓库',
                  items: repos.map((r) => MxDropdownItem<String>(
                    value: r['name'] as String,
                    label: r['name'] as String,
                    icon: r['private'] == true ? Icons.lock_rounded : Icons.folder_open_rounded,
                  )).toList(),
                  onChanged: (name) {
                    if (name == null) return;
                    final r = repos.firstWhere((e) => e['name'] == name);
                    onSelect(r);
                  },
                ),
        ),
        MxIconBtn(icon: Icons.upload_rounded, onPressed: onUpload, tooltip: '上传', size: 32),
        MxIconBtn(icon: Icons.refresh_rounded, onPressed: onRefresh, tooltip: '刷新', size: 32),
        MxIconBtn(icon: Icons.add_rounded, onPressed: onNew, tooltip: '新建仓库', size: 32),
        MxIconBtn(icon: Icons.more_horiz_rounded, onPressed: canManage ? onManage : null, tooltip: '管理仓库', size: 32),
      ]),
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

class _TreeTile extends StatelessWidget {
  const _TreeTile({required this.node, required this.depth, required this.onToggle, required this.onOpen, required this.scheme, required this.isDark});
  final _TreeNode node;
  final int depth;
  final Future<void> Function(_TreeNode) onToggle;
  final Future<void> Function(_TreeNode) onOpen;
  final ColorScheme scheme;
  final bool isDark;

  IconData _icon() {
    if (node.isDir) return node.expanded ? Icons.folder_open_rounded : Icons.folder_rounded;
    final lower = node.name.toLowerCase();
    if (lower == 'package.json') return Icons.inventory_2_rounded;
    if (lower == 'dockerfile') return Icons.directions_boat_rounded;
    if (lower == '.gitignore') return Icons.hide_source_rounded;
    if (lower == 'pubspec.yaml' || lower == 'pubspec.yml') return Icons.flutter_dash;
    if (lower == 'gradle.properties' || lower == 'settings.gradle' || lower == 'build.gradle') return Icons.precision_manufacturing_rounded;
    final ext = lower.contains('.') ? lower.split('.').last : '';
    switch (ext) {
      case 'dart': return Icons.flutter_dash;
      case 'js': case 'mjs': case 'cjs': return Icons.data_object_rounded;
      case 'ts': return Icons.code_rounded;
      case 'py': return Icons.smart_toy_rounded;
      case 'java': return Icons.local_cafe_rounded;
      case 'kt': case 'kts': return Icons.android_rounded;
      case 'c': case 'h': return Icons.memory_rounded;
      case 'cpp': case 'cc': case 'cxx': case 'hpp': return Icons.developer_board_rounded;
      case 'html': return Icons.web_asset_rounded;
      case 'css': return Icons.palette_rounded;
      case 'json': return Icons.data_object_rounded;
      case 'yaml': case 'yml': return Icons.tune_rounded;
      case 'xml': return Icons.code_rounded;
      case 'md': return Icons.article_rounded;
      case 'sh': case 'bash': return Icons.terminal_rounded;
      case 'png': case 'jpg': case 'jpeg': case 'svg': case 'webp': return Icons.image_rounded;
      case 'gradle': return Icons.precision_manufacturing_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _iconColor() {
    if (node.isDir) return const Color(0xFFF5A623);
    final lower = node.name.toLowerCase();
    if (lower == 'package.json') return const Color(0xFFCB3837);
    if (lower == 'dockerfile') return const Color(0xFF2496ED);
    if (lower == '.gitignore') return const Color(0xFFF05032);
    if (lower.startsWith('pubspec')) return const Color(0xFF54C5F8);
    final ext = lower.contains('.') ? lower.split('.').last : '';
    switch (ext) {
      case 'dart': return const Color(0xFF54C5F8);
      case 'js': case 'mjs': case 'cjs': return const Color(0xFFF7DF1E);
      case 'ts': return const Color(0xFF3178C6);
      case 'py': return const Color(0xFF3776AB);
      case 'java': return const Color(0xFFED8B00);
      case 'kt': case 'kts': return const Color(0xFF7F52FF);
      case 'c': case 'h': return const Color(0xFFA8B9CC);
      case 'cpp': case 'cc': case 'cxx': case 'hpp': return const Color(0xFF00599C);
      case 'html': return const Color(0xFFE34F26);
      case 'css': return const Color(0xFF1572B6);
      case 'json': case 'yaml': case 'yml': return const Color(0xFF6DB33F);
      case 'md': return const Color(0xFF519ABA);
      case 'sh': case 'bash': return const Color(0xFF4EAA25);
      default: return scheme.onSurface.withOpacity(0.50);
    }
  }

  @override
  Widget build(BuildContext context) {
    const rowH = 30.0;
    final indent = 10.0 + depth * 15.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () => node.isDir ? onToggle(node) : onOpen(node),
        child: SizedBox(
          height: rowH,
          child: Row(children: [
            SizedBox(width: indent),
            SizedBox(width: 16, child: node.isDir
              ? node.loading
                ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
                : Icon(node.expanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, size: 16, color: scheme.onSurface.withOpacity(0.45))
              : null),
            const SizedBox(width: 2),
            Icon(_icon(), size: 15, color: _iconColor()),
            const SizedBox(width: 6),
            Expanded(child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: node.isDir ? FontWeight.w600 : FontWeight.w400, color: scheme.onSurface.withOpacity(0.85)))),
          ]),
        ),
      ),
      if (node.isDir && node.expanded)
        ...node.children.map((child) => _TreeTile(node: child, depth: depth + 1, onToggle: onToggle, onOpen: onOpen, scheme: scheme, isDark: isDark)),
    ]);
  }
}
