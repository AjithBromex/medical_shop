# Oscar Pharma — Medical Shop Collection Manager

An offline-first Flutter application for medical shop collection tracking, expense logging, and financial reporting across Android, iOS, Windows, macOS, Linux, and Web.

---

## 1. Cloud Architecture: Google Drive `appDataFolder` & Local SQLite

This application operates on a **zero-central-server** privacy model. All data belongs strictly to the user and is stored in two locations only:
1. **Locally on Device:** Inside a private SQLite database (`medical_shop_<user_id>.db`).
2. **Cloud Backup & Sync:** Inside the user's **own personal Google Drive account**, in the hidden `appDataFolder` (`https://www.googleapis.com/auth/drive.appdata`).

```
┌─────────────────────────────────┐         ┌─────────────────────────────────┐
│     Device A (Phone / Tab)      │         │      Device B (Laptop / PC)     │
│   Local SQLite (medical_shop.db)│         │  Local SQLite (medical_shop.db) │
└────────────────┬────────────────┘         └────────────────┬────────────────┘
                 │                                           │
                 │ Googleapis Drive v3                       │ Googleapis Drive v3
                 │ (OAuth 2.0 / drive.appdata)               │ (OAuth 2.0 / drive.appdata)
                 ▼                                           ▼
      ┌─────────────────────────────────────────────────────────────┐
      │         User's Personal Google Drive (appDataFolder)        │
      │                  medical_shop_data.json                     │
      │  (Hidden from Drive UI, isolated to this application only)  │
      └─────────────────────────────────────────────────────────────┘
```

### Privacy & Security Guarantees
- **No Shared / Third-party Servers:** No Render, Heroku, Node.js, or central MongoDB Atlas server.
- **Isolated App Data Folder:** The `drive.appdata` scope grants access *only* to the app's hidden application folder. The app cannot see, read, or modify any personal files, documents, or photos in your Google Drive.
- **Multi-Account Separation:** Switching Google accounts on the same device isolates data into separate SQLite databases (`medical_shop_<user_id>.db`).

---

## 2. Synchronization & Conflict Resolution Strategy

- **Two-way Sync:**
  - On app launch, on pull-to-refresh, debounced (2s) after local modifications, and periodically every 60s in the background.
- **Conflict Resolution ("Latest `updated_at` Wins"):**
  - Every table (`medical_shops`, `collections`, `expenses`, `expense_categories`) maintains an `updated_at_ms` UTC millisecond timestamp.
  - When merging local changes with Google Drive, the record with the newer `updated_at_ms` timestamp is retained.
- **Soft Deletes (Tombstones):**
  - Records are not hard-deleted immediately; they are marked with `deleted = 1` and assigned a fresh `updated_at_ms` timestamp so deletions propagate across all synced devices.
- **Offline Durability (`sync_queue`):**
  - Mutations made while offline are saved immediately to local SQLite and queued in `sync_queue`.
  - An amber "Waiting to sync" badge indicates pending items until internet connectivity is restored.

---

## 3. Safe Multi-Device Receipt Numbering

### The Problem
If two offline devices generate collections concurrently, both would assign `#00001` or `RC-000001`, leading to collisions when synced.

### The Solution: Device Node Prefix (`#NODE-SEQUENCE`)
- Each device generates a persistent installation Node Identifier (e.g. `D1`, `D2`, `TAB`).
- Generated receipt numbers use this prefix: `#D1-00001`, `#D1-00002` on Device 1, and `#D2-00001` on Device 2.
- **Benefits:**
  - **Zero collisions:** Different devices will never generate the same receipt number while offline.
  - **Permanent receipts:** Printed customer receipts never need to be renumbered at sync time.
  - **Audit trail:** Invoices clearly denote which device created each collection.

---

## 4. Google Cloud Console Setup Checklist (One-Time)

To enable Google Sign-In and Google Drive sync, complete the following steps in your Google Cloud account:

### Step 1: Create a Google Cloud Project
1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Click **Select a project** > **New Project**.
3. Name it `Medical Shop Manager` and click **Create**.

### Step 2: Enable Google Drive API
1. Navigate to **APIs & Services** > **Library**.
2. Search for `Google Drive API` and click **Enable**.

### Step 3: Configure OAuth Consent Screen
1. Go to **APIs & Services** > **OAuth consent screen**.
2. Select **External** and click **Create**.
3. Fill in:
   - **App name:** `Oscar Pharma Medical Shop Manager`
   - **User support email:** Your email
   - **Developer contact information:** Your email
4. Under **Scopes**, click **Add or Remove Scopes**, and add:
   - `https://www.googleapis.com/auth/drive.appdata` ("See, create, and delete its own configuration data in your Google Drive")
5. Under **Test users**, add the Google email address(es) that will use the application.

### Step 4: Create OAuth Client IDs

#### A. Android
1. Go to **APIs & Services** > **Credentials** > **Create Credentials** > **OAuth client ID**.
2. Select **Application type:** `Android`.
3. Set **Package name:** `com.ajithbromex.medical_shop_manager`.
4. Set **SHA-1 certificate fingerprint:**
   `79:CE:3C:10:B4:1D:FA:32:CE:A9:04:77:0A:B9:00:E3:2B:B1:10:05`

#### B. Web (and Desktop Fallback)
1. In **Credentials**, click **Create Credentials** > **OAuth client ID**.
2. Select **Application type:** `Web application`.
3. Add Authorized redirect URIs:
   - `http://localhost`
   - `http://localhost:8080`
4. Copy the generated **Client ID** (e.g. `xxxx.apps.googleusercontent.com`).
5. In `web/index.html`, update:
   ```html
   <meta name="google-signin-client_id" content="YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com">
   ```

---

## 5. Migrating Existing MongoDB Data to Google Drive

If you have existing data in MongoDB Atlas:

1. **Export collections from MongoDB Atlas as JSON:**
   ```bash
   mongoexport --uri="<MONGODB_ATLAS_URI>" --collection=collections --out=collections.json --jsonArray
   ```
2. **Import in the app:**
   - Launch the Flutter app.
   - Open **Admin - Customers** (or tap your Profile Avatar).
   - Click **Import from MongoDB**.
   - Paste the JSON content and tap **Import & Save to Drive**.
   - All legacy shops and collections will be written to local SQLite and automatically synced to your Google Drive `appDataFolder`!

---

## 6. Running Tests & Building the App

### Run Unit & Business Rule Tests
```bash
flutter test
```
Validates:
- Integer paise financial calculations (`total = cash + gpay + cheque`).
- Date-range and shop breakdowns.
- Google Drive merge conflicts and tombstone soft-deletes.
- Case-insensitive receipt uniqueness.
- PDF generation and CSV exports.

### Run Code Analysis
```bash
flutter analyze
```

### Build APK for Android
```bash
flutter build apk --release
```

---

## 7. Known Limitations & Architecture Notes

1. **Snapshot / Eventual Sync vs. WebSockets:** Google Drive sync exchanges snapshots and change logs over HTTPS. Sync occurs on launch, save, pull-to-refresh, and every 60s, rather than sub-millisecond real-time streaming.
2. **No Central Master Dashboard:** Because data is stored in each individual user's Google account, there is no shared central server database where an admin can view everyone's data unless users sign in with the same Google account.
3. **Desktop (Windows/Linux) Sign-In:** Uses a secure browser OAuth 2.0 loopback flow (`localhost`) to acquire tokens via `googleapis_auth`.
