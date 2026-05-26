import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../ai_settings/ai_settings_screen.dart';
import '../signing/signing_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

        const MxSectionLabel('签名'),
        _SettingRow(
          icon: Icons.security_rounded,
          title: 'Keystore 签名配置',
          subtitle: 'Release 包签名 · 密钥别名 · 密码',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SigningScreen())),
        ),

        const MxSectionLabel('背景'),
        MxCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.wallpaper_rounded, color: scheme.primary, size: 18),
              const SizedBox(width: 10),
              const Expanded(child: Text('自定义背景', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              if (widget.state.customBackgroundPath != null)
                MxIconBtn(icon: Icons.close_rounded, size: 30,
                  onPressed: () => widget.state.setCustomBackground(null)),
            ]),
            if (widget.state.customBackgroundPath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(widget.state.customBackgroundPath!),
                    height: 80, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.opacity_rounded, size: 14, color: scheme.onSurface.withOpacity(0.45)),
                const SizedBox(width: 6),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: widget.state.bgOpacity,
                      min: 0.1, max: 1.0,
                      onChanged: widget.state.setBgOpacity,
                    ),
                  ),
                ),
                Text('${(widget.state.bgOpacity * 100).round()}%',
                    style: TextStyle(fontSize: 11, color: scheme.onSurface.withOpacity(0.5))),
              ]),
            ] else ...[
              const SizedBox(height: 10),
              MxButton(label: '选择图片', icon: Icons.image_rounded,
                  onPressed: _pickBackground, filled: false, small: true),
            ],
          ]),
        ),

        const MxSectionLabel('社区交流'),
        _SettingRow(
          icon: Icons.people_rounded,
          title: '加入 QQ 交流群',
          subtitle: '群内首发最新内测版与完整 APK 包',
          onTap: () async {
            const url = 'https://qun.qq.com/universal-share/share?ac=1&authKey=vkul2m0csA5sgX8g7PrwijmJRSGcwTfkKi8xlUaJlmnYMlChx%2FHvWvK6Z5GKFmU1&busi_data=eyJncm91cENvZGUiOiI5ODI5NzIzNzEiLCJ0b2tlbiI6Im9mN3RaYVJJTTNPTXViRVpZcHpleFVmeXZueWhpVDNJb2F4UEVGbTNmRWdRZTluUnFLeWVhQ3lET0NHTXNWN2oiLCJ1aW4iOiIzODQ1OTM5Njk4In0%3D&data=L4F0_h2IQmlj-POwzkQbm-YEIQWtcImAe5gL0Exbc2BNRFbf_ByAFCBCUbHspsq-yAU8ZGZpqhhB_8DZYB6y5w&svctype=4&tempid=h5_group_info';
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),

        const MxSectionLabel('关于 MoonXide'),
        MxCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.info_outline_rounded, size: 16),
                const SizedBox(width: 8),
                Text('软件说明', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              const Text(
                '本软件开发由开发者独立完成。\n'
                '软件开发者：北海cmbh\n'
                '软件开源协议：MIT',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              MxButton(
                label: 'GitHub 开源主页',
                icon: Icons.code_rounded,
                small: true,
                filled: false,
                onPressed: () async {
                  final uri = Uri.parse('https://github.com/cmbh0/MoonXide/');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 6),
              MxButton(
                label: '关注作者 B 站',
                icon: Icons.video_library_rounded,
                small: true,
                filled: false,
                onPressed: () async {
                  final uri = Uri.parse('https://b23.tv/NHf4BNg');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 10),
              Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant.withOpacity(0.4)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('版本号', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.55))),
                  const Text('0.0.1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
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
