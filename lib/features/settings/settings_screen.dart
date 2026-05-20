import 'package:flutter/material.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/signing_store.dart';
import '../../core/catalogs/permission_catalog.dart';
import '../../core/catalogs/dependency_catalog.dart';
import '../ai_settings/ai_settings_screen.dart';
import '../project_identity/project_identity_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Set<String> selectedPermissions = {};
  final Set<String> selectedDependencies = {};
  final signingStore = SigningStore();

  @override
  Widget build(BuildContext context) {
    return MxPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const MxSectionLabel('账号'),
          MxCard(
            onTap: () => widget.state.logout(),
            child: Row(
              children: [
                const Icon(Icons.logout_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('退出登录', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(widget.state.login == null ? 'GitHub 未登录' : '@${widget.state.login}', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const MxSectionLabel('AI 接口'),
          MxCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiSettingsScreen())),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('模型接口配置', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('OpenAI / Anthropic / 自定义端点', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const MxSectionLabel('项目身份'),
          MxCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProjectIdentityScreen())),
            child: const Row(
              children: [
                Icon(Icons.badge_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('应用名称、包名、版本、图标', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('用于用户项目的发行版本配置', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const MxSectionLabel('签名'),
          MxCard(
            onTap: () async {
              await signingStore.save(keystore: '/sdcard/Download/moonxide.jks', alias: 'moonxide', storePassword: '******', keyPassword: '******');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('签名配置已保存')));
            },
            child: const Row(
              children: [
                Icon(Icons.security_rounded),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Keystore 签名配置', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('Release 包签名必备', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const MxSectionLabel('Android 权限'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(label: const Text('全选'), onPressed: () => setState(() => selectedPermissions.addAll(PermissionCatalog.android.map((e) => e.name)))),
              ActionChip(label: const Text('清空'), onPressed: () => setState(() => selectedPermissions.clear())),
            ],
          ),
          const SizedBox(height: 8),
          ...PermissionCatalog.android.map((item) => MxCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: CheckboxListTile(
                  value: selectedPermissions.contains(item.name),
                  onChanged: (v) => setState(() => v == true ? selectedPermissions.add(item.name) : selectedPermissions.remove(item.name)),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(item.description, style: const TextStyle(fontSize: 12)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              )),
          const MxSectionLabel('Flutter 依赖'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(label: const Text('全选'), onPressed: () => setState(() => selectedDependencies.addAll(DependencyCatalog.flutter.map((e) => e.packageName)))),
              ActionChip(label: const Text('清空'), onPressed: () => setState(() => selectedDependencies.clear())),
            ],
          ),
          const SizedBox(height: 8),
          ...DependencyCatalog.flutter.map((item) => MxCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: CheckboxListTile(
                  value: selectedDependencies.contains(item.packageName),
                  onChanged: (v) => setState(() => v == true ? selectedDependencies.add(item.packageName) : selectedDependencies.remove(item.packageName)),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('${item.packageName}  ·  ${item.description}', style: const TextStyle(fontSize: 12)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              )),
        ],
      ),
    );
  }
}