const express = require('express');
const router = express.Router();
const Shop = require('../models/Shop');
const Collection = require('../models/Collection');
const Expense = require('../models/Expense');
const Category = require('../models/Category');

// GET all data from Atlas for initial load or app reopen
router.get('/all', async (req, res) => {
  try {
    const [shops, collections, expenses, categories] = await Promise.all([
      Shop.find().sort({ name: 1 }),
      Collection.find().sort({ date: 1, createdAt: 1 }),
      Expense.find().sort({ date: 1, createdAt: 1 }),
      Category.find().sort({ name: 1 }),
    ]);

    res.json({
      shops,
      collections,
      expenses,
      categories: categories.map((c) => c.name),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST push batch of local items to Atlas (two-way sync)
router.post('/push', async (req, res) => {
  try {
    const { shops = [], collections = [], expenses = [], categories = [] } = req.body;

    // 1. Sync shops
    for (const s of shops) {
      if (!s.name || !s.name.trim()) continue;
      await Shop.findOneAndUpdate(
        { name: s.name.trim() },
        {
          name: s.name.trim(),
          address: s.address || '',
          phone: s.phone || '',
          notes: s.notes || '',
          active: s.active !== undefined ? s.active : true,
        },
        { upsert: true }
      );
    }

    // 2. Sync categories
    for (const catName of categories) {
      if (!catName || !catName.trim()) continue;
      await Category.findOneAndUpdate(
        { name: catName.trim() },
        { name: catName.trim() },
        { upsert: true }
      );
    }

    // 3. Sync collections
    for (const c of collections) {
      if (!c.receiptNumber || !c.receiptNumber.trim()) continue;
      const cash = Number(c.cash) || 0;
      const gpay = Number(c.gpay) || 0;
      const cheque = Number(c.cheque) || 0;
      await Collection.findOneAndUpdate(
        { receiptNumber: c.receiptNumber.trim() },
        {
          receiptNumber: c.receiptNumber.trim(),
          shopId: c.shopId,
          shopName: c.shopName || '',
          date: new Date(c.date),
          cash,
          gpay,
          cheque,
          total: cash + gpay + cheque,
          notes: c.notes || '',
        },
        { upsert: true }
      );
    }

    // 4. Sync expenses
    for (const e of expenses) {
      const displayId = e.displayId ? e.displayId.trim() : null;
      if (!displayId) continue;
      const amount = Number(e.amount) || 0;
      if (e.category) {
        await Category.findOneAndUpdate(
          { name: e.category.trim() },
          { name: e.category.trim() },
          { upsert: true }
        );
      }
      await Expense.findOneAndUpdate(
        { displayId },
        {
          displayId,
          date: new Date(e.date),
          category: (e.category || 'Other').trim(),
          description: e.description || '',
          amount,
          notes: e.notes || '',
        },
        { upsert: true }
      );
    }

    res.json({ message: 'Sync push completed successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
