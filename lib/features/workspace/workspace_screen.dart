import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';
import '../../core/services/local_file_upload_service.dart';

// ─── 文件树节点 ───────────────────────────────────────────────────────────────
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

// ─── 主屏 ─────────────────────────────────────────────────────────────────────
class WorkspaceScreen extends StatefulWidget {
  final AppState state;
  const WorkspaceScreen({super.key, required this.state});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  List<Map<String, dynamic>> _repos = [];
  List<_TreeNode> _roots = [];
  bool _loadingRepos = false;
  bool _loadingTree  = false;
  String? _error;

  // 新建仓库表单
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _private   = true;
  bool _autoInit  = true;

  @override
  void initState() {
    super.initState();
    _fetchRepos();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── 数据加载 ────────────────────────────────────────────────────────────────
  Future<void> _fetchRepos() async {
    if (widget.state.github == null) return;
    setState(() { _loadingRepos = true; _error = null; });
    try {
      _repos = await widget.state.github!.listRepositories();
    } catch (e) {
      _error = '仓库加载失败：$e';
    }
    setState(() => _loadingRepos = false);
  }

  Future<void> _selectRepo(String owner, String name) async {
    widget.state.selectRepository(owner, name);
    await _fetchTree('');
  }

  Future<void> _fetchTree(String path) async {
    final owner = widget.state.selectedOwner;
    final repo  = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
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
        setState(() => _roots = nodes);
      } else {
        _insertChildren(_roots, path, nodes);
        setState(() {});
      }
    } catch (e) {
      setState(() => _error = '文件树加载失败：$e');
    }
    setState(() => _loadingTree = false);
  }

  void _insertChildren(List<_TreeNode> nodes, String path, List<_TreeNode> children) {
    for (final n in nodes) {
      if (n.path == path) {
        n.children = children;
        n.loading  = false;
        return;
      }
      if (n.isDir && n.children.isNotEmpty) {
        _insertChildren(n.children, path, children);
      }
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
    setState(() { node.expanded = true; node.loading = false; });
  }

  Future<void> _openFile(_TreeNode node) async {
    final owner = widget.state.selectedOwner;
    final repo  = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    try {
      final file    = await widget.state.github!.getFile(owner, repo, node.path);
      final raw     = (file['content'] as String).replaceAll('\n', '');
      final content = utf8.decode(base64Decode(raw));
      if (!mounted) return;
      context.read<EditorState>().openFile(node.path, content);
    } catch (e) {
      setState(() => _error = '打开失败：$e');
    }
  }

  Future<void> _upload() async {
    final owner = widget.state.selectedOwner;
    final repo  = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    try {
      final svc  = LocalFileUploadService();
      final file = await svc.pickOne();
      if (file == null) return;
      final bytes = await svc.bytesOf(file);
      await widget.state.github!.putFile(
        owner: owner, repo: repo,
        path: file.name,
        message: 'Upload ${file.name}',
        contentBase64: base64Encode(bytes),
      );
      await _fetchTree('');
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
      final name  = r['name'] as String;
      widget.state.selectRepository(owner, name);
      await _fetchRepos();
      await _fetchTree('');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '创建失败：$e');
    }
    setState(() => _loadingRepos = false);
  }

  // ── 新建仓库底部弹窗 ────────────────────────────────────────────────────────
  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final isDark  = Theme.of(ctx).brightness == Brightness.dark;
          final scheme  = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A1C2C) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.70)),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF3B8FC7).withOpacity(0.16),
                      blurRadius: 28,
                      offset: const Offset(0, -6))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 34, height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                          color: scheme.onSurface.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Text('新建仓库',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  MxTextField(
                      controller: _nameCtrl,
                      hint: '仓库名称',
                      prefix: const Icon(Icons.folder_rounded, size: 17)),
                  const SizedBox(height: 8),
                  MxTextField(
                      controller: _descCtrl,
                      hint: '描述（可选）',
                      prefix: const Icon(Icons.notes_rounded, size: 17)),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Expanded(
                        child: Text('私有仓库',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    Switch(
                        value: _private,
                        onChanged: (v) => setSt(() => _private = v)),
                  ]),
                  Row(children: [
                    const Expanded(
                        child: Text('初始化 README',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    Switch(
                        value: _autoInit,
                        onChanged: (v) => setSt(() => _autoInit = v)),
                  ]),
                  const SizedBox(height: 12),
                  MxButton(
                      label: '创建',
                      icon: Icons.add_rounded,
                      onPressed: _createRepo),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 构建 ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.state.selectedRepo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 仓库选择器 + 工具栏
        _RepoBar(
          repos: _repos,
          selected: selected,
          loading: _loadingRepos,
          onSelect: (r) => _selectRepo(
              r['owner']['login'] as String, r['name'] as String),
          onRefresh: _fetchRepos,
          onNew: _showCreateSheet,
          onUpload: _upload,
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),

        if (_loadingTree)
          const LinearProgressIndicator(minHeight: 2),

        // 文件树
        Expanded(
          child: selected == null
              ? const MxEmpty(
                  icon: Icons.folder_off_rounded,
                  label: '未选择仓库',
                  hint: '从上方选择或新建仓库')
              : _roots.isEmpty && !_loadingTree
                  ? const MxEmpty(
                      icon: Icons.description_outlined,
                      label: '仓库为空',
                      hint: '上传文件或等待初始化')
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

// ─── 仓库选择栏 ───────────────────────────────────────────────────────────────
class _RepoBar extends StatelessWidget {
  const _RepoBar({
    required this.repos,
    required this.selected,
    required this.loading,
    required this.onSelect,
    required this.onRefresh,
    required this.onNew,
    required this.onUpload,
  });

  final List<Map<String, dynamic>> repos;
  final String? selected;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onNew;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0A1C2C) : const Color(0xFFEAF4FF))
            .withOpacity(0.95),
        border: Border(
            bottom: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.black.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // 仓库下拉
          Expanded(
            child: repos.isEmpty
                ? Text(
                    loading ? '加载中…' : '无仓库',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withOpacity(0.45)),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selected,
                      hint: Text('选择仓库',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withOpacity(0.45))),
                      icon: Icon(Icons.expand_more_rounded,
                          size: 16, color: scheme.primary),
                      dropdownColor:
                          isDark ? const Color(0xFF0A1C2C) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      isDense: true,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface),
                      items: repos
                          .map((r) => DropdownMenuItem<String>(
                                value: r['name'] as String,
                                child: Row(children: [
                                  Icon(
                                    r['private'] == true
                                        ? Icons.lock_rounded
                                        : Icons.folder_open_rounded,
                                    size: 14,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(r['name'] as String),
                                ]),
                              ))
                          .toList(),
                      onChanged: (name) {
                        if (name == null) return;
                        final r = repos.firstWhere(
                            (e) => e['name'] == name);
                        onSelect(r);
                      },
                    ),
                  ),
          ),
          MxIconBtn(
              icon: Icons.upload_rounded,
              onPressed: onUpload,
              tooltip: '上传',
              size: 32),
          const SizedBox(width: 2),
          MxIconBtn(
              icon: Icons.refresh_rounded,
              onPressed: onRefresh,
              tooltip: '刷新',
              size: 32),
          const SizedBox(width: 2),
          MxIconBtn(
              icon: Icons.add_rounded,
              onPressed: onNew,
              tooltip: '新建仓库',
              size: 32),
        ],
      ),
    );
  }
}

// ─── 文件树行（递归） ─────────────────────────────────────────────────────────
class _TreeTile extends StatelessWidget {
  const _TreeTile({
    required this.node,
    required this.depth,
    required this.onToggle,
    required this.onOpen,
    required this.scheme,
    required this.isDark,
  });

  final _TreeNode node;
  final int depth;
  final Future<void> Function(_TreeNode) onToggle;
  final Future<void> Function(_TreeNode) onOpen;
  final ColorScheme scheme;
  final bool isDark;

  IconData _icon() {
    if (node.isDir) {
      return node.expanded
          ? Icons.folder_open_rounded
          : Icons.folder_rounded;
    }
    final ext = node.name.contains('.')
        ? node.name.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'dart':                         return Icons.flutter_dash;
      case 'kt': case 'java':              return Icons.code_rounded;
      case 'json': case 'yaml': case 'yml': return Icons.data_object_rounded;
      case 'md':                           return Icons.article_rounded;
      case 'png': case 'jpg': case 'jpeg': case 'svg':
                                           return Icons.image_rounded;
      case 'gradle': case 'xml':           return Icons.settings_rounded;
      default:                             return Icons.insert_drive_file_rounded;
    }
  }

  Color _iconColor() {
    if (node.isDir) return const Color(0xFFF5A623);
    final ext = node.name.contains('.')
        ? node.name.split('.').last.toLowerCase()
        : '';
    switch (ext) {
      case 'dart':  return const Color(0xFF54C5F8);
      case 'kt':    return const Color(0xFF7F52FF);
      case 'java':  return const Color(0xFFED8B00);
      case 'json': case 'yaml': case 'yml': return const Color(0xFF6DB33F);
      case 'md':    return const Color(0xFF519ABA);
      default:      return scheme.onSurface.withOpacity(0.50);
    }
  }

  @override
  Widget build(BuildContext context) {
    const rowH = 30.0;
    final indent = 12.0 + depth * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => node.isDir ? onToggle(node) : onOpen(node),
          child: SizedBox(
            height: rowH,
            child: Row(
              children: [
                SizedBox(width: indent),
                // 展开箭头（仅目录）
                SizedBox(
                  width: 16,
                  child: node.isDir
                      ? (node.loading
                          ? const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5))
                          : Icon(
                              node.expanded
                                  ? Icons.arrow_drop_down_rounded
                                  : Icons.arrow_right_rounded,
                              size: 16,
                              color: scheme.onSurface.withOpacity(0.45),
                            ))
                      : null,
                ),
                const SizedBox(width: 2),
                Icon(_icon(), size: 15, color: _iconColor()),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: node.isDir
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: scheme.onSurface.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 子节点
        if (node.isDir && node.expanded)
          ...node.children.map((child) => _TreeTile(
                node: child,
                depth: depth + 1,
                onToggle: onToggle,
                onOpen: onOpen,
                scheme: scheme,
                isDark: isDark,
              )),
      ],
    );
  }
}