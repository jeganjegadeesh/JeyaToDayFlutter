# AJ Project — Flutter App

Cross-platform (Mobile + Windows) client for the AJ Retail Ice Cream Distribution Management
System, talking to the Laravel API in `../backend`.

## What's included

- `lib/config/api_config.dart` — set your backend base URL here
- `lib/models/*` — Dart models mirroring the API responses
- `lib/services/*` — thin REST clients (`ApiService` is the shared HTTP wrapper with the bearer
  token; everything else builds on it)
- `lib/providers/auth_provider.dart` — app-wide login/session state (Provider)
- `lib/widgets/stock_form_page.dart` + `stock_history_page.dart` — the shared multi-select
  give/return stock form & history list, reused by both modules
- `lib/widgets/bill_preview_card.dart` — the bill breakdown layout (spec 3.8), reused by admin
  bill preview/history and the retailer's own bill view
- `lib/screens/admin/*` — every Admin/Manager screen (Users, Products, Retailers, Give/Return
  Stock, Cash Payment, Bill Generate, Reports, Cash Report, Raw Materials, Expenses, Retailer
  Loans, Company Setup)
- `lib/screens/retailer/*` — every retailer-only, read-only screen
- `lib/screens/common/*` — Dashboard shells (role-aware), Settings, Profile

## Setup

This repo ships only the `lib/` source + `pubspec.yaml` (no generated `android/`, `ios/`,
`windows/` platform folders). To run it:

```bash
flutter create . --project-name aj_project --org com.ajproject
# ^ generates the platform folders without touching lib/ or pubspec.yaml
flutter pub get
```

Then edit `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android emulator -> host machine
```

- Android emulator → `http://10.0.2.2:8000/api`
- iOS simulator / Windows desktop / web → `http://localhost:8000/api`
- Physical device → your machine's LAN IP, e.g. `http://192.168.1.20:8000/api`

Run it:

```bash
flutter run
```

## Login

Use the seeded admin from the backend:

```
Phone: 9999999999
Password: 123456
```

Any user/retailer created afterwards also defaults to password `123456` (spec section 2.2) —
prompt them to change it from Profile → Change Password.

## Navigation

- **Admin/Manager** get a drawer-based shell (`AdminManagerShell`) matching the "App Navigation
  Summary" table (spec 8.1). Menu items only visible to Admin (Users, Company Setup) are filtered
  by `AppUser.isAdmin`.
- **Retailer** gets a bottom-nav shell (`RetailerShell`) matching spec 8.2: Dashboard, Received,
  Returned, Paid, Bills, Reports — plus Settings/Profile in the app bar.

## Notes on scope / what to extend next

- PDF export/printing for bills: the `printing` + `pdf` packages are already in `pubspec.yaml`;
  wire a `Future<Uint8List> buildBillPdf(Bill bill, Company company)` and call
  `Printing.layoutPdf(...)` from `BillPreviewCard`'s "Print" action.
- Company logo upload uses `image_picker` (not yet wired into `CompanyScreen` — add an
  `IconButton` that picks an image and multipart-POSTs it, since the Laravel endpoint already
  accepts a `logo` file).
- Offline support / local caching is not implemented — every screen calls the API directly.
