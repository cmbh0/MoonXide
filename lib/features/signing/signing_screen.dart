import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/signing_store.dart';

class SigningScreen extends StatefulWidget {
  const SigningScreen({super.key});
  @override
  State<SigningScreen> createState() => _SigningScreenState();
}

class _SigningScreenState extends State<SigningScreen> {
  final _store = SigningStore();
  final _keystoreCtrl  = TextEditingController();
  final _aliasCtrl     = TextEditingController();
  final _storePassCtrl = TextEditingController();
  final _keyPassCtrl   = TextEditingController();
  bool _obscureStore = true;
  bool _obscureKey   = true;
  bool _saving = false;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await _store.read();
    if (cfg == null) return;
    _keystoreCtrl.text  = cfg['keystore']       ?? '';
    _aliasCtrl.text     = cfg['alias']           ?? '';
    _storePassCtrl.text = cfg['storePassword']   ?? '';
    _keyPassCtrl.text   = cfg['keyPassword']     ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _pickKeystore() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    final path = r?.files.single.path;
    if (path == null) return;
    setState(() => _keystoreCtrl.text = path);
  }

  Future<void> _save() async {
    final keystore = _keystoreCtrl.text.trim();
    final alias    = _aliasCtrl.text.trim();
    final sp       = _storePassCtrl.text;
    final kp       = _keyPassCtrl.text;
    if (keystore.isEmpty || alias.isEmpty || sp.isEmpty || kp.isEmpty) {
      setState(() => _saved = '请填写所有字段');
      return;
    }
    setState(() { _saving = true; _saved = null; });
    await _store.save(
      keystore: keystore,
      alias: alias,
      storePassword: sp,
      keyPassword: kp,
    );
    if (mounted) setState(() { _saving = false; _saved = '签名配置已保存'; });
  }

  @override
  void dispose() {
    _keystoreCtrl.dispose();
    _aliasCtrl.dispose();
    _storePassCtrl.dispose();
    _keyPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              MxIconBtn(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Keystore 签名配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ]),

            const MxSectionLabel('Keystore 文件'),
            MxCard(
              child: Row(children: [
                Icon(Icons.lock_outline_rounded, color: scheme.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _keystoreCtrl.text.isEmpty ? '未选择 .jks / .keystore 文件' : _keystoreCtrl.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _keystoreCtrl.text.isEmpty
                      ? scheme.onSurface.withOpacity(0.4)
                      : scheme.onSurface),
                )),
                const SizedBox(width: 8),
                MxButton(label: '选择', onPressed: _pickKeystore, small: true, filled: false),
              ]),
            ),

            const MxSectionLabel('签名信息'),
            // 快速填入默认调试签名
            MxCard(
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(child: Text('使用 Android 默认调试签名', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                MxButton(
                  label: '填入',
                  small: true,
                  filled: false,
                  onPressed: () => setState(() {
                    _keystoreCtrl.text  = '\$HOME/.android/debug.keystore';
                    _aliasCtrl.text     = 'androiddebugkey';
                    _storePassCtrl.text = 'android';
                    _keyPassCtrl.text   = 'android';
                  }),
                ),
              ]),
            ),
            MxTextField(
              controller: _aliasCtrl,
              hint: 'Key Alias（别名）',
              prefix: const Icon(Icons.badge_outlined, size: 17),
            ),
            const SizedBox(height: 10),
            MxTextField(
              controller: _storePassCtrl,
              hint: 'Store Password',
              obscure: _obscureStore,
              prefix: const Icon(Icons.key_rounded, size: 17),
              suffix: IconButton(
                icon: Icon(_obscureStore ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                onPressed: () => setState(() => _obscureStore = !_obscureStore),
              ),
            ),
            const SizedBox(height: 10),
            MxTextField(
              controller: _keyPassCtrl,
              hint: 'Key Password',
              obscure: _obscureKey,
              prefix: const Icon(Icons.vpn_key_rounded, size: 17),
              suffix: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),

            const MxSectionLabel('说明'),
            MxCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('签名配置仅存储在本地，不会上传到 GitHub。', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.65))),
                const SizedBox(height: 6),
                Text('Release 编译时，GitHub Actions 工作流会读取仓库 Secrets 中的签名信息。请确保在 GitHub 仓库 Settings → Secrets 中同步配置：', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.65))),
                const SizedBox(height: 8),
                ...[
                  'KEYSTORE_BASE64 — Keystore 文件的 Base64 编码',
                  'KEY_ALIAS — Key Alias',
                  'KEY_STORE_PASSWORD — Store Password',
                  'KEY_PASSWORD — Key Password',
                ].map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Icon(Icons.circle, size: 5, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: scheme.onSurface.withOpacity(0.75)))),
                  ]),
                )),
              ]),
            ),

            if (_saved != null) ...[
              const SizedBox(height: 8),
              Text(_saved!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _saved!.contains('已保存') ? scheme.primary : scheme.error,
                )),
            ],
            const SizedBox(height: 16),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : MxButton(label: '保存签名配置', icon: Icons.save_rounded, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
