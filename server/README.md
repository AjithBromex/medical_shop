# Oscar Pharma Backend (Node.js + Express + MongoDB Atlas)

A REST API backend connected to MongoDB Atlas for the Oscar Pharma Medical Shop Manager Flutter application.

## Prerequisites
- Node.js (v18+)
- npm

## Quick Start

1. **Navigate to the server directory**:
   ```bash
   cd server
   ```

2. **Verify `.env` configuration**:
   Ensure `server/.env` contains your MongoDB Atlas connection string:
   ```env
   PORT=5000
   MONGODB_URI=mongodb+srv://ajithnpofficial_db_user:XM508St1NO7NMdCu@medicalshop.p6sujar.mongodb.net/medical_shop?retryWrites=true&w=majority
   ```

3. **Install dependencies** (already done):
   ```bash
   npm install
   ```

4. **Start the server**:
   ```bash
   npm start
   ```
   Or for auto-reload during development:
   ```bash
   npm run dev
   ```

---

## Fixing MongoDB Atlas "bad auth : authentication failed"
If MongoDB Atlas returns `authentication failed` when connecting, check these two settings in your **[MongoDB Atlas Console](https://cloud.mongodb.com/)**:

1. **Database Access (User & Password)**:
   - Navigate to **Security** > **Database Access**.
   - Ensure the user `ajithnpofficial_db_user` exists.
   - Click **Edit** > **Edit Password** and ensure the password matches `XM508St1NO7NMdCu`.
   - Ensure the user has the **Read and write to any database** role.
2. **Network Access (IP Whitelist)**:
   - Navigate to **Security** > **Network Access**.
   - Click **Add IP Address**.
   - Choose **Add Current IP Address** or **Allow Access from Anywhere (`0.0.0.0/0`)** for development.

---

## API Endpoints

### Health Check
- `GET /health` - Verifies server status.

### Medical Shops (`/api/shops`)
- `GET /api/shops` - List all medical shops.
- `GET /api/shops/:id` - Get a single shop by ID.
- `POST /api/shops` - Create a new shop (`name`, `notes`, `phone`, `address`).
- `PUT /api/shops/:id` - Update shop details.
- `DELETE /api/shops/:id` - Delete shop (blocked if shop has active collections).

### Collections (`/api/collections`)
- `GET /api/collections` - List collections with filtering:
  - Query parameters: `dateFrom`, `dateTo`, `shopId`, `q`, `method` (`cash`/`gpay`/`cheque`), `page`, `limit`.
- `GET /api/collections/:id` - Get receipt details.
- `POST /api/collections` - Create new collection (auto-generates next receipt number `#000001` if omitted).
- `PUT /api/collections/:id` - Update an existing collection.
- `DELETE /api/collections/:id` - Delete a collection.

### Expenses & Categories (`/api/expenses`)
- `GET /api/expenses` - List expenses with date, category, and keyword filters.
- `POST /api/expenses` - Create expense (auto-generates `EXP-00001`).
- `PUT /api/expenses/:id` - Update expense.
- `DELETE /api/expenses/:id` - Delete expense.
- `GET /api/expenses/categories` - List all unique categories.
- `POST /api/expenses/categories` - Add a category.
- `DELETE /api/expenses/categories/:name` - Delete a category.

### Reports & Dashboard (`/api/reports`)
- `GET /api/reports/dashboard` - Returns total collection, cash, online, total expenses, remaining balance, and recent collections.
- `GET /api/reports/daily-money` - Day-by-day cash, online, expense, and balance breakdown.
- `GET /api/reports/:kind` - Formatted structured reports (`date_range`, `expenses`, etc.).
