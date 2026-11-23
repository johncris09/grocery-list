import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../domain/grocery_logic.dart';
import '../../state/grocery_controller.dart';
import '../../state/selectors.dart';
import '../widgets/common.dart';
import '../widgets/edit_item_sheet.dart';
import 'history_screen.dart';

/// Screen 1: today's list, the add row, To buy / Bought tabs.
class GroceriesScreen extends ConsumerStatefulWidget {
  const GroceriesScreen({super.key});

  @override
  ConsumerState<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends ConsumerState<GroceriesScreen> {
  final _text = TextEditingController();
  int _tab = 0;
  DateTime? _plannedDate; // null = today

  DateTime get _today => dateOnly(ref.read(clockProvider)());

  /// The "Buy on" value; falls back to today if the chosen day has passed.
  DateTime get _buyOn {
    final chosen = _plannedDate;
    return (chosen == null || chosen.isBefore(_today)) ? _today : chosen;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  GroceryController get _ctrl => ref.read(groceryControllerProvider.notifier);

  Future<void> _add() async {
    final raw = _text.text;
    final date = _buyOn;
    final result = _ctrl.addItem(raw, date);
    if (result == AddItemResult.emptyName) {
      showSnack(context, 'Type an item name first.');
      return;
    }
    if (result == AddItemResult.duplicate) {
      final name = parseEntry(raw)!.name;
      final when = isSameDay(date, _today) ? 'today' : formatShortDate(date);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Add "$name" again?'),
          content: Text('$name is already on the list for $when.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      _ctrl.addItem(raw, date, allowDuplicate: true);
    }
    _text.clear();
    if (_tab != 0) setState(() => _tab = 0);
  }

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _buyOn,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Buy on',
    );
    if (picked != null) setState(() => _plannedDate = dateOnly(picked));
  }

  void _saveTrip() {
    final trip = _ctrl.saveTrip();
    if (trip == null) {
      showSnack(context, 'Nothing bought today yet.');
    } else {
      final n = trip.itemIds.length;
      showSnack(context, 'Trip saved · $n ${n == 1 ? 'item' : 'items'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(countsProvider);
    ref.watch(groceryControllerProvider); // rebuild on any change
    final today = _today;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Column(
          children: [
            ScreenHeader(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatShortDate(today), style: mutedStyle14),
                  HeaderLink(
                    label: 'History',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Groceries', style: headerTitleStyle),
              const SizedBox(height: 2),
              Text(
                '${counts.today} to buy today · ${counts.planned} planned',
                style: const TextStyle(fontSize: 15, color: AppColors.muted),
              ),
            ]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _AddRow(
                      controller: _text,
                      onAdd: _add,
                      buyOn: _buyOn,
                      isToday: isSameDay(_buyOn, today),
                      onPickDate: _pickDate,
                    ),
                    const SizedBox(height: 14),
                    TabSwitcher(
                      labels: [
                        'To buy · ${counts.toBuy}',
                        'Bought · ${counts.bought}',
                      ],
                      selected: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                    Expanded(
                      child: _tab == 0
                          ? _GroupedList(
                              key: const ValueKey('list-toBuy'),
                              groups: ref.watch(toBuyGroupsProvider),
                              labelFor: (g) => g.isToday ? 'Today' : 'Planned',
                              empty: 'Nothing to buy. Add an item above.',
                              hint: 'Drag ⋮⋮ to reorder · long-press to edit · '
                                  'swipe left to delete',
                              onReorder: (g, from, to) =>
                                  _ctrl.reorderToBuy(g.date, from, to),
                            )
                          : _GroupedList(
                              key: const ValueKey('list-bought'),
                              groups: ref.watch(boughtGroupsProvider),
                              labelFor: (g) =>
                                  g.isToday ? 'Bought today' : 'Bought',
                              empty: 'Tick items off as you shop.',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // In the bottom bar slot so snackbars float above it.
        bottomNavigationBar:
            BottomAction(label: 'Save trip to history', onPressed: _saveTrip),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.controller,
    required this.onAdd,
    required this.buyOn,
    required this.isToday,
    required this.onPickDate,
  });

  final TextEditingController controller;
  final VoidCallback onAdd;
  final DateTime buyOn;
  final bool isToday;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        isToday ? 'Today · ${formatShortDate(buyOn)}' : formatShortDate(buyOn);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  key: const ValueKey('add-field'),
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onAdd(),
                  style: const TextStyle(fontSize: 16, color: AppColors.ink),
                  decoration: const InputDecoration(hintText: 'Add an item'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                key: const ValueKey('add-button'),
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.add, size: 24, semanticLabel: 'Add'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Buy on', style: mutedStyle14),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('buy-on'),
                onPressed: onPickDate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.inputBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupedList extends ConsumerStatefulWidget {
  const _GroupedList({
    super.key,
    required this.groups,
    required this.labelFor,
    required this.empty,
    this.hint = 'Long-press an item to edit · swipe left to delete',
    this.onReorder,
  });

  final List<DateGroup> groups;
  final String Function(DateGroup) labelFor;
  final String empty;
  final String hint;

  /// When set, each section's rows get a grip and can be dragged within
  /// that section. [to] is the item's final index after the move.
  final void Function(DateGroup group, int from, int to)? onReorder;

  @override
  ConsumerState<_GroupedList> createState() => _GroupedListState();
}

class _GroupedListState extends ConsumerState<_GroupedList> {
  /// Section being dragged in; the other sections dim while it's set.
  DateTime? _dragging;

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(widget.empty, style: mutedStyle14),
        ),
      );
    }
    final ctrl = ref.read(groceryControllerProvider.notifier);
    final onReorder = widget.onReorder;
    final dragging = _dragging;

    Widget dim(DateGroup g, Widget child) => AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: dragging == null || isSameDay(dragging, g.date) ? 1 : 0.45,
          child: child,
        );

    Widget row(DateGroup g, int index) {
      final item = g.items[index];
      return KeyedSubtree(
        key: ValueKey('slot-${item.id}'),
        child: dim(
          g,
          ItemRow(
            key: ValueKey('row-${item.id}'),
            item: item,
            dragIndex: onReorder == null ? null : index,
            onToggle: () => ctrl.toggleBought(item.id),
            onDelete: () => deleteWithUndo(
              ScaffoldMessenger.of(context),
              ctrl,
              item.id,
            ),
            onEdit: () => showEditItemSheet(context, item),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        for (final g in groups) ...[
          SliverToBoxAdapter(
            child: dim(
              g,
              SectionHeader(
                label: widget.labelFor(g),
                trailing: formatShortDate(g.date),
              ),
            ),
          ),
          if (onReorder == null)
            SliverList.list(
              children: [for (var i = 0; i < g.items.length; i++) row(g, i)],
            )
          else
            SliverReorderableList(
              itemCount: g.items.length,
              itemBuilder: (context, i) => row(g, i),
              proxyDecorator: liftedRowDecorator,
              onReorderStart: (_) => setState(() => _dragging = g.date),
              onReorderEnd: (_) => setState(() => _dragging = null),
              // Flutter reports the drop slot before removal; convert it to
              // the item's final index.
              onReorder: (from, to) =>
                  onReorder(g, from, to > from ? to - 1 : to),
            ),
        ],
        SliverPadding(
          padding: const EdgeInsets.only(top: 14, bottom: 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              widget.hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}
