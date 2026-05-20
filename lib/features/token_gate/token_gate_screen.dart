import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/app_state.dart';
import '../../app/moonxide_theme.dart';

class TokenGateScreen extends StatefulWidget {
  const TokenGateScreen({super.key});

  @override
  State<TokenGateScreen> createState() => _TokenGateScreenState();
}

class _TokenGateScreenState extends State<TokenGateScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _openTokenPage() async {
    final uri = Uri.https('github.com', '/settings/tokens/new', {
      'description': 'MoonXide',
      'scopes': 'repo,workflow,read:user,write:packages,delete_repo',
    });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法打开浏览器，请手动访问 GitHub Token 页面')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    if (state.token != null && state.token!.isNotEmpty && controller.text.isEmpty) {
      controller.text = state.token!;
    }
    return Scaffold(
      body: Stack(
        children: [
          // 背景渐变
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [MoonXideTheme.snow, MoonXideTheme.ice, MoonXideTheme.frost],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  // Logo 区
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary.withOpacity(0.12),
                          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                        ),
                        child: Icon(Icons.terrain_rounded, color: scheme.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MoonXide', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: MoonXideTheme.deepBlue)),
                          Text('Snow Alpine IDE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface.withOpacity(0.52))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text('连接 GitHub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: MoonXideTheme.deepBlue)),
                  const SizedBox(height: 6),
                  Text('需要 GitHub Personal Access Token 才能管理仓库、触发编译和发布版本。', style: TextStyle(color: scheme.onSurface.withOpacity(0.62))),
                  const SizedBox(height: 24),
                  // Token 输入卡片
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.78),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.72)),
                      boxShadow: const [BoxShadow(color: Color(0x1A3B8FC7), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: controller,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '粘贴 GitHub Token',
                            hintText: 'ghp_xxxxxxxxxxxx',
                            prefixIcon: Icon(Icons.key_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('建议权限：repo · workflow · read:user · write:packages', style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.48))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 状态反馈
                  if (state.tokenStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(state.tokenStatus!, style: TextStyle(fontWeight: FontWeight.w700, color: state.tokenValidated ? Colors.green : scheme.primary)),
                    ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(state.error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                  const Spacer(),
                  // 操作按钮
                  OutlinedButton.icon(
                    onPressed: _openTokenPage,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('前往 GitHub 创建令牌'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: state.loading
                        ? null
                        : () async {
                            final ok = await context.read<AppState>().acceptToken(controller.text);
                            if (ok && mounted) Navigator.of(context).pushReplacementNamed('/home');
                          },
                    child: state.loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('验证并进入 MoonXide'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}