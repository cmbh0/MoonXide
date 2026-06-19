import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/mx_widgets.dart';
import '../../core/ai/ai_api_mode.dart';
import '../../core/ai/ai_config_state.dart';
import '../../core/ai/ai_api_client.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final baseController = TextEditingController();
  final pathController = TextEditingController();
  final keyController = TextEditingController();
  final modelController = TextEditingController();
  final temperatureController = TextEditingController();
  final topPController = TextEditingController();
  final maxTokensController = TextEditingController();
  final systemController = TextEditingController();
  final testController = TextEditingController(text: '请用一句话回复：接口配置正常。');
  bool synced = false;

  @override
  void dispose() {
    for (final c in [baseController, pathController, keyController, modelController, temperatureController, topPController, maxTokensController, systemController, testController]) { c.dispose(); }
    super.dispose();
  }

  void _sync(AiConfigState state) {
    if (synced || !state.loaded) return;
    final c = state.config;
    baseController.text = c.baseUrl;
    pathController.text = c.endpointPath;
    keyController.text = c.apiKey;
    modelController.text = c.model;
    temperatureController.text = c.temperature;
    topPController.text = c.topP;
    maxTokensController.text = c.maxTokens;
    systemController.text = c.systemPrompt;
    synced = true;
  }

  Future<void> _save(AiConfigState state) async {
    var next = state.config.copyWith(
      baseUrl: baseController.text,
      endpointPath: pathController.text,
      apiKey: keyController.text,
      model: modelController.text,
      temperature: temperatureController.text,
      topP: topPController.text,
      maxTokens: maxTokensController.text,
      systemPrompt: systemController.text,
    );
    next = next.copyWith(baseUrl: state.normalizer.normalizeBaseUrl(next.baseUrl), endpointPath: state.normalizer.normalizePath(next.endpointPath, next.mode));
    await state.update(next);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 接口配置已保存')));
  }

  Future<void> _test(AiConfigState state) async {
    await _save(state);
    try {
      final body = await AiApiClient().send(state.config, testController.text);
      if (mounted) {
        MxBottomSheet.show(
          context,
          title: '测试响应',
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: SingleChildScrollView(
                child: SelectableText(
                  body,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            MxButton(
              label: '关闭',
              icon: Icons.close_rounded,
              filled: false,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('测试失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AiConfigState>();
    _sync(state);
    final actual = state.normalizer.actualUrl(baseUrl: baseController.text, endpointPath: pathController.text, mode: state.config.mode);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              MxIconBtn(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              const Expanded(child: Text('AI 接口设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const MxSectionLabel('接口模式'),
            MxDropdown<AiApiMode>(
              value: state.config.mode,
              hint: '点击选择 API 格式',
              items: AiApiMode.values.map((e) => MxDropdownItem(value: e, label: e.label, icon: Icons.api_rounded)).toList(),
              onChanged: (v) async { if (v == null) return; pathController.text = v.defaultPath; await state.setMode(v); },
            ),
            const SizedBox(height: 12),
            MxTextField(controller: baseController, hint: '请求地址 / 域名', prefix: const Icon(Icons.link_rounded), onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            Text(actual.isEmpty ? '实际请求地址会显示在这里' : '实际请求地址：$actual', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 12),
            MxTextField(controller: pathController, hint: state.config.mode.defaultPath, prefix: const Icon(Icons.route_rounded), onChanged: (_) => setState(() {})),
            const MxSectionLabel('模型'),
            MxTextField(controller: keyController, hint: 'API Key', obscure: true, prefix: const Icon(Icons.key_rounded)),
            const SizedBox(height: 10),
            MxTextField(controller: modelController, hint: '模型名，例如 gpt-4o-mini', prefix: const Icon(Icons.memory_rounded)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MxTextField(controller: temperatureController, hint: 'temperature', keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: MxTextField(controller: topPController, hint: 'top_p', keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 10),
            MxTextField(controller: maxTokensController, hint: 'max_tokens，空则不传', keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            MxTextField(controller: systemController, hint: '系统提示词，空则不传', minLines: 3, maxLines: 6),
            const MxSectionLabel('流式'),
            MxCard(child: Row(children: [
              const Expanded(child: Text('SSE 流式模式', style: TextStyle(fontWeight: FontWeight.w800))),
              MxSwitch(value: state.config.stream, onChanged: state.setStream),
            ])),
            const MxSectionLabel('测试'),
            MxTextField(controller: testController, hint: '测试输入', minLines: 2, maxLines: 4),
            const SizedBox(height: 12),
            MxActionRow(children: [
              MxButton(label: '保存配置', icon: Icons.save_rounded, onPressed: () => _save(state)),
              MxButton(label: '保存并测试', icon: Icons.play_arrow_rounded, onPressed: () => _test(state), filled: false),
            ]),
          ],
        ),
      ),
    );
  }
}