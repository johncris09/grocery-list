import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/grocery_item.dart';

/// Beige header band shared by both screens (design: padding 52/20/14,
/// where the 52 includes the status bar).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final top = math.max(MediaQuery.paddingOf(context).top + 8, 20.0);
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(20, top, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Green text link used for "History" and "← Today" (44px tap height).
class HeaderLink extends StatelessWidget {
  const HeaderLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

const headerTitleStyle = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  color: AppColors.ink,
  height: 1.2,
);
const mutedStyle14 = TextStyle(fontSize: 14, color: AppColors.muted);

/// "TODAY ............ Mon, Nov 23"
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    required this.trailing,
    this.uppercase = true,
    this.top = 18,
    this.bottom = 4,
    this.color = AppColors.muted,
  });

  final String label;
  final String trailing;
  final bool uppercase;
  final double top;
  final double bottom;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: uppercase ? 0.78 : 0.52,
                color: color,
              ),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              fontSize: 13,
              fontWeight: uppercase ? FontWeight.w500 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A list row: checkbox, name, quantity. The whole row toggles.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final GroceryItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final done = item.isBought;
    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: AppColors.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Text(
          'Delete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onToggle,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Transform.scale(
                    scale: 24 / 18,
                    child: Checkbox(
                      key: ValueKey('check-${item.id}'),
                      value: done,
                      onChanged: (_) => onToggle(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: VisualDensity.minimumDensity,
                        vertical: VisualDensity.minimumDensity,
                      ),
                      semanticLabel: item.name,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: done ? AppColors.doneText : AppColors.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.doneText,
                    ),
                  ),
                ),
                if (item.quantity.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  Text(
                    item.quantity,
                    style: TextStyle(
                      fontSize: 14,
                      color: done ? AppColors.doneQty : AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented "To buy · N | Bought · N" control.
class TabSwitcher extends StatelessWidget {
  const TabSwitcher({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.tabTrack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _tab(i)),
          ],
        ],
      ),
    );
  }

  Widget _tab(int i) {
    final active = i == selected;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        key: ValueKey('tab-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            labels[i],
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinned full-width button at the bottom of a screen.
class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.ink,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(MediaQuery.paddingOf(context).bottom + 12, 30.0);
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
