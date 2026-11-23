import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/models/grocery_item.dart';
import '../../state/grocery_controller.dart';
import 'common.dart';

/// Deletes an item and shows "Item deleted · Undo".
void deleteWithUndo(
  ScaffoldMessengerState messenger,
  GroceryController controller,
  String id,
) {
  final removed = controller.deleteItem(id);
  if (removed == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('"${removed.name}" deleted'),
      duration: const Duration(seconds: 4),
      persist: false, // auto-hide even though it has an action
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => controller.restoreItem(removed),
      ),
    ));
}

/// Opens the edit sheet for [item] (long-press on a row).
Future<void> showEditItemSheet(BuildContext context, GroceryItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => EditItemSheet(item: item),
  );
}

class EditItemSheet extends ConsumerStatefulWidget {
  const EditItemSheet({super.key, required this.item});
  final GroceryItem item;

  @override
  ConsumerState<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<EditItemSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _qty = TextEditingController(text: widget.item.quantity);
  late DateTime _date;
  String? _nameError;

  DateTime get _today => dateOnly(ref.read(clockProvider)());
  GroceryController get _ctrl => ref.read(groceryControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    final today = _today;
    // Overdue items show (and save) today's date.
    _date = widget.item.plannedDate.isBefore(today)
        ? today
        : widget.item.plannedDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Buy on',
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final result = _ctrl.editItem(
      widget.item.id,
      name: _name.text,
      quantity: _qty.text,
      plannedDate: _date,
    );
    if (result == EditItemResult.emptyName) {
      setState(() => _nameError = 'Enter a name');
      return;
    }
    if (result == EditItemResult.duplicate) {
      final name = _name.text.trim();
      final when = isSameDay(_date, _today) ? 'today' : formatShortDate(_date);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Keep two "$name"?'),
          content: Text('$name is already on the list for $when.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      _ctrl.editItem(
        widget.item.id,
        name: _name.text,
        quantity: _qty.text,
        plannedDate: _date,
        allowDuplicate: true,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _delete() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    deleteWithUndo(messenger, _ctrl, widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final bought = widget.item.isBought;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final dateLabel = isSameDay(_date, _today)
        ? 'Today · ${formatShortDate(_date)}'
        : formatShortDate(_date);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboard),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Edit item',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _label('Name'),
            TextField(
              key: const ValueKey('edit-name'),
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 16, color: AppColors.ink),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. Rice',
                errorText: _nameError,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _label('Quantity'),
            TextField(
              key: const ValueKey('edit-qty'),
              controller: _qty,
              style: const TextStyle(fontSize: 16, color: AppColors.ink),
              decoration: const InputDecoration(
                hintText: 'e.g. 5 kg (optional)',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            if (!bought) ...[
              const SizedBox(height: 12),
              _label('Buy on'),
              OutlinedButton(
                key: const ValueKey('edit-date'),
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('edit-delete'),
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const ValueKey('edit-save'),
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: mutedStyle14),
      );
}
