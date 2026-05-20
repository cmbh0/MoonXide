import 'package:flutter/material.dart';
import '../../app/mx_widgets.dart';

class PackageEditorScreen extends StatefulWidget {
  const PackageEditorScreen({super.key});
  @override
  State<PackageEditorScreen> createState() => _PackageEditorScreenState();
}

class _PackageEditorScreenState extends State<PackageEditorScreen> {
  final packageCtrl = TextEditingController(text: 'com.example.app');
  final versionCtrl = TextEditingController(text: '1.0.0');
  final codeCtrl = TextEditingController(text: '1');
  String selectedTemplate = 'apk_dart';

  final templates = const {
    'native_cpp': {
      'name': 'C/C++ 原生可执行文件',
      'output': 'run.sh',
      'type': 'binary',
      'steps': ['clang++ main.cpp -o app', 'cat > run.sh', 'chmod +x run.sh']
    },
    'apk_java': {
      'name': 'Java APK 模板',
      'output': 'app-release.apk',
      'type': 'apk',
      'steps': ['创建 Gradle Android 项目', '注入 Java 源码', 'assembleRelease']
    },
    'apk_kotlin': {
      'name': 'Kotlin APK 模板',
      'output': 'app-release.apk',
      'type': 'apk',
      'steps': ['创建 Gradle Kotlin 项目', '注入 Kotlin 源码', 'assembleRelease']
    },
    'apk_dart': {
      'name': 'Dart / Flutter APK 模板',
      'output': 'app-release.apk',
      'type': 'apk',
      'steps': ['flutter create', '写入 pubspec 与 lib', 'flutter build apk']
    },
  };

  @override
  void dispose() {
    packageCtrl.dispose();
    versionCtrl.dispose();
    codeCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = templates.entries.map((e) => MxDropdownItem<String>(value: e.key, label: e.value['name'] as String, icon: Icons.auto_awesome_motion_rounded)).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              MxIconBtn(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              const Expanded(child: Text('安装包编辑 / 编译模板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const MxSectionLabel('应用信息'),
            MxTextField(controller: packageCtrl, hint: '包名，例如 com.example.app', prefix: const Icon(Icons.apps_rounded)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MxTextField(controller: versionCtrl, hint: '版本号 1.0.0')),
              const SizedBox(width: 10),
              Expanded(child: MxTextField(controller: codeCtrl, hint: 'versionCode', keyboardType: TextInputType.number)),
            ]),
            const MxSectionLabel('模板'),
            MxDropdown<String>(
              value: selectedTemplate,
              items: items,
              onChanged: (v) => setState(() => selectedTemplate = v ?? selectedTemplate),
              hint: '点击选择模板',
            ),
            const SizedBox(height: 12),
            MxCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(templates[selectedTemplate]!['name'] as String, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('输出：${templates[selectedTemplate]!['output']}', style: TextStyle(color: scheme.onSurface.withOpacity(0.6))),
              const SizedBox(height: 8),
              ...(templates[selectedTemplate]!['steps'] as List).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [Icon(Icons.check_circle_rounded, size: 14, color: scheme.primary), const SizedBox(width: 6), Expanded(child: Text('$e', style: const TextStyle(fontSize: 12)))]),
              )),
            ])),
            const MxSectionLabel('说明'),
            const MxCard(child: Text('模板仅用于生成编译配置预案；实际依赖、权限和工程文件修改由 AI 自动执行。')),
          ],
        ),
      ),
    );
  }
}