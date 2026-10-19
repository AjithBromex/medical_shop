const express = require('express');
const router = express.Router();
const Collection = require('../models/Collection');
const Expense = require('../models/Expense');
const Shop = require('../models/Shop');

function toISODate(d) {
  const dt = new Date(d);
  return dt.toISOString().split('T')[0];
}

// ------------------------------------------------------------- Dashboard
router.get('/dashboard', async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const [collAll, expAll, collToday, expToday, recent] = await Promise.all([
      Collection.aggregate([
        {
          $group: {
            _id: null,
            cash: { $sum: '$cash' },
            gpay: { $sum: '$gpay' },
            cheque: { $sum: '$cheque' },
            total: { $sum: '$total' },
            count: { $sum: 1 },
          },
        },
      ]),
      Expense.aggregate([{ $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } }]),
      Collection.aggregate([
        { $match: { date: { $gte: today, $lt: tomorrow } } },
        {
          $group: {
            _id: null,
            cash: { $sum: '$cash' },
            gpay: { $sum: '$gpay' },
            cheque: { $sum: '$cheque' },
            total: { $sum: '$total' },
            count: { $sum: 1 },
          },
        },
      ]),
      Expense.aggregate([
        { $match: { date: { $gte: today, $lt: tomorrow } } },
        { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
      Collection.find().sort({ date: -1, createdAt: -1 }).limit(10),
    ]);

    const totalColl = collAll[0] || { cash: 0, gpay: 0, cheque: 0, total: 0, count: 0 };
    const totalExp = expAll[0]?.total || 0;
    const todayColl = collToday[0] || { cash: 0, gpay: 0, cheque: 0, total: 0, count: 0 };
    const todayExp = expToday[0]?.total || 0;

    res.json({
      allTime: {
        ...totalColl,
        expenses: totalExp,
        remaining: totalColl.total - totalExp,
        remainingCash: totalColl.cash - totalExp,
      },
      today: {
        ...todayColl,
        expenses: todayExp,
        remaining: todayColl.total - todayExp,
        remainingCash: todayColl.cash - todayExp,
      },
      recentCollections: recent,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ------------------------------------------------------------- Daily Money
router.get('/daily-money', async (req, res) => {
  try {
    const { from, to } = req.query;
    const matchColl = {};
    const matchExp = {};
    if (from || to) {
      matchColl.date = {};
      matchExp.date = {};
      if (from) {
        matchColl.date.$gte = new Date(from);
        matchExp.date.$gte = new Date(from);
      }
      if (to) {
        const toDate = new Date(to);
        toDate.setHours(23, 59, 59, 999);
        matchColl.date.$lte = toDate;
        matchExp.date.$lte = toDate;
      }
    }

    const [collByDay, expByDay] = await Promise.all([
      Collection.aggregate([
        { $match: matchColl },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$date' } },
            cash: { $sum: '$cash' },
            gpay: { $sum: '$gpay' },
            cheque: { $sum: '$cheque' },
            total: { $sum: '$total' },
            count: { $sum: 1 },
          },
        },
      ]),
      Expense.aggregate([
        { $match: matchExp },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$date' } },
            expenses: { $sum: '$amount' },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    const daysMap = new Map();
    for (const c of collByDay) {
      daysMap.set(c._id, {
        date: c._id,
        cash: c.cash,
        gpay: c.gpay,
        cheque: c.cheque,
        total: c.total,
        expenses: 0,
      });
    }
    for (const e of expByDay) {
      const existing = daysMap.get(e._id) || {
        date: e._id,
        cash: 0,
        gpay: 0,
        cheque: 0,
        total: 0,
        expenses: 0,
      };
      existing.expenses = e.expenses;
      daysMap.set(e._id, existing);
    }

    const rows = Array.from(daysMap.values())
      .map((r) => ({
        ...r,
        remainingCash: r.cash - r.expenses,
        remaining: r.total - r.expenses,
      }))
      .sort((a, b) => b.date.localeCompare(a.date));

    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ------------------------------------------------------------- Reports (compatible with Flutter)
router.get('/:kind', async (req, res) => {
  try {
    const { kind } = req.params;
    const { dateFrom, dateTo, shopId, q, category } = req.query;

    const collFilter = {};
    if (dateFrom || dateTo) {
      collFilter.date = {};
      if (dateFrom) collFilter.date.$gte = new Date(dateFrom);
      if (dateTo) {
        const to = new Date(dateTo);
        to.setHours(23, 59, 59, 999);
        collFilter.date.$lte = to;
      }
    }
    if (shopId) collFilter.shopId = shopId;
    if (q) {
      const regex = new RegExp(q.trim(), 'i');
      collFilter.$or = [{ receiptNumber: regex }, { shopName: regex }, { notes: regex }];
    }

    let report = null;

    if (kind === 'date_range') {
      const collections = await Collection.find(collFilter).sort({ date: 1, createdAt: 1 });
      const headers = ['Receipt No', 'Date', 'Medical Shop', 'Cash', 'Gpay/cheque/CN', 'Total', 'Notes'];
      const rows = collections.map((c) => [
        c.receiptNumber,
        toISODate(c.date),
        c.shopName,
        c.cash,
        c.gpay + c.cheque,
        c.total,
        c.notes || '',
      ]);
      const totalCash = rows.reduce((s, r) => s + r[3], 0);
      const totalOnline = rows.reduce((s, r) => s + r[4], 0);
      const totalAmount = rows.reduce((s, r) => s + r[5], 0);
      const footer = ['Total', '', '', totalCash, totalOnline, totalAmount, ''];
      report = { kind, title: 'Date-range Collection Report', headers, rows, footer };
    } else if (kind === 'expenses') {
      const expFilter = {};
      if (dateFrom || dateTo) {
        expFilter.date = {};
        if (dateFrom) expFilter.date.$gte = new Date(dateFrom);
        if (dateTo) {
          const to = new Date(dateTo);
          to.setHours(23, 59, 59, 999);
          expFilter.date.$lte = to;
        }
      }
      if (category) expFilter.category = category;
      const expenses = await Expense.find(expFilter).sort({ date: 1, createdAt: 1 });
      const headers = ['Expense ID', 'Date', 'Category', 'Description', 'Amount', 'Notes'];
      const rows = expenses.map((e) => [
        e.displayId,
        toISODate(e.date),
        e.category,
        e.description,
        e.amount,
        e.notes || '',
      ]);
      const totalExp = rows.reduce((s, r) => s + r[4], 0);
      const footer = ['Total', '', '', '', totalExp, ''];
      report = { kind, title: 'Expense Report', headers, rows, footer };
    } else {
      // Fallback
      report = {
        kind,
        title: `${kind} Report`,
        headers: ['Status'],
        rows: [['Report type supported via direct queries']],
        footer: null,
      };
    }

    res.json(report);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
