# Medical Shop Collection Manager — Flutter

A Flutter/Dart port of the Flask + SQLite web app. It runs **fully offline** on Android, iOS,
Windows, macOS and Linux with a local SQLite database (sqflite).

## Quick Start

### 1. Start the Backend (Connects securely to MongoDB Atlas)
The Flutter app securely persists and syncs data to MongoDB Atlas through the Node.js Express backend API:
```bash
cd server
cp .env.example .env     # Copy environment file
# Edit .env and paste your MongoDB Atlas connection string:
# MONGODB_URI=mongodb+srv://<username>:<password>@<cluster-url>/medical_shop?retryWrites=true&w=majority
npm install
npm start
```
The server runs on `http://localhost:5000` (health check: `http://localhost:5000/health`).

### 2. Run the Flutter App
In the root directory:
```bash
flutter pub get
flutter run
```
*Note for Android Emulator:* The app automatically targets `http://10.0.2.2:5000/api` on Android emulators and `http://localhost:5000/api` on desktop and web. A custom base URL can also be passed at build/run time:
```bash
flutter run --dart-define=API_BASE_URL=http://your-server-ip:5000/api
```

### 3. Run Tests
```bash
flutter test
```

On the **first launch** the sign-in screen asks you to create the admin account (username ≥ 3 and
password ≥ 8 characters). Passwords are stored as salted SHA-256 hashes; 5 failed sign-ins lock
sign-in for 5 minutes.

Android: set `minSdkVersion 21` or higher (default). Printing and sharing need no extra permissions.

## What was ported (Flask → Flutter)
| Flask | Flutter |
|---|---|
| `models.py` (+ CHECK / UNIQUE / NOCASE / AUTOINCREMENT) | `lib/data/database.dart` (same schema) and `models.dart` |
| `services.py` (all totals via SQL) | `lib/data/repository.dart` |
| `utils.py` (paise, ₹ Indian grouping, CSV safety) | `lib/core/money.dart`, `dates.dart`, `Report.cell` |
| login / dashboard | `login_screen.dart`, `dashboard_screen.dart` |
| add / edit collection, history, receipt | `collection_form.dart`, `collection_history.dart`, `receipt_screen.dart` (PDF print) |
| collection analysis, daily money | `analysis_screen.dart`, `daily_money_screen.dart` |
| expenses + categories | `expenses_screen.dart` |
| 6 reports + CSV export | `reports_screen.dart`, `report_export.dart` |
| admin shops, backup / restore, seed-sample | `shops_screen.dart`, `AppDatabase.backup/restore`, `Repository.seedSample` |
| Chart.js | fl_chart (`widgets/charts.dart`) |

## Business rules kept
- Money is stored as **integer paise**; totals are always calculated live from saved rows, so edits and deletes refresh every screen (`AppState.revision`).
- `total = cash + gpay + cheque` (database CHECK constraint). At least one amount must be > 0; negative or invalid amounts are rejected.
- Receipt numbers are unique (case-insensitive) and never reused after a delete (`RC-000001` style from SQLite's AUTOINCREMENT counter).
- Expenses are deducted only from the combined daily total: `Remaining = (Cash + GPay + Cheque) − Expenses`.
- Inactive shops stay in history and reports; a shop with collections cannot be deleted, only deactivated.
- Date filters use the collection / expense date. The save button locks while saving.
- CSV exports use the same filters as the screen, include a UTF-8 BOM for Excel and neutralise formula injection.

## Differences from the web version
- Backups are saved to the app documents folder (`medical_shop_backups`) and opened in the share sheet, so you can send them to Drive / WhatsApp / e-mail. Restore picks a `.db` file and saves the current data as a safety backup first.
- Receipts print / save as PDF through the system print dialog (`printing` package).
- The data lives on the device. There is no server, so no CSRF or session cookies are needed.
