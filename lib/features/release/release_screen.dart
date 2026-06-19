import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/build_center_state.dart';
import '../../core/services/artifact_downloader.dart';
import '../../core/platform/android_installer.dart';

class ReleaseScreen extends StatefulWidget {
  const ReleaseScreen({super.key});

  @override
  State<ReleaseScreen> createState() => _ReleaseScreenState();
}

class _ReleaseScreenState extends State<ReleaseScreen> {
  final _tagCtrl   = TextEditingController(text: 'v1.0.0');
  final _titleCtrl = TextEditingController(text: 'MoonXide Release');
  final _bodyCtrl  = TextEditingController();
  bool _prerelease = false;
  bool _loading    = false;
  String? _assetPath;
  List<Map<String, dynamic>> _releases = [];

  @override
  void dispose() {
    _tagCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish(BuildContext context) async {
    final app   = context.read<AppState>();
    final owner = app.selectedOwner;
    final repo  = app.selectedRepo;
    if (owner == null || repo == null || app.github == null) return;
    if (_assetPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先上传发行文件，不能创建空发行版')));
      return;
    }
    setState(() => _loading = true);
    try {
      final release = await app.github!.createRelease(
        owner: owner, repo: repo,
        tagName: _tagCtrl.text.trim(),
        name: _titleCtrl.text.trim(),
        body: _bodyCtrl.text,
        prerelease: _prerelease,
      );
      final f = File(_assetPath!);
      await app.github!.uploadReleaseAsset(
        uploadUrl: release['upload_url'] as String,
        name: f.uri.pathSegments.last,
        bytes: await f.readAsBytes(),
      );
      await _load(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发行版已创建')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发布失败：$e')));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _load(BuildContext context) async {
    final app   = context.read<AppState>();
    final owner = app.selectedOwner;
    final repo  = app.selectedRepo;
    if (owner == null || repo == null || app.github == null) return;
    setState(() => _loading = true);
    try {
      _releases = await app.github!.listReleases(owner, repo);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('读取发行版失败：$e')));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _downloadAndInstall(BuildContext context) async {
    final app   = context.read<AppState>();
    final build = context.read<BuildCenterState>();
    if (build.artifactDownloadUrl == null || app.token == null) return;
    final name = (build.artifactName == null || build.artifactName!.trim().isEmpty)
        ? 'artifact'
        : build.artifactName!.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-');
    final fileName = name.toLowerCase().endsWith('.zip') ? name : '$name.zip';
    build.startDownload();
    try {
      final path = await ArtifactDownloader().download(
        url: build.artifactDownloadUrl!,
        token: app.token!,
        fileName: fileName,
        onProgress: (p) => build.updateDownloadProgress(p),
      );
      build.finishDownload(localPath: path);
      await AndroidInstaller().openFile(path);
    } catch (_) {
      build.failDownload();
    }
  }

  Future<void> _pickReleaseAsset() async {
    final r = await FilePicker.platform.pickFiles(withData: false);
    final path = r?.files.single.path;
    if (path == null) return;
    setState(() => _assetPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final build  = context.watch<BuildCenterState>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // 工具栏
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Spacer(),
              MxIconBtn(icon: Icons.refresh_rounded, onPressed: () => _load(context), tooltip: '刷新', size: 36),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),

        // 本次构建产物
        if (build.artifactDownloadUrl != null) ...[
          const MxSectionLabel('本次构建产物'),
          MxCard(
            child: Row(
              children: [
                Icon(Icons.archive_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            build.artifactLocalPath ?? build.artifactName ?? build.artifactDownloadUrl!,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          if (build.downloadBusy) ...[
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: build.downloadProgress, minHeight: 3)),
            const SizedBox(height: 4),
            Text('正在下载：${(build.downloadProgress * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: scheme.onSurface.withOpacity(0.5))),
          ],
        ]),
      ),
                MxIconBtn(
                  icon: Icons.download_rounded,
                  tooltip: '下载/打开 GitHub Actions 附件',
                  onPressed: build.artifactDownloadUrl == null ? null : () => _downloadAndInstall(context),
                  size: 36,
                ),
              ],
            ),
          ),
        ],

        // 发布新版本
        const MxSectionLabel('发布新版本'),
        MxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MxTextField(controller: _tagCtrl,   hint: 'v1.0.0',    label: '版本标签',   prefix: const Icon(Icons.label_rounded,  size: 18)),
              const SizedBox(height: 10),
              MxTextField(controller: _titleCtrl, hint: '发行版标题', label: '标题',       prefix: const Icon(Icons.title_rounded,  size: 18)),
              const SizedBox(height: 10),
              MxTextField(controller: _bodyCtrl,  hint: '本次更新内容…', label: '版本说明', minLines: 3, maxLines: 6,
                  prefix: const Icon(Icons.notes_rounded, size: 18)),
              const SizedBox(height: 10),
              MxCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Icon(Icons.attach_file_rounded, color: scheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_assetPath ?? '必须上传发行文件后才能创建发行版', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  MxButton(label: '上传', icon: Icons.upload_file_rounded, onPressed: _pickReleaseAsset, small: true, filled: false),
                ]),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: Text('预发布版本', style: TextStyle(fontWeight: FontWeight.w600))),
                  MxSwitch(value: _prerelease, onChanged: (v) => setState(() => _prerelease = v)),
                ],
              ),
              const SizedBox(height: 8),
              MxButton(label: '创建发行版', icon: Icons.rocket_launch_rounded, onPressed: () => _publish(context)),
            ],
          ),
        ),

        // 历史发行版
        const MxSectionLabel('历史发行版'),
        if (_releases.isEmpty)
          const MxEmpty(icon: Icons.history_rounded, label: '暂无发行版', hint: '点击右上角刷新或先创建一个')
        else
          ..._releases.map((r) => MxCard(
                child: Row(
                  children: [
                    Icon(Icons.tag_rounded, color: scheme.primary, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['name']?.toString() ?? r['tag_name']?.toString() ?? '未命名',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            r['tag_name']?.toString() ?? '',
                            style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.45)),
                          ),
                        ],
                      ),
                    ),
                    MxBadge(
                      r['prerelease'] == true ? '预发布' : '正式',
                      color: r['prerelease'] == true ? Colors.orange : Colors.green,
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}