import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/build_center_state.dart';
import '../../core/services/artifact_downloader.dart';
import '../../core/services/log_parser.dart';
import '../../core/platform/android_installer.dart';
import '../../core/models/build_profile.dart';

class BuildScreen extends StatelessWidget {
  final AppState state;
  const BuildScreen({super.key, required this.state});

  Future<void> _trigger(BuildContext context) async {
    final build = context.read<BuildCenterState>();
    final owner = state.selectedOwner;
    final repo = state.selectedRepo;
    if (owner == null || repo == null || state.github == null) {
      build.setStatus('请先选择仓库');
      return;
    }
    try {
      build.setStatus('正在触发 GitHub Actions...');
      await state.github!.dispatchWorkflow(
        owner: owner,
        repo: repo,
        workflowFile: 'android-apk.yml',
        inputs: {'build_type': state.buildProfile == BuildProfile.debug ? 'debug' : 'release', 'publish_release': 'false', 'release_tag': 'latest'},
      );
      build.setStatus('已触发构建，等待 GitHub Actions 响应...');
    } catch (e) {
      build.setStatus('触发失败：$e');
    }
  }

  Future<void> _poll(BuildContext context) async {
    final build = context.read<BuildCenterState>();
    final owner = state.selectedOwner;
    final repo = state.selectedRepo;
    if (owner == null || repo == null || state.github == null) return;
    try {
      build.setStatus('正在读取最新构建...');
      final runs = await state.github!.listWorkflowRuns(owner, repo);
      if (runs.isEmpty) { build.setStatus('没有构建记录'); return; }
      final run = runs.first;
      final status = run['status'];
      final conclusion = run['conclusion'];
      final htmlUrl = run['html_url'];
      build.setStatus('状态：$status / 结果：${conclusion ?? '运行中'}\n$htmlUrl');
      if (status == 'completed' && conclusion == 'success') {
        final artifacts = await state.github!.listArtifacts(owner, repo, run['id'] as int);
        if (artifacts.isNotEmpty) build.setArtifact(downloadUrl: artifacts.first['archive_download_url'] as String?);
        build.setLog(null);
      }
      if (status == 'completed' && conclusion != 'success') {
        final bytes = await state.github!.downloadRunLogs(owner, repo, run['id'] as int);
        final summary = LogParser().summarize(String.fromCharCodes(bytes));
        build.setLog(summary);
      }
    } catch (e) {
      build.setStatus('读取状态失败：$e');
    }
  }

  Future<void> _download(BuildContext context) async {
    final build = context.read<BuildCenterState>();
    if (build.artifactDownloadUrl == null || state.token == null) return;
    try {
      final path = await ArtifactDownloader().download(url: build.artifactDownloadUrl!, token: state.token!, fileName: 'moonxide-artifact.zip');
      build.setArtifact(localPath: path, downloadUrl: build.artifactDownloadUrl);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已下载到 $path')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败：$e')));
    }
  }

  Future<void> _install(BuildContext context) async {
    final build = context.read<BuildCenterState>();
    if (build.artifactLocalPath == null) return;
    try {
      await AndroidInstaller().openApk(build.artifactLocalPath!);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('安装失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final build = context.watch<BuildCenterState>();
    final scheme = Theme.of(context).colorScheme;
    return MxPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const MxSectionLabel('构建类型'),
          MxCard(
            child: SegmentedButton<BuildProfile>(
              segments: const [
                ButtonSegment(value: BuildProfile.debug, icon: Icon(Icons.bug_report_rounded), label: Text('Debug')),
                ButtonSegment(value: BuildProfile.release, icon: Icon(Icons.rocket_launch_rounded), label: Text('Release')),
              ],
              selected: {state.buildProfile},
              onSelectionChanged: (value) => state.setBuildProfile(value.first),
            ),
          ),
          const MxSectionLabel('操作'),
          MxActionRow(children: [
            Expanded(child: FilledButton.icon(onPressed: () => _trigger(context), icon: const Icon(Icons.play_arrow_rounded), label: const Text('触发编译'))),
            Expanded(child: OutlinedButton.icon(onPressed: () => _poll(context), icon: const Icon(Icons.refresh_rounded), label: const Text('刷新状态'))),
          ]),
          const MxSectionLabel('构建状态'),
          MxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.terminal_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Text('GitHub Actions', style: TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                SelectableText(build.status, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              ],
            ),
          ),
          if (build.artifactDownloadUrl != null) ...[
            const MxSectionLabel('产物'),
            MxCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.android_rounded, color: scheme.primary),
                    const SizedBox(width: 8),
                    const Text('APK 产物', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    MxBadge('可下载', color: Colors.green),
                  ]),
                  const SizedBox(height: 8),
                  Text(build.artifactLocalPath ?? build.artifactDownloadUrl!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.55))),
                  const SizedBox(height: 12),
                  MxActionRow(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _download(context), icon: const Icon(Icons.download_rounded), label: const Text('下载'))),
                    Expanded(child: FilledButton.icon(onPressed: build.artifactLocalPath == null ? null : () => _install(context), icon: const Icon(Icons.install_mobile_rounded), label: const Text('安装'))),
                  ]),
                ],
              ),
            ),
          ],
          if (build.logText != null) ...[
            const MxSectionLabel('错误日志'),
            MxCard(
              child: SelectableText(build.logText!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}