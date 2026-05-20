import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/signing_store.dart';
import '../ai_settings/ai_settings_screen.dart';
import '../project_identity/project_identity_screen.dart';
import '../package_editor/package_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _signingStore = SigningStore();

  Future<void> _pickBackground() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
    final path = r?.files.single.path;
    if (path == null) return;
    await widget.state.setCustomBackground(path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const MxSectionLabel('账号'),
        MxCard(
          onTap: () => widget.state.logout(),
          child: Row(children: [
            widget.state.avatarUrl == null
                ? CircleAvatar(radius: 18, backgroundColor: scheme.primary.withOpacity(0.12), child: Icon(Icons.person_rounded, color: scheme.primary))
                : CircleAvatar(radius: 18, backgroundImage: NetworkImage(widget.state.avatarUrl!)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.state.login == null ? 'GitHub 未登录' : '@${widget.state.login}', style: const TextStyle(fontWeight: FontWeight.w900)),
              Text('点击退出登录', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5))),
            ])),
            Icon(Icons.logout_rounded, color: scheme.error, size: 20),
          ]),
        ),

        const MxSectionLabel('AI 接口'),
        _SettingRow(
          icon: Icons.auto_awesome_rounded,
          title: '模型接口配置',
          subtitle: 'OpenAI / Anthropic / 自定义端点',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
        ),

        const MxSectionLabel('安装包配置'),
        _SettingRow(
          icon: Icons.apps_rounded,
          title: '包名、版本、模板',
          subtitle: 'APK 元数据、默认编译模板、自定义模板导入导出',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PackageEditorScreen())),
        ),
        _SettingRow(
          icon: Icons.badge_rounded,
          title: '项目身份配置',
          subtitle: '应用名称、包名、版本、图标',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProjectIdentityScreen())),
        ),

        const MxSectionLabel('签名'),
        _SettingRow(
          icon: Icons.security_rounded,
          title: 'Keystore 签名配置',
          subtitle: 'Release 包签名必备',
          onTap: () async {
            await _signingStore.save(
              keystore: '/sdcard/Download/moonxide.jks',
              alias: 'moonxide',
              storePassword: '******',
              keyPassword: '******',
            );
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('签名配置已保存')));
          },
        ),

        const MxSectionLabel('背景'),
        MxCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.wallpaper_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('自定义编辑器背景', style: TextStyle(fontWeight: FontWeight.w800))),
            ]),
            if (widget.state.customBackgroundPath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(widget.state.customBackgroundPath!), height: 90, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 12),
            MxActionRow(children: [
              MxButton(label: '上传图片', icon: Icons.image_rounded, onPressed: _pickBackground, filled: false),
              MxButton(label: '清除背景', icon: Icons.cleaning_services_rounded, onPressed: () => widget.state.setCustomBackground(null), color: Colors.red),
            ]),
          ]),
        ),

        const MxSectionLabel('自动化'),
        const MxCard(
          child: Text('依赖管理、权限申请、Manifest 修改等快捷按钮已移除，后续由 AI 任务执行统一完成，避免页面臃肿。'),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MxCard(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: scheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.55))),
        ])),
        Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(0.3)),
      ]),
    );
  }
}
