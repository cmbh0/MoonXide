import 'package:flutter/material.dart';

// ─── 统一页面容器 ─────────────────────────────────────────────────────────────
// 所有功能页面都用这个包裹，保证视觉一致性。
// 不再各自 return Scaffold，而是 return MxPage(...)。
class MxPage extends StatelessWidget {
  const MxPage({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.fab,
    this.bottom,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? fab;
  final PreferredSizeWidget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: title == null && actions == null && bottom == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 16,
              title: title != null ? Text(title!, style: const TextStyle(fontWeight: FontWeight.w800)) : null,
              actions: actions,
              bottom: bottom,
            ),
      floatingActionButton: fab,
      body: child,
    );
  }
}

// ─── 统一卡片 ─────────────────────────────────────────────────────────────────
class MxCard extends StatelessWidget {
  const MxCard({super.key, required this.child, this.padding, this.onTap, this.color});

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: color ?? scheme.surface.withOpacity(0.72),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── 节标题 ───────────────────────────────────────────────────────────────────
class MxSectionLabel extends StatelessWidget {
  const MxSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.48),
        ),
      ),
    );
  }
}

// ─── 行动按钮行 ───────────────────────────────────────────────────────────────
class MxActionRow extends StatelessWidget {
  const MxActionRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: children
            .expand((w) => [w, const SizedBox(width: 10)])
            .toList()
          ..removeLast(),
      ),
    );
  }
}

// ─── 状态徽章 ─────────────────────────────────────────────────────────────────
class MxBadge extends StatelessWidget {
  const MxBadge(this.label, {super.key, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

// ─── 空状态占位 ───────────────────────────────────────────────────────────────
class MxEmpty extends StatelessWidget {
  const MxEmpty({super.key, required this.icon, required this.label, this.hint});
  final IconData icon;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: scheme.onSurface.withOpacity(0.22)),
          const SizedBox(height: 14),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface.withOpacity(0.55))),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!, style: TextStyle(fontSize: 13, color: scheme.onSurface.withOpacity(0.38))),
          ],
        ],
      ),
    );
  }
}

// ─── 进度条横幅 ───────────────────────────────────────────────────────────────
class MxProgressBanner extends StatelessWidget {
  const MxProgressBanner({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}