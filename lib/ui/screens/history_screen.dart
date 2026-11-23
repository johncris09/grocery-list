import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/models/grocery_item.dart';
import '../../domain/grocery_logic.dart';
import '../../state/grocery_controller.dart';
import '../../state/selectors.dart';
import '../widgets/common.dart';

/// Screen 2: saved trips from the last 30 days, searchable.
/// Tap a trip's header to pick which trip "Buy again" copies.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _selectedTripId;

  void _buyAgain(TripView trip) {
    final added =
        ref.read(groceryControllerProvider.notifier).buyAgain(trip.trip.id);
    if (added == 0) {
      showSnack(context, "Those items are already on today's list.");
      return;
    }
    showSnack(context,
        'Added $added ${added == 1 ? 'item' : 'items'} to today');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(ref.watch(clockProvider)());
    final data = ref.watch(groceryControllerProvider);
    final shown = ref.watch(historyProvider);
    final query = ref.watch(historySearchProvider);

    // Selection is resolved against all trips, not the filtered ones.
    final all = historyTrips(data.trips, data.items, today);
    final newest = all.isEmpty ? null : all.first;
    final selected = all.where((v) => v.trip.id == _selectedTripId).firstOrNull ??
        newest;
    final buttonLabel = selected == null || selected == newest
        ? 'Buy again from last trip'
        : 'Buy again from ${formatShortDate(selected.trip.date)}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Column(
          children: [
            ScreenHeader(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HeaderLink(
                    label: '← Today',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Text('Last 30 days', style: mutedStyle14),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Purchase history', style: headerTitleStyle),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: TextField(
                  key: const ValueKey('history-search'),
                  onChanged: (v) =>
                      ref.read(historySearchProvider.notifier).state = v,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 16, color: AppColors.ink),
                  decoration: const InputDecoration(
                    hintText: 'Search past purchases',
                  ),
                ),
              ),
            ]),
            Expanded(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                      child: Text(
                        query.trim().isEmpty
                            ? 'No trips saved in the last 30 days.\n'
                                'Tick items off and tap "Save trip to history".'
                            : 'No past purchases match "${query.trim()}".',
                        textAlign: TextAlign.center,
                        style: mutedStyle14,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      children: [
                        for (final view in shown) ...[
                          _TripHeader(
                            view: view,
                            today: today,
                            selected: view.trip.id == selected?.trip.id,
                            onTap: () => setState(
                                () => _selectedTripId = view.trip.id),
                          ),
                          for (final item in view.items) _HistoryRow(item: item),
                        ],
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: BottomAction(
          label: buttonLabel,
          color: AppColors.accent,
          onPressed: selected == null ? null : () => _buyAgain(selected),
        ),
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({
    required this.view,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final TripView view;
  final DateTime today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = view.totalCount;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Select trip for buy again',
      child: InkWell(
        key: ValueKey('trip-${view.trip.id}'),
        onTap: onTap,
        child: SectionHeader(
          label: formatHistoryDate(view.trip.date, today),
          trailing: '$n ${n == 1 ? 'item' : 'items'}',
          uppercase: false,
          top: 22,
          bottom: 2,
          color: selected ? AppColors.accent : AppColors.muted,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final GroceryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          if (item.quantity.isNotEmpty)
            Text(item.quantity, style: mutedStyle14),
        ],
      ),
    );
  }
}
