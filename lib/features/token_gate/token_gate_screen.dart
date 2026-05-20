import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/moonxide_theme.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';

class TokenGateScreen extends StatefulWidget {
  const TokenGateScreen({super.key});

  @override
  State<TokenGateScreen> createState() => _TokenGateScreenState();
}

class _TokenGateScreenState extends State<TokenGateScreen> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openTokenPage() async {
    final uri = Uri.https('github.com', '/settings/tokens/new', {
      'description': 'MoonXide',
      'scopes': 'repo,workflow,read:user,write:packages,delete_repo',
    });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开浏览器，请手动访问 GitHub Token 页面')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.token != null && state.token!.isNotEmpty && _ctrl.text.isEmpty) {
      _ctrl.text = state.token!;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071722) : MoonXideTheme.snow,
      body: Stack(
        children: [
          // ── 背景光斑 ──────────────────────────────────────────────────────
          Positioned(
            top: -120, right: -80,
            child: _Blob(size: 300,
                color: const Color(0xFF9CD8FF).withOpacity(isDark ? 0.14 : 0.32)),
          ),
          Positioned(
            bottom: -60, left: -100,
            child: _Blob(size: 260,
                color: const Color(0xFFD9F2FF).withOpacity(isDark ? 0.08 : 0.40)),
          ),
          Positioned(
            top: 200, left: -60,
            child: _Blob(size: 180,
                color: const Color(0xFFB8E8FF).withOpacity(isDark ? 0.06 : 0.22)),
          ),

          // ── 内容 ──────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 52),

                  // Logo
          // ── Logo ──────────────────────────────────────────────────────────
          Row(
                    children: [
                      Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.white.withOpacity(0.75),
                              width: 1.5),
                        ),
                        child: Icon(Icons.terrain_rounded,
                            color: scheme.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MoonXide',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? const Color(0xFFE9F8FF)
                                    : MoonXideTheme.deepBlue,
                              )),
                          Text('Snow Alpine IDE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withOpacity(0.48),
                              )),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  Text('连接 GitHub',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFFE9F8FF) : MoonXideTheme.deepBlue,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    '需要 GitHub Personal Access Token 才能管理仓库、触发编译和发布版本。',
                    style: TextStyle(
                        fontSize: 14, color: scheme.onSurface.withOpacity(0.58)),
                  ),

                  const SizedBox(height: 28),

                  // Token 输入卡片
                  MxGlass(
                    padding: const EdgeInsets.all(18),
                    radius: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MxTextField(
                          controller: _ctrl,
                          hint: 'ghp_xxxxxxxxxxxx',
                          label: 'GitHub Token',
                          obscure: _obscure,
                          prefix: const Icon(Icons.key_rounded, size: 18),
                          suffix: MxIconBtn(
                            icon: _obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            onPressed: () => setState(() => _obscure = !_obscure),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'repo · workflow · read:user · write:packages · delete_repo',
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withOpacity(0.42)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 状态反馈
                  if (state.tokenStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            state.tokenValidated
                                ? Icons.check_circle_rounded
                                : Icons.info_rounded,
                            size: 15,
                            color: state.tokenValidated ? Colors.green : scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              state.tokenStatus!,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: state.tokenValidated
                                    ? Colors.green
                                    : scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.error_rounded,
                              size: 15, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(state.error!,
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // 操作按钮
                  MxButton(
                    label: '前往 GitHub 创建令牌',
                    icon: Icons.open_in_new_rounded,
                    onPressed: _openTokenPage,
                    filled: false,
                  ),
                  const SizedBox(height: 10),
                  MxButton(
                    label: state.loading ? '验证中…' : '验证并进入 MoonXide',
                    icon: state.loading ? Icons.hourglass_top_rounded : Icons.login_rounded,
                    onPressed: state.loading
                        ? null
                        : () async {
                            final ok =
                                await context.read<AppState>().acceptToken(_ctrl.text);
                            if (ok && mounted) {
                              Navigator.of(context).pushReplacementNamed('/home');
                            }
                          },
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}