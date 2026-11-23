import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'ui/screens/groceries_screen.dart';

class GroceryApp extends StatelessWidget {
  const GroceryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Groceries',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const GroceriesScreen(),
    );
  }
}
