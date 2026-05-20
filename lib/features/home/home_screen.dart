import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  int index = 1;

  static const _items = <_MoonNavItem>[
    _MoonNavItem('工作区', Icons.folder_open_rounded),
    _MoonNavItem('编辑器', Icons.edit_note_rounded),
    _MoonNavItem('AI', Icons.auto_awesome_rounded),
    _MoonNavItem('编译', Icons.play_arrow_rounded),
    _MoonNavItem('发行', Icons.rocket_launch_rounded),
    _MoonNavItem('设置', Icons.tune_rounded),
  ];

  void _openSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.96),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('MoonXide 功能切换', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('AI 聊天与任务执行已合并在一个入口里'),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.25,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _items.length,
                itemBuilder: (_, i) => _SwitcherTile(
                  item: _items[i],
                  selected: i == index,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => index = i);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final screens = [
      WorkspaceScreen(state: state),
      const EditorScreen(),
      const ChatScreen(),
      BuildScreen(state: state),
      const ReleaseScreen(),
      SettingsScreen(state: state),
    ];
    final item = _items[index];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 54,
        leading: IconButton(onPressed: _openSwitcher, icon: const Icon(Icons.menu_rounded)),
        titleSpacing: 0,
        title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          _TopNavIcon(item: _items[0], selected: index == 0, onTap: () => setState(() => index = 0)),
          _TopNavIcon(item: _items[1], selected: index == 1, onTap: () => setState(() => index = 1)),
          _TopNavIcon(item: _items[2], selected: index == 2, onTap: () => setState(() => index = 2)),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => setState(() => index = value),
            itemBuilder: (_) => [
              for (var i = 3; i < _items.length; i++)
                PopupMenuItem(value: i, child: ListTile(leading: Icon(_items[i].icon), title: Text(_items[i].label))),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(key: ValueKey(index), child: screens[index]),
      ),
    );
  }
}

class _MoonNavItem {
  const _MoonNavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _TopNavIcon extends StatelessWidget {
  const _TopNavIcon({required this.item, required this.selected, required this.onTap});
  final _MoonNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: IconButton(
        tooltip: item.label,
        onPressed: onTap,
        icon: Icon(item.icon, color: selected ? scheme.primary : scheme.onSurface),
        style: IconButton.styleFrom(backgroundColor: selected ? scheme.primary.withOpacity(0.12) : null),
      ),
    );
  }
}

class _SwitcherTile extends StatelessWidget {
  const _SwitcherTile({required this.item, required this.selected, required this.onTap});
  final _MoonNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withOpacity(0.14) : scheme.surfaceContainerHighest.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? scheme.primary.withOpacity(0.4) : scheme.outlineVariant.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: selected ? scheme.primary : scheme.onSurface),
            const SizedBox(height: 8),
            Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
