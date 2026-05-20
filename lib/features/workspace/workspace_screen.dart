import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';
import '../../core/services/local_file_upload_service.dart';
import '../../core/models/repository_file_item.dart';

class WorkspaceScreen extends StatefulWidget {
  final AppState state;
  const WorkspaceScreen({super.key, required this.state});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final repoNameController = TextEditingController();
  final descController = TextEditingController();
  bool creatingPrivate = true;
  bool autoInit = true;
  List<Map<String, dynamic>> repos = [];
  List<RepositoryFileItem> files = [];
  String currentPath = '';
  bool loading = false;
  String? message;

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    if (widget.state.github == null) return;
    setState(() => loading = true);
    try {
      repos = await widget.state.github!.listRepositories();
      message = null;
    } catch (e) {
      message = '仓库读取失败：$e';
    }
    setState(() => loading = false);
  }

  Future<void> _loadFiles([String path = '']) async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    setState(() => loading = true);
    try {
      final data = await widget.state.github!.getContents(owner, repo, path: path);
      files = data.map((e) => RepositoryFileItem(path: e['path'] as String, name: e['name'] as String, isDir: e['type'] == 'dir', sha: e['sha'] as String?, downloadUrl: e['download_url'] as String?)).toList();
      currentPath = path;
      message = null;
    } catch (e) {
      message = '文件树读取失败：$e';
    }
    setState(() => loading = false);
  }

  Future<void> _createRepo() async {
    if (repoNameController.text.trim().isEmpty || widget.state.github == null) return;
    setState(() => loading = true);
    try {
      final repo = await widget.state.github!.createRepository(name: repoNameController.text.trim(), private: creatingPrivate, autoInit: autoInit, description: descController.text.trim());
      final owner = repo['owner']['login'] as String;
      final name = repo['name'] as String;
      widget.state.selectRepository(owner, name);
      await _loadRepos();
      await _loadFiles();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      message = '创建仓库失败：$e';
    }
    setState(() => loading = false);
  }

  Future<void> _openFile(RepositoryFileItem item) async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    setState(() => loading = true);
    try {
      final file = await widget.state.github!.getFile(owner, repo, item.path);
      final raw = (file['content'] as String).replaceAll('\n', '');
      final content = utf8.decode(base64Decode(raw));
      if (!mounted) return;
      context.read<EditorState>().openFile(item.path, content);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已在编辑器打开 ${item.name}')));
    } catch (e) {
      message = '打开文件失败：$e';
    }
    setState(() => loading = false);
  }

  Future<void> _uploadLocalFile() async {
    final owner = widget.state.selectedOwner;
    final repo = widget.state.selectedRepo;
    if (owner == null || repo == null || widget.state.github == null) return;
    setState(() => loading = true);
    try {
      final service = LocalFileUploadService();
      final file = await service.pickOne();
      if (file == null) { setState(() => loading = false); return; }
      final bytes = await service.bytesOf(file);
      final targetPath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
      await widget.state.github!.putFile(owner: owner, repo: repo, path: targetPath, message: 'Upload ${file.name} by MoonXide', contentBase64: base64Encode(bytes));
      await _loadFiles(currentPath);
      message = '已上传 $targetPath';
    } catch (e) {
      message = '上传失败：$e';
    }
    setState(() => loading = false);
  }

  void _showCreateRepoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('新建仓库', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(controller: repoNameController, decoration: const InputDecoration(labelText: '仓库名称', prefixIcon: Icon(Icons.folder_rounded))),
            const SizedBox(height: 12),
            TextField(controller: descController, decoration: const InputDecoration(labelText: '描述（可选）', prefixIcon: Icon(Icons.notes_rounded))),
            const SizedBox(height: 8),
            SwitchListTile(value: creatingPrivate, onChanged: (v) => setState(() => creatingPrivate = v), title: const Text('私有仓库'), contentPadding: EdgeInsets.zero),
            SwitchListTile(value: autoInit, onChanged: (v) => setState(() => autoInit = v), title: const Text('初始化 README'), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _createRepo, icon: const Icon(Icons.add_rounded), label: const Text('创建并作为工作区')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.state.selectedRepo;
    final scheme = Theme.of(context).colorScheme;
    return MxPage(
      actions: [
        IconButton(tooltip: '上传文件', onPressed: _uploadLocalFile, icon: const Icon(Icons.upload_rounded)),
        IconButton(tooltip: '刷新', onPressed: _loadRepos, icon: const Icon(Icons.sync_rounded)),
        IconButton(tooltip: '新建仓库', onPressed: _showCreateRepoSheet, icon: const Icon(Icons.add_rounded)),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (loading) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
          if (message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(message!, style: const TextStyle(color: Colors.red))),
          const MxSectionLabel('仓库'),
          if (repos.isEmpty && !loading)
            const MxEmpty(icon: Icons.folder_off_rounded, label: '没有仓库', hint: '点击右上角 + 创建第一个仓库')
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: repos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final r = repos[i];
                  final name = r['name'] as String;
                  final owner = r['owner']['login'] as String;
                  final isSelected = selected == name;
                  return GestureDetector(
                    onTap: () { widget.state.selectRepository(owner, name); _loadFiles(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 180,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary.withOpacity(0.12) : scheme.surface.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isSelected ? scheme.primary.withOpacity(0.4) : scheme.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(r['private'] == true ? Icons.lock_rounded : Icons.folder_open_rounded, color: isSelected ? scheme.primary : scheme.onSurface.withOpacity(0.6), size: 20),
                          const SizedBox(height: 8),
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: isSelected ? scheme.primary : null)),
                          Text(r['private'] == true ? '私有' : '公开', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const MxSectionLabel('文件'),
          if (currentPath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded, size: 16, color: scheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 6),
                  Expanded(child: Text('/$currentPath', style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.6)))),
                  TextButton.icon(onPressed: () => _loadFiles(''), icon: const Icon(Icons.home_rounded, size: 16), label: const Text('根目录')),
                ],
              ),
            ),
          if (files.isEmpty && !loading && selected != null)
            const MxEmpty(icon: Icons.description_outlined, label: '目录为空', hint: '上传文件或切换仓库')
          else
            ...files.map((item) => MxCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () => item.isDir ? _loadFiles(item.path) : _openFile(item),
                  child: Row(
                    children: [
                      Icon(item.isDir ? Icons.folder_rounded : _fileIcon(item.name), color: item.isDir ? const Color(0xFFF5A623) : scheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(item.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5))),
                          ],
                        ),
                      ),
                      Icon(item.isDir ? Icons.chevron_right_rounded : Icons.open_in_new_rounded, size: 18, color: scheme.onSurface.withOpacity(0.35)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'dart': return Icons.flutter_dash;
      case 'kt': case 'java': return Icons.code_rounded;
      case 'json': case 'yaml': case 'yml': return Icons.data_object_rounded;
      case 'md': return Icons.article_rounded;
      case 'png': case 'jpg': case 'jpeg': case 'svg': return Icons.image_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }
}