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
   Ensure `server/.env` contains your MongoDB Atlas connection string and an optional `API_KEY` (copy from `.env.example`):
   ```env
   PORT=5000
   MONGODB_URI=mongodb+srv://<username>:<password>@<cluster-url>/medical_shop?retryWrites=true&w=majority
   API_KEY=your_secret_api_key_here
   ```

---

## Cloud Hosting (Render / Railway / Docker)

To run the backend online so your laptop does not need to host it:

### Deploy to Render.com (Recommended)
1. Push your repository to GitHub.
2. On Render.com, create a **New Web Service** pointing to your repo.
3. Set **Root Directory** to `server`.
4. Add environment variables:
   - `MONGODB_URI`: `<your-atlas-connection-string>`
   - `API_KEY`: `<your-secret-api-key>`
5. Deploy! Render will give you a public URL (e.g. `https://medical-shop-api.onrender.com`).
   Your API base URL is: `https://medical-shop-api.onrender.com/api`.

3. **Install dependencies**:
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

## MongoDB Atlas Configuration

If MongoDB Atlas returns `authentication failed` or connection timeout when connecting, verify your settings in the **[MongoDB Atlas Console](https://cloud.mongodb.com/)**:

1. **Database Access (User & Password)**:
   - Navigate to **Security** > **Database Access**.
   - Create or edit a database user with password authentication.
   - Assign the **Read and write to any database** built-in role.
   - If special characters are used in the password, ensure it is properly URL-encoded in the connection URI.
2. **Network Access (IP Access List)**:
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
