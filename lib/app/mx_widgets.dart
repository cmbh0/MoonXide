import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MoonXide 自定义 UI 组件库 — 静态磨砂材质，无动态模糊
// ═══════════════════════════════════════════════════════════════════════════════

// ─── 磨砂容器 ─────────────────────────────────────────────────────────────────
class MxGlass extends StatelessWidget {
  const MxGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20.0,
    this.opacity = 0.92,
    this.border = true,
    this.shadow = true,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double opacity;
  final bool border;
  final bool shadow;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base   = color ?? (isDark ? const Color(0xFF0F2230) : Colors.white);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: base.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radius),
        border: border
            ? Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.09)
                    : Colors.white.withOpacity(0.70),
              )
            : null,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: const Color(0xFF3B8FC7).withOpacity(isDark ? 0.14 : 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      child: child,
    );
  }
}

// ─── 磨砂卡片（可点击） ───────────────────────────────────────────────────────
class MxCard extends StatelessWidget {
  const MxCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.radius = 16.0,
  });

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;
    final base    = color ?? (isDark ? const Color(0xFF0F2230) : Colors.white);
    final borderC = isDark
        ? Colors.white.withOpacity(0.08)
        : scheme.primary.withOpacity(0.10);
    final card = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: base.withOpacity(isDark ? 0.82 : 0.90),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          splashColor: scheme.primary.withOpacity(0.07),
          child: Container(
            padding: padding ?? const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderC),
            ),
            child: child,
          ),
        ),
      ),
    );
    return onTap == null ? card : _MxPressable(child: card);
  }
}

// ─── 自定义下拉菜单 ───────────────────────────────────────────────────────────
class MxDropdown<T> extends StatelessWidget {
  const MxDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.prefix,
  });

  final T? value;
  final List<MxDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F2230) : Colors.white)
            .withOpacity(isDark ? 0.82 : 0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withOpacity(0.18)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: hint != null
              ? Text(hint!,
                  style: TextStyle(color: scheme.onSurface.withOpacity(0.45)))
              : null,
          icon: Icon(Icons.expand_more_rounded, color: scheme.primary),
          dropdownColor: isDark ? const Color(0xFF0F2230) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e.value,
                    child: Row(children: [
                      if (e.icon != null) ...[
                        Icon(e.icon, size: 16, color: scheme.primary),
                        const SizedBox(width: 8),
                      ],
                      Text(e.label),
                    ]),
                  ))
              .toList(),
          onChanged: onChanged,
          isExpanded: true,
        ),
      ),
    );
  }
}

class MxDropdownItem<T> {
  const MxDropdownItem({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

// ─── 自定义按钮 ───────────────────────────────────────────────────────────────
class MxButton extends StatelessWidget {
  const MxButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.small = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool small;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final c        = color ?? scheme.primary;
    final disabled = onPressed == null;
    return _MxPressable(
      child: Material(
      color: filled
          ? c.withOpacity(disabled ? 0.30 : 1.0)
          : c.withOpacity(0.08),
      borderRadius: BorderRadius.circular(small ? 10 : 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(small ? 10 : 14),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: small ? 12 : 18, vertical: small ? 8 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(small ? 10 : 14),
            border: filled
                ? null
                : Border.all(color: c.withOpacity(0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: small ? 15 : 17,
                    color: filled ? Colors.white : c),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: small ? 13 : 14,
                      color: filled ? Colors.white : c)),
            ],
          ),
        ),
      ),
    ));
  }
}

// ─── 自定义输入框 ─────────────────────────────────────────────────────────────
class MxTextField extends StatelessWidget {
  const MxTextField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.prefix,
    this.suffix,
    this.obscure = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscure;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: obscure,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: TextStyle(color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: (isDark ? const Color(0xFF0F2230) : Colors.white)
            .withOpacity(isDark ? 0.82 : 0.90),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary.withOpacity(0.18))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary.withOpacity(0.18))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: scheme.primary.withOpacity(0.60), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.40)),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: c.withOpacity(0.13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.28))),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: c)),
    );
  }
}

// ─── 空状态 ───────────────────────────────────────────────────────────────────
class MxEmpty extends StatelessWidget {
  const MxEmpty(
      {super.key, required this.icon, required this.label, this.hint});
  final IconData icon;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.onSurface.withOpacity(0.18)),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withOpacity(0.45))),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!,
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.30))),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: children
            .expand((w) => [Expanded(child: w), const SizedBox(width: 10)])
            .toList()
          ..removeLast(),
      ),
    );
  }
}

// ─── 图标按钮（静态磨砂） ─────────────────────────────────────────────────────
class MxIconBtn extends StatelessWidget {
  const MxIconBtn({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.active = false,
    this.size = 40,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = active
        ? scheme.primary.withOpacity(0.14)
        : Colors.transparent;
    final w = Material(
      color: bg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onPressed,
        onLongPress: onLongPress,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.48,
            color: active
                ? scheme.primary
                : scheme.onSurface.withOpacity(0.56),
          ),
        ),
      ),
    );
    final animated = (onPressed == null && onLongPress == null) ? w : _MxPressable(child: w);
    return tooltip != null ? Tooltip(message: tooltip!, child: animated) : animated;
  }
}

// ─── 分割线 ───────────────────────────────────────────────────────────────────
class MxDivider extends StatelessWidget {
  const MxDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 20,
        thickness: 0.5,
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withOpacity(0.30));
  }
}

// ─── 进度横幅 ─────────────────────────────────────────────────────────────────
class MxProgressBanner extends StatelessWidget {
  const MxProgressBanner({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ─── 自定义开关 ───────────────────────────────────────────────────────────────
class MxSwitch extends StatelessWidget {
  const MxSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? scheme.primary : scheme.onSurface.withOpacity(0.18),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))]),
          ),
        ),
      ),
    );
  }
}

// ─── 自定义对话框（iOS 磨砂毛玻璃风格） ──────────────────────────────────────
class MxDialog extends StatelessWidget {
  const MxDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = '确认',
    this.cancelLabel = '取消',
    this.confirmColor,
    this.onConfirm,
    this.onCancel,
  });
  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final Color? confirmColor;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  static Future<bool> show(BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = '确认',
    String cancelLabel = '取消',
    Color? confirmColor,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogCtx) => MxDialog(
        title: title, content: content,
        confirmLabel: confirmLabel, cancelLabel: cancelLabel,
        confirmColor: confirmColor,
        onConfirm: () => Navigator.of(dialogCtx).pop(true),
        onCancel: () => Navigator.of(dialogCtx).pop(false),
      ),
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmC = confirmColor ?? scheme.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: _MxPressable(
        child: Container(
          decoration: BoxDecoration(
            // 静态磨砂：深色半透明 + 高斯模糊感通过多层叠加模拟
            color: isDark
                ? const Color(0xFF1A2E3E).withOpacity(0.92)
                : Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.80),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.55 : 0.18),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: scheme.primary.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题 + 内容区
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  children: [
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(content,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: scheme.onSurface.withOpacity(0.65))),
                  ],
                ),
              ),
              // iOS 风格分割线
              Divider(height: 0.5, thickness: 0.5,
                  color: scheme.onSurface.withOpacity(0.15)),
              // 按钮行
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _DialogBtn(
                        label: cancelLabel,
                        color: scheme.onSurface.withOpacity(0.55),
                        onTap: onCancel ?? () => Navigator.pop(context, false),
                        roundLeft: true,
                      ),
                    ),
                    VerticalDivider(width: 0.5, thickness: 0.5,
                        color: scheme.onSurface.withOpacity(0.15)),
                    Expanded(
                      child: _DialogBtn(
                        label: confirmLabel,
                        color: confirmC,
                        bold: true,
                        onTap: onConfirm ?? () => Navigator.pop(context, true),
                        roundRight: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── iOS 风格底部弹窗 ─────────────────────────────────────────────────────────
class MxBottomSheet extends StatelessWidget {
  const MxBottomSheet({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;

  static Future<T?> show<T>(BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => MxBottomSheet(title: title, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A2E3E).withOpacity(0.94)
              : Colors.white.withOpacity(0.90),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.white.withOpacity(0.75),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.50 : 0.14),
              blurRadius: 40,
              spreadRadius: -4,
              offset: const Offset(0, -8),
            ),
            BoxShadow(
              color: scheme.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogBtn extends StatefulWidget {
  const _DialogBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
    this.roundLeft = false,
    this.roundRight = false,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool bold;
  final bool roundLeft;
  final bool roundRight;

  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.only(
      bottomLeft:  widget.roundLeft  ? const Radius.circular(20) : Radius.zero,
      bottomRight: widget.roundRight ? const Radius.circular(20) : Radius.zero,
    );
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _pressed
              ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))
              : Colors.transparent,
          borderRadius: radius,
        ),
        child: Center(
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w400,
                  color: widget.color)),
        ),
      ),
    );
  }
}

class _MxPressable extends StatefulWidget {
  const _MxPressable({required this.child});
  final Widget child;
  @override
  State<_MxPressable> createState() => _MxPressableState();
}

class _MxPressableState extends State<_MxPressable> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => down = true),
      onPointerUp: (_) => setState(() => down = false),
      onPointerCancel: (_) => setState(() => down = false),
      child: AnimatedScale(
        scale: down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
