import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/moonxide_theme.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';
import '../workspace/workspace_screen.dart';
import '../editor/editor_screen.dart';
import '../chat/chat_screen.dart';
import '../build/build_screen.dart';
import '../release/release_screen.dart';
import '../settings/settings_screen.dart';

// 左侧面板：文件树
// 右侧面板：AI / 编译 / 发行 / 设置
enum _LeftPanel  { none, workspace }
enum _RightPanel { none, ai, build, release, settings }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  _LeftPanel  _left  = _LeftPanel.none;
  _RightPanel _right = _RightPanel.none;

  late final AnimationController _leftAnim;
  late final AnimationController _rightAnim;
  late final Animation<double>   _leftFade;
  late final Animation<double>   _rightFade;

  @override
  void initState() {
    super.initState();
    const dur = Duration(milliseconds: 200);
    _leftAnim  = AnimationController(vsync: this, duration: dur);
    _rightAnim = AnimationController(vsync: this, duration: dur);
    _leftFade  = CurvedAnimation(parent: _leftAnim,  curve: Curves.easeOutCubic);
    _rightFade = CurvedAnimation(parent: _rightAnim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _leftAnim.dispose();
    _rightAnim.dispose();
    super.dispose();
  }

  void _openLeft(_LeftPanel p) {
    if (_left == p) { _closeLeft(); return; }
    setState(() => _left = p);
    _leftAnim.forward(from: 0);
  }

  void _openRight(_RightPanel p) {
    if (_right == p) { _closeRight(); return; }
    setState(() => _right = p);
    _rightAnim.forward(from: 0);
  }

  void _closeLeft() {
    _leftAnim.reverse().then((_) {
      if (mounted) setState(() => _left = _LeftPanel.none);
    });
  }

  void _closeRight() {
    _rightAnim.reverse().then((_) {
      if (mounted) setState(() => _right = _RightPanel.none);
    });
  }

  String _rightTitle() {
    switch (_right) {
      case _RightPanel.ai:       return 'AI 助手';
      case _RightPanel.build:    return '云编译';
      case _RightPanel.release:  return '发行版';
      case _RightPanel.settings: return '设置';
      case _RightPanel.none:     return '';
    }
  }

  Widget _buildRightContent(AppState state) {
    switch (_right) {
      case _RightPanel.ai:       return const ChatScreen();
      case _RightPanel.build:    return BuildScreen(state: state);
      case _RightPanel.release:  return const ReleaseScreen();
      case _RightPanel.settings: return SettingsScreen(state: state);
      case _RightPanel.none:     return const SizedBox.shrink();
    }
  }

  // ── 面板容器 ────────────────────────────────────────────────────────────────
  Widget _panelContainer({
    required bool fromLeft,
    required Animation<double> fade,
    required String title,
    required VoidCallback onClose,
    required Widget child,
    required double width,
    required bool isDark,
  }) {
    final bg = isDark ? const Color(0xFF0A1C2C) : const Color(0xFFF4FAFF);
    final border = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.60);
    final shadow = const Color(0xFF3B8FC7);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(fromLeft ? -0.05 : 0.05, 0),
          end: Offset.zero,
        ).animate(fade),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: bg,
            border: fromLeft
                ? Border(right: BorderSide(color: border))
                : Border(left:  BorderSide(color: border)),
            boxShadow: [
              BoxShadow(
                color: shadow.withOpacity(isDark ? 0.22 : 0.14),
                blurRadius: 32,
                offset: Offset(fromLeft ? 8 : -8, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
                  child: Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      MxIconBtn(
                          icon: Icons.close_rounded,
                          onPressed: onClose,
                          tooltip: '关闭',
                          size: 34),
                    ],
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final editor = context.watch<EditorState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final sw     = MediaQuery.of(context).size.width;
    // 面板宽度：左侧文件树稍窄，右侧内容稍宽
    final leftW  = sw * 0.72;
    final rightW = sw * 0.78;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071722) : MoonXideTheme.snow,
      body: Stack(
        children: [
          // ── 编辑器全屏底层 ──────────────────────────────────────────────────
          const Positioned.fill(child: EditorScreen()),

          // ── 左侧遮罩 ────────────────────────────────────────────────────────
          if (_left != _LeftPanel.none)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeLeft,
                child: FadeTransition(
                  opacity: _leftFade,
                  child: ColoredBox(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.28)),
                ),
              ),
            ),

          // ── 左侧面板（文件树，从左滑入） ────────────────────────────────────
          if (_left != _LeftPanel.none)
            Positioned(
              top: 0, left: 0, bottom: 0,
              child: _panelContainer(
                fromLeft: true,
                fade: _leftFade,
                title: '文件树',
                onClose: _closeLeft,
                width: leftW,
                isDark: isDark,
                child: WorkspaceScreen(state: state),
              ),
            ),

          // ── 右侧遮罩 ────────────────────────────────────────────────────────
          if (_right != _RightPanel.none)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeRight,
                child: FadeTransition(
                  opacity: _rightFade,
                  child: ColoredBox(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.28)),
                ),
              ),
            ),

          // ── 右侧面板（AI/编译/发行/设置，从右滑入） ─────────────────────────
          if (_right != _RightPanel.none)
            Positioned(
              top: 0, right: 0, bottom: 0,
              child: _panelContainer(
                fromLeft: false,
                fade: _rightFade,
                title: _rightTitle(),
                onClose: _closeRight,
                width: rightW,
                isDark: isDark,
                child: _buildRightContent(state),
              ),
            ),

          // ── 顶部浮层工具栏 ──────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    // 左上角：文件树
                    MxIconBtn(
                      icon: Icons.account_tree_rounded,
                      onPressed: () => _openLeft(_LeftPanel.workspace),
                      tooltip: '文件树',
                      active: _left == _LeftPanel.workspace,
                    ),
                    const SizedBox(width: 6),
                    // 文件名胶囊
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? const Color(0xFF0F2230)
                                  : Colors.white)
                              .withOpacity(isDark ? 0.80 : 0.88),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white.withOpacity(0.60),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file_rounded,
                                size: 13, color: scheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                editor.currentPath.isEmpty
                                    ? '未打开文件'
                                    : editor.currentPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        scheme.onSurface.withOpacity(0.68)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 右侧功能图标
                    MxIconBtn(
                      icon: Icons.auto_awesome_rounded,
                      onPressed: () => _openRight(_RightPanel.ai),
                      tooltip: 'AI',
                      active: _right == _RightPanel.ai,
                    ),
                    const SizedBox(width: 3),
                    MxIconBtn(
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => _openRight(_RightPanel.build),
                      tooltip: '编译',
                      active: _right == _RightPanel.build,
                    ),
                    const SizedBox(width: 3),
                    MxIconBtn(
                      icon: Icons.rocket_launch_rounded,
                      onPressed: () => _openRight(_RightPanel.release),
                      tooltip: '发行',
                      active: _right == _RightPanel.release,
                    ),
                    const SizedBox(width: 3),
                    MxIconBtn(
                      icon: Icons.tune_rounded,
                      onPressed: () => _openRight(_RightPanel.settings),
                      tooltip: '设置',
                      active: _right == _RightPanel.settings,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}