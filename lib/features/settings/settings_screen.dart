import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../ai_settings/ai_settings_screen.dart';
import '../token_gate/token_gate_screen.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const MxSectionLabel('账号'),
        MxCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TokenGateScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              widget.state.avatarUrl == null
                  ? CircleAvatar(radius: 20, backgroundColor: scheme.primary.withOpacity(0.12), child: Icon(Icons.person_rounded, color: scheme.primary))
                  : CircleAvatar(radius: 20, backgroundImage: NetworkImage(widget.state.avatarUrl!)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.state.login == null ? 'GitHub 未登录' : '@${widget.state.login}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 2),
                Text('点击管理/切换账号', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5))),
              ])),
              Icon(Icons.switch_account_rounded, color: scheme.primary, size: 20),
            ]),
          ),
        ),

        const MxSectionLabel('配置与接口'),
        _SettingRow(
          icon: Icons.auto_awesome_rounded,
          title: '模型接口配置',
          subtitle: 'OpenAI / Anthropic / 自定义端点',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
        ),
        _SettingRow(
          icon: Icons.security_rounded,
          title: 'Keystore 签名配置',
          subtitle: 'Release 包签名 · 密钥别名 · 密码',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SigningScreen())),
        ),

        const MxSectionLabel('外观'),
        MxCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.palette_rounded, color: scheme.primary, size: 18),
                const SizedBox(width: 10),
                const Expanded(child: Text('主题模式', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ThemeChoice(label: '跟随系统', icon: Icons.brightness_auto_rounded, value: ThemeMode.system, state: widget.state),
                  _ThemeChoice(label: '浅色', icon: Icons.light_mode_rounded, value: ThemeMode.light, state: widget.state),
                  _ThemeChoice(label: '深色', icon: Icons.dark_mode_rounded, value: ThemeMode.dark, state: widget.state),
                ],
              ),
              const SizedBox(height: 14),
              Text('主题配色', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onSurface.withOpacity(0.62))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ThemeVariantChoice(label: '冰川蓝', value: 'arctic', color: const Color(0xFF2F8CCB), state: widget.state),
                  _ThemeVariantChoice(label: '森林绿', value: 'forest', color: const Color(0xFF16885A), state: widget.state),
                  _ThemeVariantChoice(label: '紫罗兰', value: 'violet', color: const Color(0xFF6652D9), state: widget.state),
                  _ThemeVariantChoice(label: '落日橙', value: 'sunset', color: const Color(0xFFE66745), state: widget.state),
                ],
              ),
            ]),
          ),
        ),

        const MxSectionLabel('背景个性化'),
        MxCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.wallpaper_rounded, color: scheme.primary, size: 18),
                const SizedBox(width: 10),
                const Expanded(child: Text('自定义背景图片', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
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
        ),

        const MxSectionLabel('社区与交流'),
        _SettingRow(
          icon: Icons.people_rounded,
          title: '加入 QQ 交流群',
          subtitle: '群内首发最新内测版与完整 APK 产物包',
          onTap: () async {
            const url = 'https://qun.qq.com/universal-share/share?ac=1&authKey=vkul2m0csA5sgX8g7PrwijmJRSGcwTfkKi8xlUaJlmnYMlChx%2FHvWvK6Z5GKFmU1&busi_data=eyJncm91cENvZGUiOiI5ODI5NzIzNzEiLCJ0b2tlbiI6Im9mN3RaYVJJTTNPTXViRVpZcHpleFVmeXZueWhpVDNJb2F4UEVGbTNmRWdRZTluUnFLeWVhQ3lET0NHTXNWN2oiLCJ1aW4iOiIzODQ1OTM5Njk4In0%3D&data=L4F0_h2IQmlj-POwzkQbm-YEIQWtcImAe5gL0Exbc2BNRFbf_ByAFCBCUbHspsq-yAU8ZGZpqhhB_8DZYB6y5w&svctype=4&tempid=h5_group_info';
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),

        const MxSectionLabel('关于应用'),
        _SettingRow(
          icon: Icons.info_outline_rounded,
          title: '关于 MoonXide',
          subtitle: '开发者：北海cmbh · 软件开源协议：MIT',
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => _AboutDetailScreen(scheme: scheme, isDark: isDark)));
          },
        ),
      ],
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.icon,
    required this.value,
    required this.state,
  });

  final String label;
  final IconData icon;
  final ThemeMode value;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = state.themeMode == value;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 15, color: selected ? scheme.onPrimary : scheme.primary),
      label: Text(label),
      onSelected: (_) => state.setThemeMode(value),
      selectedColor: scheme.primary,
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _ThemeVariantChoice extends StatelessWidget {
  const _ThemeVariantChoice({
    required this.label,
    required this.value,
    required this.color,
    required this.state,
  });

  final String label;
  final String value;
  final Color color;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.themeVariant == value;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => state.setThemeVariant(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.16) : scheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color.withOpacity(0.62) : scheme.outlineVariant.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8)] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? color : scheme.onSurface.withOpacity(0.72))),
        ]),
      ),
    );
  }
}

class _AboutDetailScreen extends StatelessWidget {
  const _AboutDetailScreen({required this.scheme, required this.isDark});
  final ColorScheme scheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Row(children: [
              MxIconBtn(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              const Expanded(child: Text('关于 MoonXide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 36),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.onSurface.withOpacity(0.1), width: 1.0),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.developer_mode_rounded,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'MoonXide',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Snow Alpine IDE v0.0.1',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.55)),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161616) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('软件简介', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '本软件开发由开发者独立完成。提供给广大移动开发者随时随地在手机端畅快编写并云端编译出完整、安全的 Android 应用程序安装包(APK)的开发环境。',
                    style: TextStyle(fontSize: 12, height: 1.6, color: scheme.onSurface.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  _buildMetaRow('核心开发者', '北海cmbh'),
                  _buildMetaRow('软件开源协议', 'MIT'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            MxButton(
              label: 'GitHub 开源主页',
              icon: Icons.code_rounded,
              filled: true,
              onPressed: () async {
                final uri = Uri.parse('https://github.com/cmbh0/MoonXide/');
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
            const SizedBox(height: 10),
            MxButton(
              label: '关注作者 B 站',
              icon: Icons.video_library_rounded,
              filled: false,
              onPressed: () async {
                final uri = Uri.parse('https://b23.tv/NHf4BNg');
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.55))),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
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