import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/moonxide_theme.dart';
import '../../core/services/app_state.dart';
import '../workspace/workspace_screen.dart';
import '../editor/editor_screen.dart';
import '../chat/chat_screen.dart';
import '../build/build_screen.dart';
import '../release/release_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 1; // 默认进编辑器

  static const _tabs = <_Tab>[
    _Tab('工作区', Icons.folder_open_rounded),
    _Tab('编辑器', Icons.edit_note_rounded),
    _Tab('AI', Icons.auto_awesome_rounded),
    _Tab('编译', Icons.play_arrow_rounded),
    _Tab('发行', Icons.rocket_launch_rounded),
    _Tab('设置', Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final screens = [
      WorkspaceScreen(state: state),
      const EditorScreen(),
      const ChatScreen(),
      BuildScreen(state: state),
      const ReleaseScreen(),
      SettingsScreen(state: state),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071722) : MoonXideTheme.snow,
      body: Stack(
        children: [
          // 背景光斑
          Positioned(top: -80, right: -60, child: _Blob(size: 200, color: const Color(0xFF9CD8FF).withOpacity(isDark ? 0.14 : 0.28))),
          Positioned(bottom: 80, left: -80, child: _Blob(size: 220, color: const Color(0xFFD9F2FF).withOpacity(isDark ? 0.08 : 0.38))),
          // 主内容
          Column(
            children: [
              // 顶部标题栏
              _TopBar(
                tab: _tabs[_index],
                login: state.login,
                repo: state.selectedOwner != null && state.selectedRepo != null ? '${state.selectedOwner}/${state.selectedRepo}' : null,
              ),
              // 页面内容
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(key: ValueKey(_index), child: screens[_index]),
                ),
              ),
              // 底部导航栏
              _BottomNav(tabs: _tabs, selected: _index, onSelect: (i) => setState(() => _index = i)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

// ─── 顶部标题栏 ───────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.tab, required this.login, required this.repo});
  final _Tab tab;
  final String? login;
  final String? repo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withOpacity(0.12),
              ),
              child: Icon(Icons.terrain_rounded, color: scheme.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tab.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  if (repo != null)
                    Text(repo!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            if (login != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('@$login', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 底部导航栏 ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tabs, required this.selected, required this.onSelect});
  final List<_Tab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF0F2230) : Colors.white).withOpacity(0.78),
              border: Border(top: BorderSide(color: scheme.outlineVariant.withOpacity(0.25))),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = i == selected;
                return Expanded(
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: active ? scheme.primary.withOpacity(0.14) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(tabs[i].icon, size: 22, color: active ? scheme.primary : scheme.onSurface.withOpacity(0.5)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                            color: active ? scheme.primary : scheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 背景光斑 ─────────────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    );
  }
}