const express = require('express');
const cors = require('cors');
require('dotenv').config();

const connectDB = require('./db');
const shopsRouter = require('./routes/shops');
const collectionsRouter = require('./routes/collections');
const expensesRouter = require('./routes/expenses');
const reportsRouter = require('./routes/reports');
const syncRouter = require('./routes/sync');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Request logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Health check endpoint (public, used by uptime monitors and hosting platforms)
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Oscar Pharma Medical Shop Manager Backend',
    timestamp: new Date().toISOString(),
  });
});

// API Key Authentication Middleware
const REQUIRED_API_KEY = process.env.API_KEY;
const protectedPaths = [
  '/api',
  '/shops',
  '/collections',
  '/expenses',
  '/reports',
  '/sync',
];
app.use(protectedPaths, (req, res, next) => {
  if (!REQUIRED_API_KEY) {
    // If no API_KEY configured on server, allow for backward compatibility/local test
    return next();
  }
  const clientKey = req.headers['x-api-key'] || (req.headers['authorization'] || '').replace(/^Bearer\s+/i, '');
  if (!clientKey || clientKey !== REQUIRED_API_KEY) {
    return res.status(401).json({ error: 'Unauthorized: Invalid or missing API key' });
  }
  next();
});

// API Routes (mounted on both /api/resource and /resource for client compatibility)
app.use(['/api/shops', '/shops'], shopsRouter);
app.use(['/api/collections', '/collections'], collectionsRouter);
app.use(['/api/expenses', '/expenses'], expensesRouter);
app.use(['/api/reports', '/reports'], reportsRouter);
app.use(['/api/sync', '/sync'], syncRouter);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({ error: `Not Found - ${req.method} ${req.originalUrl}` });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('[Error]', err);
  res.status(500).json({ error: err.message || 'Internal Server Error' });
});

// Start Server & Connect MongoDB
async function start() {
  await connectDB();
  app.listen(PORT, () => {
    console.log(`🚀 Oscar Pharma Backend server running on: http://localhost:${PORT}`);
    console.log(`   Health check: http://localhost:${PORT}/health`);
  });
}

start();
