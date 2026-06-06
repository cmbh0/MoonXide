import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'moonxide_theme.dart';
import '../core/services/app_state.dart';
import '../features/token_gate/token_gate_screen.dart';
import '../features/home/home_screen.dart';

class MoonXideApp extends StatelessWidget {
  const MoonXideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((state) => state.themeMode);
    final themeVariant = context.select<AppState, String>((state) => state.themeVariant);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoonXide',
      theme: MoonXideTheme.light(themeVariant),
      darkTheme: MoonXideTheme.dark(themeVariant),
      themeMode: themeMode,
      builder: (ctx, child) => _AppErrorBoundary(child: child ?? const SizedBox.shrink()),
      home: const _AppRouter(),
    );
  }
}

// ─── 路由守卫：等待 restore() 完成再决定跳哪个页面 ─────────────────────────
class _AppRouter extends StatefulWidget {
  const _AppRouter();
  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await context.read<AppState>().restore();
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF071722) : MoonXideTheme.snow,
        body: const Center(
          child: SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    final validated = context.watch<AppState>().tokenValidated;
    return validated ? const HomeScreen() : const TokenGateScreen();
  }
}

// ─── 全局错误边界：防止子树崩溃导致黑屏 ─────────────────────────────────────
class _AppErrorBoundary extends StatefulWidget {
  const _AppErrorBoundary({required this.child});
  final Widget child;
  @override
  State<_AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<_AppErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Material(
        color: const Color(0xFF071722),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFF8ED8FF), size: 48),
              const SizedBox(height: 16),
              const Text('渲染异常', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_error.toString(), style: const TextStyle(color: Color(0xFF8ED8FF), fontSize: 12), textAlign: TextAlign.center, maxLines: 6, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('重试', style: TextStyle(color: Color(0xFF8ED8FF))),
              ),
            ]),
          ),
        ),
      );
    }
    return widget.child;
  }
}
