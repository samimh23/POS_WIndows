# Smart POS · Windows local prototype

A functional Flutter desktop POS for café demonstrations in Tunisia. Material 3, Riverpod, integer millimes, and local JSON snapshots. No backend, APIs, database, hardware, or network services. All application operations work offline once the application is built.

## Run on this Windows computer

Open PowerShell in this project directory:

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

The verified development environment is Flutter 3.29.2 / Dart 3.7.2 and Visual Studio Community 2022 with the Windows C++ desktop workload and Windows SDK. Android license warnings do not affect the Windows build. The dependencies are locked in `pubspec.lock`; upgrading Flutter or dependencies is not needed to run this version. The initial SDK/package setup may require internet; using the compiled application does not.

Close the running app before rebuilding. To build a standalone application after running debug/integration builds, clear generated files so Flutter installs the correct release runtime:

```powershell
flutter clean
flutter pub get
flutter build windows --release
```

Run `build\windows\x64\runner\Release\smart_pos.exe`. Keep its adjacent DLLs and `data` folder together. The portable ZIP supplied beside this project contains the complete release folder. Extract it before running the executable. A different Windows computer may need the Microsoft Visual C++ 2015–2022 x64 Redistributable.

## Demonstrate Table 7

1. Open a cashier shift, choose a demo employee, and enter the opening cash.
2. Navigate to Tables → Inside → Table 7.
3. Tap Espresso twice and Capucin once. Confirm order: **9.500 DT**.
4. Return to Tables. Table 7 is occupied. Switching areas preserves its bill.
5. Reopen Table 7, add one Espresso, and confirm the second round: **12.500 DT**.
6. Optionally choose a customer. Proceed to checkout.
7. Tap **Amount received** or **Enter cash on screen**. Use the number pad to enter **20 DT**, or tap the **20 DT** shortcut, then **Use amount**. Change is **7.500 DT**. Confirm payment.
8. The table becomes available. Find the sale in Orders / Bills, Dashboard, the customer's history, and the current shift.
9. Close and relaunch the application. All committed local data remains saved.

A customer earns 12 points for this sale when loyalty is enabled. Points are the final discounted total divided by 1000, rounded down per completed purchase. Draft/unpaid/cancelled bills earn no points. Repeated settlement of the same bill returns the existing sale without duplicating cash, history, or loyalty.

## Implemented

- Dashboard calculated from persisted sales and open bills, including today's totals and recent transactions.
- Inside Tables 1–10 and Terrace Tables 11–20; available, occupied, and payment-pending status; open time and current total.
- Visiting an empty table leaves it available. Adding the first product occupies it; draft products survive navigation. Removing the last unconfirmed product releases it. Back/sidebar navigation and startup remove unused empty editor sessions, including those saved by older versions. Confirmed cancellation history still requires explicit bill cancellation or settlement.
- Shared table bills, saved drafts, multiple confirmed ordering rounds, notes, quantities, draft removal, explicit confirmed-line cancellation with a reason, full bill inspection, bill cancellation history, and moves to available tables across areas.
- Searchable product catalog and touch-friendly ordering cards. Historical lines preserve their original product names and prices when the catalog changes.
- Counter Quick Sale with the same catalog and saved counter draft.
- Cash checkout with exact change and insufficient-cash protection, manual simulated card confirmation, optional fixed discounts, and atomic settlement.
- Touchscreen money entry: a large number pad, decimal millimes, backspace, clear, exact amount, and 20/50/100 DT shortcuts. The same number pad is available from the dialpad icon for opening/counted shift cash, discounts, and product prices. Entering an amount never settles the bill; payment still requires the confirmation button.
- Demo customers, phone numbers, completed purchase counts/spending, points balances, and purchase history.
- Shifts with demo employee selection, opening cash, cash/card transaction totals, expected cash, closing count, and recorded discrepancies. Open bills can be paid in a later shift.
- Cash out for owner withdrawals, business purchases, supplier payments, or another documented reason. Entries record the person taking the money, cashier, timestamp, details, and optional approval name. Cash in records returned change and drawer top-ups. Entries survive restart and remain visible in closed-shift history; sales and loyalty are unaffected.
- Business/station settings, default area, shared/assigned zone mode, areas/tables CRUD, categories CRUD, products add/edit/price/enable/disable, loyalty toggle, light/dark theme.
- Assigned zone mode filters the Tables view to this station's default area. Orders / Bills still provides access to every open local bill.
- Restrictions prevent removing/editing occupied tables, deleting areas with tables, deleting categories with products, or removing the last area/category.
- Settings and every order operation persist immediately. A failed write leaves the previous in-memory state intact and reports the error.

## Drawer cash movements

To record an owner taking **100.000 DT**, open **Cashier / Shifts → Cash out**, enter the amount using the number pad, select **Owner withdrawal** and **Owner**, then **Record cash out**. For a worker buying supplies, choose **Business purchase**, select the worker, and enter details and the approval name if useful. If the worker returns **25.000 DT** unused, use **Cash in / return → Returned change**. Expected drawer cash becomes opening cash + cash sales + cash added/returned − cash withdrawn. Cash withdrawals cannot exceed the expected drawer balance. Open a shift before recording cash movements.

Cash entries cannot be edited or silently deleted. If an entry needs correction, record the opposite movement using **Other cash in/out**, with a note explaining which entry is being corrected. Approval names are recorded notes; demo employees have no enforced permissions or authentication. Closing discrepancy compares counted cash with the adjusted expected cash.

## Storage and recovery

The default data directory is the Windows application-support directory supplied by `path_provider`, followed by `SmartPOS`. With the release metadata this is normally `%APPDATA%\tn.smartpos\Smart POS\SmartPOS`. Data is never written into bundled assets or the project source. Set `SMART_POS_DATA_DIR` to a separate writable folder if you need an isolated demonstration instance:

```powershell
$env:SMART_POS_DATA_DIR = 'C:\your\demo-data'
flutter run -d windows
```

Data is one versioned snapshot containing catalog, tables, customers, bills, sales, settings, and shifts. Each operation writes a temporary JSON file, flushes it, then renames it to a new immutable `state-000000000001.json` generation. The previous committed generation is retained. An interrupted temporary write cannot replace the last saved generation. Old-generation cleanup is best-effort after successful commit.

On startup, missing data seeds the demonstration once. Invalid JSON or malformed model data is skipped in favor of the previous readable generation, with a visible recovery warning. Damaged files are preserved. If all snapshots are invalid, startup shows an actionable storage error and does not silently seed over them. Recovery from an older snapshot can lose the newest operation, so inspect recovered data before continuing. There is no guarantee against disk hardware failure or manual file changes.

Only one running instance can hold the data folder's exclusive session lock. For backup, close the app and copy the entire data folder to a safe location. For restoration, close all instances and restore that folder. A stale `session.lock` file after process exit is harmless; the operating-system lock is released automatically.

## Source organization

```text
lib/
  main.dart                         startup, storage initialization, Riverpod scope
  core/
    navigation/app_shell.dart       desktop sidebar, header, navigation
    storage/pos_repository.dart     repository contract + JSON generations
    theme/pos_theme.dart            Material 3 light/dark theme
    utils/money.dart                exact money parsing/formatting
  models/pos_data.dart               typed catalog, bill, sale, shift, settings models
  features/
    dashboard/dashboard_screen.dart
    tables/tables_screen.dart
    orders/pos_controller.dart       UI-independent business operations
    orders/order_screen.dart         catalog + current order
    orders/history_screen.dart
    checkout/checkout_screen.dart
    customers/customers_screen.dart
    shifts/shifts_screen.dart
    shifts/cash_movements.dart        cash entry forms and audit details
    settings/settings_screen.dart
  shared/widgets/pos_widgets.dart    forms, error feedback, bill details, shared UI
  shared/widgets/money_keypad.dart   reusable touchscreen TND entry
test/
  pos_controller_test.dart           monetary, settlement, loyalty, shifts, persistence
  pos_widget_test.dart               workflows + desktop layouts in both themes
  money_keypad_test.dart             touch entry, correction, presets, layout checks
  cash_movements_test.dart           drawer ledger, retry protection, closing and restart
integration_test/
  windows_workflow_test.dart         compiled native workflow + separate restart stage
  windows_cash_movements_test.dart   touch withdrawals/returns + saved shift audit
windows/                            real Windows runner and build files
```

`PosController` owns domain operations and commits through the `PosRepository` interface. The Flutter UI calls those operations and observes them through Riverpod. Replace the repository/operation adapter when introducing a backend; the current application does not contain one. Production-grade server concurrency, access control, migrations, and fiscal rules would require separate work.

## Native verification

Use an **empty, isolated** test directory. The workflow stage refuses to overwrite existing test state. The restart stage runs in a fresh Windows process and reads the saved transactions, loyalty, settings, products, and tables:

```powershell
$env:SMART_POS_TEST_DIR = Join-Path $env:TEMP ('smart-pos-check-' + [guid]::NewGuid())
$env:SMART_POS_VERIFY_STAGE = 'workflow'
flutter test integration_test\windows_workflow_test.dart -d windows
$env:SMART_POS_VERIFY_STAGE = 'restart'
flutter test integration_test\windows_workflow_test.dart -d windows
```

Optional `SMART_POS_PREVIEW_DIR` saves screenshots from the actual rendered Windows app. The standard suite checks 1366×768, 1920×1080, and 1000×650 layouts with light and dark themes. Native tests additionally use the real Windows fonts and disk persistence.

For the drawer cash workflow, use another empty test directory and run `integration_test\windows_cash_movements_test.dart` with `SMART_POS_VERIFY_STAGE=workflow`, then `restart`. It checks a 100.000 DT owner withdrawal and 25.000 DT returned change against 200.000 DT opening cash, closes with 125.000 DT counted, and reads the cash audit after a fresh process restart.

## Deliberately unavailable / limitations

- Multiple bills preference is saved and clearly labeled **Coming later**. Every table still has one shared bill; no splitting or partial settlement.
- One local station/data folder at a time. Shared/assigned mode is a local navigation setting, not multi-device synchronization or employee authorization.
- Windows only in this delivery. Android has not been generated or validated.
- Demo customers and employees; no authentication, customer creation, SMS, marketing, redemption, or real payment processing.
- No receipt printing, kitchen tickets, hardware, fiscal integration, tax engine, refunds, or certified accounting.
- JSON snapshots are suitable for a small local demonstration, not large production transaction volumes. Payments and data are not encrypted or tamper-proof. Back up the folder.

**This application is a local prototype, not a production-certified fiscal cash register. No Tunisian regulatory compliance is claimed.**
