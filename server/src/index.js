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

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Oscar Pharma Medical Shop Manager Backend',
    timestamp: new Date().toISOString(),
  });
});

// API Routes
app.use('/api/shops', shopsRouter);
app.use('/api/collections', collectionsRouter);
app.use('/api/expenses', expensesRouter);
app.use('/api/reports', reportsRouter);
app.use('/api/sync', syncRouter);

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
