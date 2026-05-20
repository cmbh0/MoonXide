import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final tagController = TextEditingController(text: 'v1.0.0');
  final titleController = TextEditingController(text: 'MoonXide Release');
  final bodyController = TextEditingController(text: '');
  bool prerelease = false;
  bool loading = false;
  List<Map<String, dynamic>> releases = [];

  @override
  void dispose() {
    tagController.dispose();
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> _publish(BuildContext context) async {
    final app = context.read<AppState>();
    final owner = app.selectedOwner;
    final repo = app.selectedRepo;
    if (owner == null || repo == null || app.github == null) return;
    setState(() => loading = true);
    try {
      await app.github!.createRelease(owner: owner, repo: repo, tagName: tagController.text.trim(), name: titleController.text.trim(), body: bodyController.text, prerelease: prerelease);
      await _load(context);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发行版已创建')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发布失败：$e')));
    }
    setState(() => loading = false);
  }

  Future<void> _load(BuildContext context) async {
    final app = context.read<AppState>();
    final owner = app.selectedOwner;
    final repo = app.selectedRepo;
    if (owner == null || repo == null || app.github == null) return;
    setState(() => loading = true);
    try {
      releases = await app.github!.listReleases(owner, repo);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('读取发行版失败：$e')));
    }
    setState(() => loading = false);
  }

  Future<void> _downloadAndInstall(BuildContext context) async {
    final app = context.read<AppState>();
    final build = context.read<BuildCenterState>();
    if (build.artifactDownloadUrl == null || app.token == null) return;
    final path = await ArtifactDownloader().download(url: build.artifactDownloadUrl!, token: app.token!, fileName: 'moonxide-artifact.zip');
    build.setArtifact(localPath: path, downloadUrl: build.artifactDownloadUrl);
    await AndroidInstaller().openApk(path);
  }

  @override
  Widget build(BuildContext context) {
    final build = context.watch<BuildCenterState>();
    final scheme = Theme.of(context).colorScheme;
    return MxPage(
      actions: [
        IconButton(tooltip: '刷新发行版', onPressed: () => _load(context), icon: const Icon(Icons.refresh_rounded)),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (loading) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
          if (build.artifactDownloadUrl != null) ...[
            const MxSectionLabel('本次构建产物'),
            MxCard(
              child: Row(
                children: [
                  Icon(Icons.android_rounded, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(build.artifactLocalPath ?? build.artifactDownloadUrl!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  IconButton(icon: const Icon(Icons.install_mobile_rounded), onPressed: build.artifactDownloadUrl == null ? null : () => _downloadAndInstall(context)),
                ],
              ),
            ),
          ],
          const MxSectionLabel('发布新版本'),
          MxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: tagController, decoration: const InputDecoration(labelText: '版本标签', hintText: 'v1.0.0', prefixIcon: Icon(Icons.label_rounded))),
                const SizedBox(height: 12),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: '发行版标题', prefixIcon: Icon(Icons.title_rounded))),
                const SizedBox(height: 12),
                TextField(controller: bodyController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: '版本说明', hintText: '本次更新内容...', prefixIcon: Icon(Icons.notes_rounded))),
                const SizedBox(height: 8),
                SwitchListTile(value: prerelease, onChanged: (v) => setState(() => prerelease = v), title: const Text('预发布版本'), contentPadding: EdgeInsets.zero),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: () => _publish(context), icon: const Icon(Icons.rocket_launch_rounded), label: const Text('创建发行版')),
              ],
            ),
          ),
          const MxSectionLabel('历史发行版'),
          if (releases.isEmpty)
            const MxEmpty(icon: Icons.history_rounded, label: '暂无发行版', hint: '点击右上角刷新或先创建一个')
          else
            ...releases.map((r) => MxCard(
                  child: Row(
                    children: [
                      Icon(Icons.tag_rounded, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['name']?.toString() ?? r['tag_name']?.toString() ?? '未命名', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(r['tag_name']?.toString() ?? '', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5))),
                          ],
                        ),
                      ),
                      MxBadge(r['prerelease'] == true ? '预发布' : '正式', color: r['prerelease'] == true ? Colors.orange : Colors.green),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}