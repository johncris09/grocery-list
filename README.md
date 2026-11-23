# Grocery List

A daily grocery planner in Flutter. You add items, choose the day you plan to buy each one, tick them off while you shop, and save each day's purchases as a trip you can look back on and buy again. It works fully offline: all data is stored on the device.

The UI follows the approved "Grocery List" design canvas (phone size 390×844, Inter, green accent `#2E6B4F`).

## Run

Requirements: Flutter 3.41+ (Dart 3.11+), and an Android device or emulator or an iOS simulator.

```bash
flutter pub get
flutter run            # pick a device
flutter test           # unit + widget tests
flutter analyze
```

## How it works

| Layer | Path | Notes |
|---|---|---|
| Models | `lib/data/models/` | `GroceryItem` (id, name, quantity, plannedDate, status, boughtAt, tripId, createdAt), `Trip` (id, date, itemIds, createdAt). Plain JSON, no codegen. |
| Repository | `lib/data/repositories/` | `GroceryRepository` interface; `HiveGroceryRepository` (on device), `InMemoryGroceryRepository` (tests). |
| Rules | `lib/domain/grocery_logic.dart` | Pure functions for toggling, grouping, saving trips, buy-again, duplicate checks and quantity parsing. "Now" is always passed in. |
| State | `lib/state/` | Riverpod `GroceryController` (updates in memory first, then saves to the repository) plus derived selectors. |
| UI | `lib/ui/` | `GroceriesScreen`, `HistoryScreen`, shared widgets. |

**Moving to the Laravel API:** write an `ApiGroceryRepository implements GroceryRepository` and override `groceryRepositoryProvider` with it in `main.dart`. You don't need to change the UI or state code.

**Dates:** dates use the device's local timezone. Planned and trip dates are stored as `yyyy-MM-dd` strings, and `boughtAt` / `createdAt` as local ISO timestamps.

## Behaviour notes

- **Adding:** type the quantity at the end of the name, e.g. `Rice 5 kg` saves as *Rice / 5 kg*. Empty names are rejected. If the same name is already planned for that date, the app asks before adding it again.
- **To buy:** items are grouped by date, with **Today** first and then future dates. Unbought items from past days move into Today.
- **Bought:** items you've ticked but not yet saved, grouped by the day you bought them. Unticking moves an item back to To buy.
- **Save trip to history:** moves everything bought *today* into one trip and clears it from the Bought tab.
- **History:** shows trips from the last 30 days, newest first, and the search filters by item name. Tap a trip's date header to select it (it turns green). **Buy again** copies that trip into today's To buy list and skips names that are already on today's list. It defaults to the newest trip.
- **Delete:** swipe a row left.

## Still placeholder / not built

- No way to edit an item's name, quantity or date after adding it (you can delete and re-add).
- If the app stays open past midnight, "today" updates on the next interaction, not exactly at midnight.
- Bought items from earlier days that were never saved stay in the Bought tab. "Save trip" only archives today's.
- Trips can't be deleted or edited, and items older than 30 days stay in storage (history only hides them).
- No Laravel API repository, sync, or conflict handling yet (interface only).
- App icon, launcher name, splash screen and bundle id (`com.example.grocery_list`) are Flutter defaults.
- Not yet checked on a physical device or with a screen reader. iOS has not been built (developed on Windows).
- Dark mode is not designed. The app always uses the light theme.

Fonts: Inter 4.1 (SIL Open Font License, see `assets/fonts/OFL.txt`), bundled so the app needs no network.
