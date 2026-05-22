import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/moonxide_theme.dart';
import '../../app/mx_widgets.dart';
import '../../core/services/app_state.dart';
import '../../core/services/editor_state.dart';
import '../../core/services/build_center_state.dart';
import '../workspace/workspace_screen.dart';
import '../editor/editor_screen.dart';
import '../chat/chat_screen.dart';
import '../build/build_screen.dart';
import '../release/release_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';

enum _LeftPanel  { none, workspace }
enum _RightPanel { none, ai, build, release, settings }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  _LeftPanel  _left  = _LeftPanel.none;
  _RightPanel _right = _RightPanel.none;

  late final AnimationController _leftAnim;
  late final AnimationController _rightAnim;
  late final Animation<double>   _leftSlide;
  late final Animation<double>   _rightSlide;
  Timer? _buildPollTimer;

  // GlobalKey 用于调用 EditorScreen 的方法
  final _editorKey = GlobalKey<EditorScreenState>();

  @override
  void initState() {
    super.initState();
    const dur = Duration(milliseconds: 220);
    _leftAnim   = AnimationController(vsync: this, duration: dur);
    _rightAnim  = AnimationController(vsync: this, duration: dur);
    _leftSlide  = CurvedAnimation(parent: _leftAnim,  curve: Curves.easeOutCubic);
    _rightSlide = CurvedAnimation(parent: _rightAnim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _leftAnim.dispose();
    _rightAnim.dispose();
    _buildPollTimer?.cancel();
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

  Future<void> _pollBuild(AppState state, BuildCenterState build) async {
    final owner = state.selectedOwner;
    final repo = state.selectedRepo;
    if (!build.busy || owner == null || repo == null || state.github == null) return;
    try {
      final runs = await state.github!.listWorkflowRuns(owner, repo);
      if (runs.isEmpty) return;
      final run = runs.first;
      final status = run['status'];
      final conclusion = run['conclusion'];
      final url = run['html_url']?.toString();
      final progress = status == 'completed' ? 1.0 : (status == 'in_progress' ? 0.62 : 0.25);
      if (status == 'completed' && conclusion == 'success') {
        build.finish('构建完成：success');
        final artifacts = await state.github!.listArtifacts(owner, repo, run['id'] as int);
        if (artifacts.isNotEmpty) {
          final artifact = artifacts.first;
          build.setArtifact(
            downloadUrl: artifact['archive_download_url'] as String?,
            name: artifact['name']?.toString(),
          );
        }
      } else if (status == 'completed') {
        build.fail('构建结束：${conclusion ?? 'unknown'}');
      } else {
        build.updateProgress(statusText: '构建中：$status', value: progress, runUrl: url);
      }
    } catch (_) {}
  }

  void _ensureBuildPolling(AppState state, BuildCenterState build) {
    if (!build.busy) {
      _buildPollTimer?.cancel();
      _buildPollTimer = null;
      return;
    }
    _buildPollTimer ??= Timer.periodic(const Duration(minutes: 2), (_) => _pollBuild(state, build));
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

  // ── 面板容器 ─────────────────────────────────────────────────────────────────
  Widget _panelContainer({
    required bool fromLeft,
    required Animation<double> anim,
    required String title,
    required VoidCallback onClose,
    required Widget child,
    required double width,
    required bool isDark,
    bool hasBg = false,
  }) {
    final bg     = (isDark ? const Color(0xFF0A1C2C) : const Color(0xFFF4FAFF))
        .withOpacity(hasBg ? 0.82 : 1.0);
    final border = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.07);
    final shadow = const Color(0xFF3B8FC7);

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(fromLeft ? -1.0 : 1.0, 0),
        end: Offset.zero,
      ).animate(anim),
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
            // 面板标题栏（含 SafeArea 顶部）
            SafeArea(
              bottom: false,
              child: Container(
                height: 52,
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                child: Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    MxIconBtn(
                        icon: Icons.close_rounded,
                        onPressed: onClose,
                        tooltip: '关闭',
                        size: 36),
                  ],
                ),
              ),
            ),
            // 面板内容
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  // ── 顶部工具栏高度（用于编辑器内容偏移） ────────────────────────────────────
  static const double _toolbarH = 52.0;

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final build  = context.watch<BuildCenterState>();
    final editor = context.watch<EditorState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final mq     = MediaQuery.of(context);
    final sw     = mq.size.width;
    final topPad = mq.padding.top; // 状态栏高度

    final leftW  = sw * 0.56;
    final rightW = sw * 0.78;

    // 工具栏总高 = 状态栏 + 固定高度
    final toolbarTotal = topPad + _toolbarH;
    _ensureBuildPolling(state, build);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF071722) : MoonXideTheme.snow,
      body: Stack(
        children: [
          if (state.customBackgroundPath != null)
            Positioned.fill(
              child: Image.file(
                File(state.customBackgroundPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (state.customBackgroundPath != null)
            Positioned.fill(
              child: ColoredBox(color: (isDark ? Colors.black : Colors.white)
                  .withOpacity(1.0 - state.bgOpacity)),
            ),
          // ── 编辑器全屏底层（顶部留出工具栏空间） ──────────────────────────────
          Positioned(
            top: toolbarTotal,
            left: 0,
            right: 0,
            bottom: 0,
            child: EditorScreen(key: _editorKey),
          ),

          // ── 顶部工具栏（平时在编辑器上方；面板打开后会被面板覆盖） ───────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: toolbarTotal,
            child: _TopBar(
              isDark: isDark,
              scheme: scheme,
              topPad: topPad,
              editor: editor,
              state: state,
              leftOpen: _left == _LeftPanel.workspace,
              rightPanel: _right,
              onMenuTap: () => _openLeft(_LeftPanel.workspace),
              onAiTap:      () => _openRight(_RightPanel.ai),
              onBuildTap:   () => _openRight(_RightPanel.build),
              onReleaseTap: () => _openRight(_RightPanel.release),
              onSettingsTap:() => _openRight(_RightPanel.settings),
              onSearchTap:  () => _editorKey.currentState?.toggleFind(),
              onUndoTap:    editor.undo,
              onRedoTap:    editor.redo,
              onSaveLongPress: () {
                final st = _editorKey.currentState;
                if (st != null) st.saveAll(context);
              },
              onSaveTap:    () {
                final st = _editorKey.currentState;
                if (st != null) st.save(context);
              },
            ),
          ),

          // ── 左侧遮罩 ──────────────────────────────────────────────────────────
          if (_left != _LeftPanel.none)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeLeft,
                child: FadeTransition(
                  opacity: _leftSlide,
                  child: ColoredBox(
                      color: Colors.black
                          .withOpacity(isDark ? 0.45 : 0.28)),
                ),
              ),
            ),

          // ── 左侧面板（文件树，从左滑入） ──────────────────────────────────────
          if (_left != _LeftPanel.none)
            Positioned(
              top: 0, left: 0, bottom: 0,
              child: _panelContainer(
                fromLeft: true,
                anim: _leftSlide,
                title: '文件树',
                onClose: _closeLeft,
                width: leftW,
                isDark: isDark,
                hasBg: state.customBackgroundPath != null,
                child: WorkspaceScreen(state: state),
              ),
            ),

          // ── 右侧遮罩 ──────────────────────────────────────────────────────────
          if (_right != _RightPanel.none)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeRight,
                child: FadeTransition(
                  opacity: _rightSlide,
                  child: ColoredBox(
                      color: Colors.black
                          .withOpacity(isDark ? 0.45 : 0.28)),
                ),
              ),
            ),

          // ── 右侧面板（AI/编译/发行/设置，从右滑入） ───────────────────────────
          if (_right != _RightPanel.none)
            Positioned(
              top: 0, right: 0, bottom: 0,
              child: _panelContainer(
                fromLeft: false,
                anim: _rightSlide,
                title: _rightTitle(),
                onClose: _closeRight,
                width: rightW,
                isDark: isDark,
                hasBg: state.customBackgroundPath != null,
                child: _buildRightContent(state),
              ),
            ),

          // ── 右下角构建迷你通知条 ─────────────────────────────────────────────
          if (build.busy)
            Positioned(
              right: 12,
              bottom: 14,
              child: _BuildToast(center: build),
            ),
        ],
      ),
    );
  }
}

// ─── 顶部工具栏组件 ───────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isDark,
    required this.scheme,
    required this.topPad,
    required this.editor,
    required this.state,
    required this.leftOpen,
    required this.rightPanel,
    required this.onMenuTap,
    required this.onAiTap,
    required this.onBuildTap,
    required this.onReleaseTap,
    required this.onSettingsTap,
    required this.onSearchTap,
    required this.onUndoTap,
    required this.onRedoTap,
    required this.onSaveTap,
    required this.onSaveLongPress,
  });

  final bool isDark;
  final ColorScheme scheme;
  final double topPad;
  final EditorState editor;
  final AppState state;
  final bool leftOpen;
  final _RightPanel rightPanel;
  final VoidCallback onMenuTap;
  final VoidCallback onAiTap;
  final VoidCallback onBuildTap;
  final VoidCallback onReleaseTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSearchTap;
  final VoidCallback onUndoTap;
  final VoidCallback onRedoTap;
  final VoidCallback onSaveTap;
  final VoidCallback onSaveLongPress;

  @override
  Widget build(BuildContext context) {
    final bg = (isDark ? const Color(0xFF071722) : MoonXideTheme.snow)
        .withOpacity(0.97);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.06);

    // 右侧面板激活状态
    final rightActive = rightPanel != _RightPanel.none;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.only(top: topPad),
      child: SizedBox(
        height: _HomeScreenState._toolbarH,
        child: Row(
          children: [
            // ── 文件树按钮
            MxIconBtn(
              icon: Icons.menu_rounded,
              onPressed: onMenuTap,
              tooltip: '文件树',
              active: leftOpen,
              size: 40,
            ),
            // ── 查找
            MxIconBtn(
              icon: Icons.search_rounded,
              onPressed: onSearchTap,
              tooltip: '查找',
              size: 36,
            ),
            // ── 撤销/重做/保存 紧凑排列
            MxIconBtn(
              icon: Icons.undo_rounded,
              onPressed: editor.canUndo ? onUndoTap : null,
              active: editor.canUndo,
              size: 32,
            ),
            MxIconBtn(
              icon: Icons.redo_rounded,
              onPressed: editor.canRedo ? onRedoTap : null,
              active: editor.canRedo,
              size: 32,
            ),
            MxIconBtn(
              icon: Icons.save_rounded,
              onPressed: onSaveTap,
              onLongPress: onSaveLongPress,
              tooltip: editor.dirtyCount > 1 ? '保存当前；长按推送全部 ${editor.dirtyCount} 个文件' : '保存当前文件',
              active: editor.modified || editor.dirtyCount > 0,
              size: 34,
            ),
            const SizedBox(width: 4),
            // ── 文件名胶囊（Expanded 保证不被挤）
            Expanded(
              child: _FileTab(
                path: editor.currentPath,
                modified: editor.modified,
                dirtyCount: editor.dirtyCount,
                isDark: isDark,
                scheme: scheme,
              ),
            ),
            const SizedBox(width: 4),
            // ── 右侧功能：AI / 编译 / 发行 / 设置 收进 PopupMenu
            _RightMenu(
              rightPanel: rightPanel,
              onAiTap: onAiTap,
              onBuildTap: onBuildTap,
              onReleaseTap: onReleaseTap,
              onSettingsTap: onSettingsTap,
              isDark: isDark,
              scheme: scheme,
            ),
            const SizedBox(width: 2),
            _AvatarButton(state: state),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'GitHub 主页',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfileScreen(state: state)),
        ),
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary.withOpacity(0.45), width: 1.4),
            boxShadow: [BoxShadow(color: scheme.primary.withOpacity(0.12), blurRadius: 10)],
          ),
          child: CircleAvatar(
            backgroundColor: scheme.primary.withOpacity(0.12),
            backgroundImage: state.avatarUrl == null ? null : NetworkImage(state.avatarUrl!),
            child: state.avatarUrl == null ? Icon(Icons.person_rounded, size: 18, color: scheme.primary) : null,
          ),
        ),
      ),
    );
  }
}

// ─── 文件名标签页 ─────────────────────────────────────────────────────────────
class _FileTab extends StatelessWidget {
  const _FileTab({required this.path, required this.modified,
      required this.isDark, required this.scheme, required this.dirtyCount});
  final String path;
  final bool modified;
  final bool isDark;
  final ColorScheme scheme;
  final int dirtyCount;

  @override
  Widget build(BuildContext context) {
    final name = path.isEmpty ? '未打开文件' : path.split('/').last;
    final dir  = path.isEmpty ? '' : path.contains('/')
        ? path.substring(0, path.lastIndexOf('/'))
        : '';
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.07),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded, size: 11, color: scheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withOpacity(path.isEmpty ? 0.35 : 0.75)),
            ),
          ),
          if (modified || dirtyCount > 0) ...[
            const SizedBox(width: 4),
            Container(
              width: 5, height: 5,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 右侧功能菜单（收进 PopupMenu 减少拥挤） ──────────────────────────────────
class _RightMenu extends StatelessWidget {
  const _RightMenu({
    required this.rightPanel,
    required this.onAiTap,
    required this.onBuildTap,
    required this.onReleaseTap,
    required this.onSettingsTap,
    required this.isDark,
    required this.scheme,
  });
  final _RightPanel rightPanel;
  final VoidCallback onAiTap;
  final VoidCallback onBuildTap;
  final VoidCallback onReleaseTap;
  final VoidCallback onSettingsTap;
  final bool isDark;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final active = rightPanel != _RightPanel.none;
    return PopupMenuButton<int>(
      tooltip: '功能面板',
      offset: const Offset(0, 44),
      color: isDark ? const Color(0xFF0A1C2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06)),
      ),
      onSelected: (v) {
        switch (v) {
          case 0: onAiTap(); break;
          case 1: onBuildTap(); break;
          case 2: onReleaseTap(); break;
          case 3: onSettingsTap(); break;
        }
      },
      itemBuilder: (_) => [
        _menuItem(0, Icons.auto_awesome_rounded, 'AI 助手',
            rightPanel == _RightPanel.ai, scheme),
        _menuItem(1, Icons.play_arrow_rounded, '云编译',
            rightPanel == _RightPanel.build, scheme),
        _menuItem(2, Icons.rocket_launch_rounded, '发行版',
            rightPanel == _RightPanel.release, scheme),
        _menuItem(3, Icons.tune_rounded, '设置',
            rightPanel == _RightPanel.settings, scheme),
      ],
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? scheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          active ? Icons.dashboard_rounded : Icons.dashboard_outlined,
          size: 18,
          color: active ? scheme.primary : scheme.onSurface.withOpacity(0.52),
        ),
      ),
    );
  }

  PopupMenuItem<int> _menuItem(int v, IconData icon, String label,
      bool active, ColorScheme scheme) {
    return PopupMenuItem<int>(
      value: v,
      height: 40,
      child: Row(children: [
        Icon(icon, size: 16,
            color: active ? scheme.primary : scheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? scheme.primary : scheme.onSurface.withOpacity(0.8))),
      ]),
    );
  }
}

class _BuildToast extends StatelessWidget {
  const _BuildToast({required this.center});
  final BuildCenterState center;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = center.status.contains('推送') ? '正在推送' : '正在构建';
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0F2230) : Colors.white).withOpacity(0.74),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withOpacity(0.22)),
          boxShadow: [BoxShadow(color: scheme.primary.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(scheme.primary))),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
              Text('${(center.progress * 100).round()}%', style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: center.progress <= 0 ? null : center.progress, minHeight: 4),
            ),
            const SizedBox(height: 6),
            Text(center.status.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurface.withOpacity(0.62))),
          ],
        ),
      ),
    );
  }
}
