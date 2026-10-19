# Medical Shop Collection Manager — Flutter

A Flutter/Dart port of the Flask + SQLite web app. It runs **fully offline** on Android, iOS,
Windows, macOS and Linux with a local SQLite database (sqflite).

## Cloud Architecture & Multi-Device Sync

The Flutter application stores all data permanently in **MongoDB Atlas** via an online hosted Node.js Express backend. It does **not** require your laptop to run or host anything once deployed.

```
┌────────────────────────┐      ┌────────────────────────┐
│  Device A (Phone/Web)  │      │  Device B (Laptop/Tab) │
└───────────┬────────────┘      └───────────┬────────────┘
            │   REST API + API Key          │   REST API + API Key
            └───────────────┬───────────────┘
                            ▼
              ┌───────────────────────────┐
              │ Hosted Backend API        │
              │ (Render / Railway / Cloud)│
              └─────────────┬─────────────┘
                            ▼
              ┌───────────────────────────┐
              │   MongoDB Atlas Database  │
              └───────────────────────────┘
```

- **Online Saves:** Confirmed in the app only after the hosted backend saves them to MongoDB Atlas.
- **Offline Durability:** When offline, changes are queued in a durable local SQLite table (`sync_queue`) and marked with an amber "Waiting to sync" badge.
- **Auto Sync & Retry:** The background sync manager automatically retries pending changes when connectivity returns.
- **Multi-Device Sync:** On app launch or refresh, latest records are pulled from Atlas so all devices stay in sync.

---

## 1. Deploy the Backend Online (Render.com - Free & No Laptop Needed)

Deploy the backend to Render in a few clicks:

1. Push your repository to your GitHub account:
   ```bash
   git push origin main
   ```
2. Log in to **[dashboard.render.com](https://dashboard.render.com/)**.
3. Click **New +** > **Web Service**.
4. Connect your GitHub repository (`AjithBromex/medical_shop`).
5. Configure the service:
   - **Name:** `medical-shop-api` (or your preferred name)
   - **Root Directory:** `server`
   - **Environment:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
6. Under **Environment Variables**, add:
   - `MONGODB_URI`: Your MongoDB Atlas connection string (e.g. `mongodb+srv://<user>:<password>@<cluster>.mongodb.net/medical_shop?retryWrites=true&w=majority`)
   - `API_KEY`: A strong secret key of your choice (e.g. `my_secret_token_123`)
7. Click **Deploy Web Service**.
8. Once deployed, copy your public URL (e.g., `https://medical-shop-api.onrender.com`).
   Your API endpoint is: `https://medical-shop-api.onrender.com/api`.

---

## 2. Configure & Run the Flutter App

You can connect any phone, tablet, or PC to your online backend:

### Option A: In-App Configuration (Easiest - No Rebuild Needed)
1. Launch the app on your phone, tablet, or PC.
2. Tap the **Cloud icon** in the top bar (or go to **Admin - Medical Shops** > **Cloud Server Settings**).
3. Enter your hosted backend API URL (e.g., `https://medical-shop-api.onrender.com/api`) and your `API_KEY`.
4. Tap **Save & Connect**. Your app immediately links to your cloud database!

### Option B: Build with Compile-time Flags
```bash
flutter run --dart-define=API_BASE_URL=https://medical-shop-api.onrender.com/api --dart-define=API_KEY=my_secret_token_123
```

To build a release APK for your Android phone:
```bash
flutter build apk --dart-define=API_BASE_URL=https://medical-shop-api.onrender.com/api --dart-define=API_KEY=my_secret_token_123
```

---

## 3. Run Tests
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
