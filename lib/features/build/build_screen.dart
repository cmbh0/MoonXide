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
    final repo  = state.selectedRepo;
    if (owner == null || repo == null || state.github == null) {
      build.setStatus('请先选择仓库');
      return;
    }
    build.start('正在触发 GitHub Actions…');
    try {
      final workflow = await state.github!.dispatchBestBuildWorkflow(
        owner: owner, repo: repo,
        inputs: {
          'build_type':      state.buildProfile == BuildProfile.debug ? 'debug' : 'release',
          'publish_release': 'false',
        },
      );
      build.updateProgress(statusText: '已触发 $workflow，等待 GitHub Actions 响应…', value: 0.12);
    } catch (e) {
      build.fail('触发失败：$e');
    }
  }

  Future<void> _poll(BuildContext context) async {
    final build = context.read<BuildCenterState>();
    final owner = state.selectedOwner;
    final repo  = state.selectedRepo;
    if (owner == null || repo == null || state.github == null) return;
    build.setStatus('正在读取最新构建…');
    try {
      final runs = await state.github!.listWorkflowRuns(owner, repo);
      if (runs.isEmpty) { build.setStatus('没有构建记录'); return; }
      final run        = runs.first;
      final status     = run['status'];
      final conclusion = run['conclusion'];
      final htmlUrl    = run['html_url'];
      final progress = status == 'completed'
          ? 1.0
          : (status == 'in_progress' ? 0.55 : 0.22);
      build.updateProgress(
        statusText: '状态：$status\n结果：${conclusion ?? '运行中'}\n$htmlUrl',
        value: progress,
        runUrl: htmlUrl?.toString(),
      );
      if (status == 'completed' && conclusion == 'success') {
        build.finish('构建完成：success\n$htmlUrl');
        final artifacts = await state.github!.listArtifacts(owner, repo, run['id'] as int);
        if (artifacts.isNotEmpty) {
          final artifact = artifacts.first;
          build.setArtifact(
            downloadUrl: artifact['archive_download_url'] as String?,
            name: artifact['name']?.toString(),
          );
        }
        build.setLog(null);
      }
      if (status == 'completed' && conclusion != 'success') {
        build.fail('构建失败：${conclusion ?? 'unknown'}\n$htmlUrl');
        final bytes   = await state.github!.downloadRunLogs(owner, repo, run['id'] as int);
        final summary = LogParser().summarize(String.fromCharCodes(bytes));
        build.setLog(summary);
      }
    } catch (e) {
      build.setStatus('读取状态失败：$e');
    }
  }

  String _safeArtifactFileName(String? name) {
    final base = (name == null || name.trim().isEmpty) ? 'artifact' : name.trim();
    final safe = base.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-');
    return safe.toLowerCase().endsWith('.zip') ? safe : '$safe.zip';
  }

  Future<void> _download(BuildContext context) async {
    final build = context.read<BuildCenterState>();
    if (build.artifactDownloadUrl == null || state.token == null) return;
    try {
      final fileName = _safeArtifactFileName(build.artifactName);
      final path = await ArtifactDownloader().download(
        url: build.artifactDownloadUrl!, token: state.token!, fileName: fileName);
      build.setArtifact(localPath: path, downloadUrl: build.artifactDownloadUrl, name: build.artifactName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已下载 GitHub Actions 附件到 $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败：$e')));
      }
    }
  }

  Future<void> _install(BuildContext context) async {
    final build = context.read<BuildCenterState>();
    if (build.artifactLocalPath == null) return;
    try {
      await AndroidInstaller().openFile(build.artifactLocalPath!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final build  = context.watch<BuildCenterState>();
    final scheme = Theme.of(context).colorScheme;
    final artifactName = build.artifactName ?? 'GitHub Actions artifact';
    final localPath = build.artifactLocalPath;
    final isDownloadedApk = localPath != null && localPath.toLowerCase().endsWith('.apk');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const MxSectionLabel('构建类型'),
        MxCard(
          child: Row(
            children: [
              _ProfileChip(
                label: 'Debug',
                icon: Icons.bug_report_rounded,
                active: state.buildProfile == BuildProfile.debug,
                onTap: () => state.setBuildProfile(BuildProfile.debug),
              ),
              const SizedBox(width: 10),
              _ProfileChip(
                label: 'Release',
                icon: Icons.rocket_launch_rounded,
                active: state.buildProfile == BuildProfile.release,
                onTap: () => state.setBuildProfile(BuildProfile.release),
              ),
            ],
          ),
        ),
        const MxSectionLabel('操作'),
        MxActionRow(children: [
          MxButton(label: '触发编译', icon: Icons.play_arrow_rounded, onPressed: () => _trigger(context)),
          MxButton(label: '刷新状态', icon: Icons.refresh_rounded,   onPressed: () => _poll(context),   filled: false),
        ]),
        const MxSectionLabel('构建状态'),
        MxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.terminal_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                const Text('GitHub Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              SelectableText(build.status,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
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
                  Icon(Icons.archive_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(artifactName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(width: 8),
                  MxBadge(localPath == null ? 'GitHub 附件' : '已下载', color: Colors.green),
                ]),
                const SizedBox(height: 8),
                Text(
                  build.artifactLocalPath ?? build.artifactDownloadUrl!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5)),
                ),
                const SizedBox(height: 12),
                MxActionRow(children: [
                  MxButton(label: '下载附件', icon: Icons.download_rounded, onPressed: () => _download(context), filled: false),
                  MxButton(label: isDownloadedApk ? '安装 APK' : '打开附件', icon: isDownloadedApk ? Icons.install_mobile_rounded : Icons.open_in_new_rounded, onPressed: localPath == null ? null : () => _install(context)),
                ]),
              ],
            ),
          ),
        ],
        if (build.logText != null) ...[
          const MxSectionLabel('错误日志'),
          MxCard(
            child: SelectableText(build.logText!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ],
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.label, required this.icon, required this.active, required this.onTap});
  final String   label;
  final IconData icon;
  final bool     active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? scheme.primary.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? scheme.primary.withOpacity(0.45) : scheme.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? scheme.primary : scheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? scheme.primary : scheme.onSurface.withOpacity(0.6))),
            ],
          ),
        ),
      ),
    );
  }
}