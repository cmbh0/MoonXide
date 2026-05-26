import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/github_logo.dart';
import '../../app/mx_widgets.dart';
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

  void _showAccountManageDialog(BuildContext context, AppState state) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addTokenCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F1B26) : Colors.white,
              title: const Text('多账号与切换', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text('已保存的账号列表：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (state.accounts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('暂无保存的其他账号', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                    ...state.accounts.map((acc) {
                      final isCurrent = acc['login'] == state.login;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? scheme.primary.withOpacity(0.08)
                              : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent ? scheme.primary.withOpacity(0.4) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: (acc['avatarUrl'] ?? '').isNotEmpty
                                  ? NetworkImage(acc['avatarUrl']!)
                                  : null,
                              child: (acc['avatarUrl'] ?? '').isEmpty ? const Icon(Icons.person_rounded, size: 14) : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '@${acc['login']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              const Icon(Icons.check_circle_rounded, size: 15, color: Colors.green)
                            else
                              IconButton(
                                icon: const Icon(Icons.login_rounded, size: 15),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await state.switchAccount(acc['login']!);
                                },
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await state.removeAccount(acc['login']!);
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(height: 20),
                    const Text('添加新账号：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF162533) : const Color(0xFFF1F3F4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.onSurface.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: addTokenCtrl,
                        obscureText: true,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: '输入新 Token (ghp_...)',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
                TextButton(
                  onPressed: () async {
                    final val = addTokenCtrl.text.trim();
                    if (val.isEmpty) return;
                    Navigator.pop(ctx);
                    await state.acceptToken(val);
                  },
                  child: const Text('验证并登录'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.token != null && state.token!.isNotEmpty && _ctrl.text.isEmpty) {
      _ctrl.text = state.token!;
    }

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
              const SizedBox(height: 48),

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
                  child: GitHubLogo(
                    width: 44,
                    height: 44,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

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

              Text(
                '使用 GitHub Personal Access Token 安全登录并访问您的资源。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 36),

              // ── 账号管理切换入口 ──
              if (state.accounts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton.icon(
                    onPressed: () => _showAccountManageDialog(context, state),
                    icon: const Icon(Icons.switch_account_rounded),
                    label: Text(
                      '已保存 ${state.accounts.length} 个账号，点击切换/管理',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              Text(
                'Personal Access Token',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fieldLabelColor,
                ),
              ),
              const SizedBox(height: 8),

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

              Text(
                'Token 以 “ghp_”、“github_pat_” 或 “v1.” 开头',
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 48),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
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
                            : () async {
                                final ok = await context.read<AppState>().acceptToken(_ctrl.text.trim());
                                if (ok && mounted) {
                                  _ctrl.text = state.token ?? '';
                                }
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
                  ),
                  if (state.token != null && state.token!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final ok = await MxDialog.show(
                            context,
                            title: '退出登录',
                            content: '确认退出当前账号 @${state.login} 吗？',
                            confirmLabel: '退出',
                            cancelLabel: '取消',
                            confirmColor: Colors.redAccent,
                          );
                          if (ok) {
                            await state.logout();
                            _ctrl.clear();
                          }
                        },
                        child: const Text('退出登录', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

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
