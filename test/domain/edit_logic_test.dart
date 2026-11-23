import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_list/domain/grocery_logic.dart';

import '../support/fixtures.dart';

void main() {
  test('applyEdit cleans text and strips time from the date', () {
    final edited = applyEdit(
      item('Rice', quantity: '5 kg'),
      name: '  Brown   rice ',
      quantity: ' 2  kg ',
      plannedDate: DateTime(2026, 11, 25, 17, 30),
    );
    expect(edited.name, 'Brown rice');
    expect(edited.quantity, '2 kg');
    expect(edited.plannedDate, DateTime(2026, 11, 25));
    expect(edited.id, 'rice');
  });

  test('duplicate check can ignore the item being edited', () {
    final items = [item('Rice')];
    expect(hasDuplicateOnDate(items, 'rice', kToday, kNow), isTrue);
    expect(
      hasDuplicateOnDate(items, 'rice', kToday, kNow, excludeId: 'rice'),
      isFalse,
    );
  });
}
