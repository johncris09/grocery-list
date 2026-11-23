import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/repositories/hive_grocery_repository.dart';
import 'state/grocery_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local-first: everything lives in Hive on the device. To move to the
  // Laravel API later, swap this repository for an API-backed one.
  final repository = await HiveGroceryRepository.open();
  final data = GroceryData(
    items: await repository.loadItems(),
    trips: await repository.loadTrips(),
  );

  runApp(
    ProviderScope(
      overrides: [
        groceryRepositoryProvider.overrideWithValue(repository),
        initialGroceryDataProvider.overrideWithValue(data),
      ],
      child: const GroceryApp(),
    ),
  );
}
