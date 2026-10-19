const express = require('express');
const router = express.Router();
const Expense = require('../models/Expense');
const Category = require('../models/Category');

// Helper to generate next expense display ID
async function getNextExpenseId() {
  const latest = await Expense.findOne().sort({ createdAt: -1 });
  if (!latest || !latest.displayId) return 'EXP-00001';
  const num = parseInt(latest.displayId.replace(/\D/g, ''), 10);
  if (isNaN(num)) return 'EXP-00001';
  return 'EXP-' + String(num + 1).padStart(5, '0');
}

// ------------------------------------------------------------- Categories
router.get('/categories', async (req, res) => {
  try {
    const cats = await Category.find().sort({ name: 1 });
    res.json(cats.map((c) => c.name));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/categories', async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !name.trim()) return res.status(400).json({ error: 'Category name is required' });
    const existing = await Category.findOne({ name: name.trim() });
    if (existing) return res.status(400).json({ error: 'Category already exists' });
    const cat = new Category({ name: name.trim() });
    await cat.save();
    res.status(201).json(cat);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/categories/:name', async (req, res) => {
  try {
    const name = decodeURIComponent(req.params.name);
    const count = await Expense.countDocuments({ category: name });
    if (count > 0) {
      return res.status(400).json({
        error: `Cannot delete: Category is used by ${count} expense record(s).`,
      });
    }
    await Category.findOneAndDelete({ name });
    res.json({ message: 'Category deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ------------------------------------------------------------- Expenses
router.get('/', async (req, res) => {
  try {
    const { dateFrom, dateTo, category, q, limit = 50, page = 1 } = req.query;
    const filter = {};

    if (dateFrom || dateTo) {
      filter.date = {};
      if (dateFrom) filter.date.$gte = new Date(dateFrom);
      if (dateTo) {
        const to = new Date(dateTo);
        to.setHours(23, 59, 59, 999);
        filter.date.$lte = to;
      }
    }

    if (category) filter.category = category;

    if (q) {
      const regex = new RegExp(q.trim(), 'i');
      filter.$or = [{ description: regex }, { notes: regex }, { displayId: regex }];
    }

    const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);
    const totalCount = await Expense.countDocuments(filter);
    const expenses = await Expense.find(filter)
      .sort({ date: -1, createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit, 10));

    const totalAgg = await Expense.aggregate([
      { $match: filter },
      { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } },
    ]);

    const catAgg = await Expense.aggregate([
      { $match: filter },
      { $group: { _id: '$category', total: { $sum: '$amount' }, count: { $sum: 1 } } },
      { $sort: { total: -1 } },
    ]);

    res.json({
      rows: expenses,
      totalAmount: totalAgg[0]?.total || 0,
      totalCount,
      byCategory: catAgg.map((c) => ({ category: c._id, total: c.total, count: c.count })),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    let { displayId, date, category, description, amount = 0, notes } = req.body;
    if (!date) return res.status(400).json({ error: 'Date is required' });
    if (!category || !category.trim()) return res.status(400).json({ error: 'Category is required' });
    amount = Number(amount) || 0;
    if (amount <= 0) return res.status(400).json({ error: 'Amount must be greater than zero' });

    if (!displayId || !displayId.trim()) {
      displayId = await getNextExpenseId();
    }

    // Auto-create category if missing
    await Category.findOneAndUpdate(
      { name: category.trim() },
      { name: category.trim() },
      { upsert: true }
    );

    const expense = new Expense({
      displayId,
      date: new Date(date),
      category: category.trim(),
      description: description || '',
      amount,
      notes: notes || '',
    });

    await expense.save();
    res.status(201).json(expense);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const { date, category, description, amount, notes } = req.body;
    const expense = await Expense.findById(req.params.id);
    if (!expense) return res.status(404).json({ error: 'Expense not found' });

    if (date) expense.date = new Date(date);
    if (category) {
      expense.category = category.trim();
      await Category.findOneAndUpdate(
        { name: category.trim() },
        { name: category.trim() },
        { upsert: true }
      );
    }
    if (description !== undefined) expense.description = description;
    if (amount !== undefined) expense.amount = Number(amount) || 0;
    if (notes !== undefined) expense.notes = notes;

    await expense.save();
    res.json(expense);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const expense = await Expense.findByIdAndDelete(req.params.id);
    if (!expense) return res.status(404).json({ error: 'Expense not found' });
    res.json({ message: 'Expense deleted successfully', id: req.params.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
