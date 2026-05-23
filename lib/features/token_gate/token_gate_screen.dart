import 'dart:math' as math;
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

class _TokenGateScreenState extends State<TokenGateScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  late final AnimationController _particleCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _particleCtrl.dispose();
    _fadeCtrl.dispose();
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
      backgroundColor: isDark ? const Color(0xFF040E18) : MoonXideTheme.snow,
      body: Stack(children: [
        // ── 粒子背景 ──────────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) => CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ParticlePainter(
              progress: _particleCtrl.value,
              isDark: isDark,
              primary: scheme.primary,
            ),
          ),
        ),

        // ── 渐变遮罩 ──────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF040E18).withOpacity(0.0), const Color(0xFF040E18).withOpacity(0.85)]
                  : [MoonXideTheme.snow.withOpacity(0.0), MoonXideTheme.snow.withOpacity(0.80)],
            ),
          ),
        ),

        // ── 内容 ──────────────────────────────────────────────────────────────
        SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 56),

                  // ── Logo 区 ──────────────────────────────────────────────
                  Center(
                    child: Column(children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [scheme.primary, scheme.primary.withOpacity(0.55)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: scheme.primary.withOpacity(0.40), blurRadius: 28, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: const Icon(Icons.terrain_rounded, color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 16),
                      Text('MoonXide', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: isDark ? const Color(0xFFE9F8FF) : MoonXideTheme.deepBlue)),
                      const SizedBox(height: 4),
                      Text('Snow Alpine IDE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 2.0, color: scheme.onSurface.withOpacity(0.40))),
                    ]),
                  ),

                  const SizedBox(height: 44),

                  // ── 标题 ──────────────────────────────────────────────────
                  Text('连接 GitHub', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFE9F8FF) : MoonXideTheme.deepBlue)),
                  const SizedBox(height: 8),
                  Text('请提供 GitHub Token，我们需要权限来访问你的仓库、执行云端编译等。Token 仅保存在本地设备。', style: TextStyle(fontSize: 13, height: 1.6, color: scheme.onSurface.withOpacity(0.55))),

                  const SizedBox(height: 24),

                  // ── 权限说明卡片 ──────────────────────────────────────────
                  _PermCard(isDark: isDark, scheme: scheme),

                  const SizedBox(height: 20),

                  // ── Token 输入卡片 ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF0A1929) : Colors.white).withOpacity(isDark ? 0.88 : 0.92),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.09) : scheme.primary.withOpacity(0.14)),
                      boxShadow: [BoxShadow(color: scheme.primary.withOpacity(isDark ? 0.12 : 0.08), blurRadius: 32, offset: const Offset(0, 8))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Icon(Icons.key_rounded, size: 16, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text('Personal Access Token', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: scheme.primary)),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ctrl,
                        obscureText: _obscure,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: scheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                          hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.30), fontFamily: 'monospace'),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary.withOpacity(0.18))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary.withOpacity(0.18))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary.withOpacity(0.60), width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: scheme.onSurface.withOpacity(0.45)),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('repo · workflow · read:user · write:packages · delete_repo', style: TextStyle(fontSize: 11, color: scheme.onSurface.withOpacity(0.38), fontFamily: 'monospace')),
                    ]),
                  ),

                  const SizedBox(height: 12),

// ─── 状态反馈 ──────────────────────────────────────────────
                  if (state.tokenStatus != null)
                    MxCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: state.tokenValidated ? Colors.green.withOpacity(0.1) : scheme.primary.withOpacity(0.1),
                      child: _StatusRow(text: state.tokenStatus!, ok: state.tokenValidated, scheme: scheme),
                    ),
                  if (state.error != null)
                    MxCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.red.withOpacity(0.1),
                      child: _StatusRow(text: state.error!, ok: false, scheme: scheme, isError: true),
                    ),

                  const SizedBox(height: 20),

                  // ── 操作按钮 ──────────────────────────────────────────────
                  MxButton(
                    label: '前往 GitHub 创建令牌',
                    icon: Icons.open_in_new_rounded,
                    onPressed: _openTokenPage,
                    filled: false,
                  ),
                  const SizedBox(height: 10),
                  MxButton(
                    label: state.loading ? '验证中…' : '进入系统',
                    icon: state.loading ? Icons.hourglass_top_rounded : Icons.arrow_forward_rounded,
                    onPressed: state.loading ? null : () => context.read<AppState>().acceptToken(_ctrl.text),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── 权限说明卡片 ─────────────────────────────────────────────────────────────
class _PermCard extends StatelessWidget {
  const _PermCard({required this.isDark, required this.scheme});
  final bool isDark;
  final ColorScheme scheme;

  static const _perms = [
    (Icons.folder_rounded,       'repo',             '读写代码'),
    (Icons.play_circle_rounded,  'workflow',         '触发编译'),
    (Icons.person_rounded,       'read:user',        '读取账号'),
    (Icons.inventory_2_rounded,  'write:packages',   '发布产物'),
    (Icons.delete_forever_rounded,'delete_repo',     '删除仓库'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withOpacity(0.16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield_rounded, size: 15, color: scheme.primary),
          const SizedBox(width: 7),
          Text('所需权限说明', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _perms.map((p) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(p.$1, size: 12, color: scheme.primary),
                const SizedBox(width: 4),
                Text(p.$2, style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: scheme.onSurface)),
              ],
            ),
          )).toList(),
        ),
      ]),
    );
  }
}

// ─── 状态行 ───────────────────────────────────────────────────────────────────
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.text, required this.ok, required this.scheme, this.isError = false});
  final String text;
  final bool ok;
  final ColorScheme scheme;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : (ok ? Colors.green : scheme.primary);
    final icon  = isError ? Icons.error_rounded : (ok ? Icons.check_circle_rounded : Icons.info_rounded);
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
    ]);
  }
}

// ─── 粒子背景 Painter ─────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress, required this.isDark, required this.primary});
  final double progress;
  final bool isDark;
  final Color primary;

  static final _rng = math.Random(42);
  static final _particles = List.generate(38, (i) => [
    _rng.nextDouble(), // x ratio
    _rng.nextDouble(), // y ratio
    _rng.nextDouble() * 0.6 + 0.2, // speed factor
    _rng.nextDouble() * 2.5 + 0.8, // radius
    _rng.nextDouble(),              // phase
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final phase = (progress * p[2] + p[4]) % 1.0;
      final x = p[0] * size.width;
      final y = (p[1] + phase * 0.4) % 1.0 * size.height;
      final opacity = (math.sin(phase * math.pi) * 0.55 + 0.05).clamp(0.0, 0.55);
      final paint = Paint()
        ..color = primary.withOpacity(isDark ? opacity * 0.7 : opacity * 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p[3], paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}