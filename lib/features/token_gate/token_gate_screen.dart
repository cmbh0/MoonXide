import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/app_state.dart';

class TokenGateScreen extends StatefulWidget {
  const TokenGateScreen({super.key});

  @override
  State<TokenGateScreen> createState() => _TokenGateScreenState();
}

class _TokenGateScreenState extends State<TokenGateScreen> {
  final _ctrl = TextEditingController();

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
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.token != null && state.token!.isNotEmpty && _ctrl.text.isEmpty) {
      _ctrl.text = state.token!;
    }

    // 图片中背景是纯白色（或者纯黑色，取决于深浅模式，一般以纯白为主风格，这里我们支持主题色或者极简白/极简黑）
    final bgColor = isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF5F6368);
    final fieldLabelColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF202124);
    final inputBgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderCol = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFDADCE0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 56),

              // ── 顶部居中的 GitHub Logo ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Image.network(
                    'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/github/github-original.svg',
                    width: 44,
                    height: 44,
                    color: isDark ? Colors.white : Colors.black,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.logo_dev_rounded,
                        color: isDark ? Colors.white : Colors.black,
                        size: 40,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 使用 Token 登录 ──
              Text(
                '使用 Token 登录',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),

              // ── 使用 GitHub Personal Access Token 安全登录并访问您的资源 ──
              Text(
                '使用 GitHub Personal Access Token\n安全登录并访问您的资源',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 48),

              // ── Personal Access Token 标签 ──
              Text(
                'Personal Access Token',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fieldLabelColor,
                ),
              ),
              const SizedBox(height: 8),

              // ── 输入框 ──
              Container(
                decoration: BoxDecoration(
                  color: inputBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol, width: 1.2),
                ),
                child: TextField(
                  controller: _ctrl,
                  obscureText: true,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ghp_••••••••••••••••••••••••',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.25)
                          : Colors.black.withOpacity(0.25),
                      fontFamily: 'monospace',
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : Colors.black.withOpacity(0.4),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Token 以 “ghp_”、“github_pat_” 或 “v1.” 开头 ──
              Text(
                'Token 以 “ghp_”、“github_pat_” 或 “v1.” 开头',
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 48),

              // ── 登录按钮 ──
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: state.loading
                      ? null
                      : () {
                          context.read<AppState>().acceptToken(_ctrl.text.trim());
                        },
                  child: state.loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          '登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 您的 Token 将安全存储，仅用于 API 访问 ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: subtitleColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '您的 Token 将安全存储，仅用于 API 访问',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 错误或者状态反馈，优雅提示出来而不在布局里占大卡片
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (state.tokenStatus != null && state.tokenValidated)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.tokenStatus!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(height: 48),

              // ── 如何创建 Token? ──────────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: _openTokenPage,
                  style: TextButton.styleFrom(
                    foregroundColor: subtitleColor,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '如何创建 Token?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF1A73E8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF1A73E8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
