const express = require('express');
const router = express.Router();
const Collection = require('../models/Collection');
const Shop = require('../models/Shop');

// Helper to generate next receipt number
async function getNextReceiptNumber() {
  const latest = await Collection.findOne().sort({ createdAt: -1 });
  if (!latest || !latest.receiptNumber) return '#000001';
  const num = parseInt(latest.receiptNumber.replace(/\D/g, ''), 10);
  if (isNaN(num)) return '#000001';
  return '#' + String(num + 1).padStart(6, '0');
}

// GET collections with filters
router.get('/', async (req, res) => {
  try {
    const { dateFrom, dateTo, shopId, q, method, limit = 50, page = 1 } = req.query;
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

    if (shopId) {
      filter.shopId = shopId;
    }

    if (q) {
      const regex = new RegExp(q.trim(), 'i');
      filter.$or = [{ receiptNumber: regex }, { shopName: regex }, { notes: regex }];
    }

    if (method === 'cash') filter.cash = { $gt: 0 };
    if (method === 'gpay') filter.gpay = { $gt: 0 };
    if (method === 'cheque') filter.cheque = { $gt: 0 };

    const isAll = req.query.all === 'true' || limit === '0' || parseInt(limit, 10) >= 100000;
    const totalCount = await Collection.countDocuments(filter);
    const query = Collection.find(filter).sort({ date: -1, createdAt: -1 });
    if (!isAll) {
      const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);
      query.skip(skip).limit(parseInt(limit, 10));
    }
    const collections = await query;

    // Calculate totals for the filtered set
    const agg = await Collection.aggregate([
      { $match: filter },
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
    ]);

    const totals = agg[0] || { cash: 0, gpay: 0, cheque: 0, total: 0, count: 0 };

    res.json({
      rows: collections,
      totals,
      totalCount,
      page: parseInt(page, 10),
      totalPages: Math.ceil(totalCount / parseInt(limit, 10)) || 1,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET single collection
router.get('/:id', async (req, res) => {
  try {
    const collection = await Collection.findById(req.params.id);
    if (!collection) return res.status(404).json({ error: 'Collection not found' });
    res.json(collection);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// CREATE collection
router.post('/', async (req, res) => {
  try {
    let { receiptNumber, shopId, shopName, date, cash = 0, gpay = 0, cheque = 0, notes } = req.body;

    if (!shopId && !shopName) return res.status(400).json({ error: 'Medical shop is required' });
    if (!date) return res.status(400).json({ error: 'Collection date is required' });

    if (!shopName) {
      const shop = await Shop.findById(shopId);
      if (shop) {
        shopName = shop.name;
      } else {
        shopName = `Shop #${shopId}`;
      }
    }

    if (!receiptNumber || !receiptNumber.trim()) {
      receiptNumber = await getNextReceiptNumber();
    } else {
      receiptNumber = receiptNumber.trim();
    }

    cash = Number(cash) || 0;
    gpay = Number(gpay) || 0;
    cheque = Number(cheque) || 0;
    const total = cash + gpay + cheque;

    if (total <= 0) {
      return res.status(400).json({ error: 'Total collection amount must be greater than zero' });
    }

    let collection = await Collection.findOne({ receiptNumber });
    if (collection) {
      if (shopId !== undefined) collection.shopId = shopId;
      if (shopName) collection.shopName = shopName;
      collection.date = new Date(date);
      collection.cash = cash;
      collection.gpay = gpay;
      collection.cheque = cheque;
      collection.total = total;
      if (notes !== undefined) collection.notes = notes;
      await collection.save();
      return res.status(200).json(collection);
    }

    collection = new Collection({
      receiptNumber,
      shopId,
      shopName,
      date: new Date(date),
      cash,
      gpay,
      cheque,
      total,
      notes: notes || '',
    });

    await collection.save();
    res.status(201).json(collection);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// UPDATE collection
router.put('/:id', async (req, res) => {
  try {
    const { receiptNumber, shopId, shopName, date, cash, gpay, cheque, notes } = req.body;
    const collection = await Collection.findById(req.params.id);
    if (!collection) return res.status(404).json({ error: 'Collection not found' });

    if (receiptNumber && receiptNumber.trim() !== collection.receiptNumber) {
      const existing = await Collection.findOne({ receiptNumber: receiptNumber.trim() });
      if (existing) {
        return res.status(400).json({ error: `Receipt number ${receiptNumber} already exists` });
      }
      collection.receiptNumber = receiptNumber.trim();
    }

    if (shopId) {
      collection.shopId = shopId;
      if (shopName) {
        collection.shopName = shopName;
      } else {
        const shop = await Shop.findById(shopId);
        if (shop) collection.shopName = shop.name;
      }
    }

    if (date) collection.date = new Date(date);
    if (cash !== undefined) collection.cash = Number(cash) || 0;
    if (gpay !== undefined) collection.gpay = Number(gpay) || 0;
    if (cheque !== undefined) collection.cheque = Number(cheque) || 0;
    if (notes !== undefined) collection.notes = notes;

    collection.total = collection.cash + collection.gpay + collection.cheque;

    await collection.save();
    res.json(collection);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE collection by receipt number
router.delete('/by-receipt/:receiptNumber', async (req, res) => {
  try {
    const { receiptNumber } = req.params;
    await Collection.findOneAndDelete({ receiptNumber: receiptNumber.trim() });
    res.json({ message: 'Collection deleted successfully', receiptNumber });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE collection
router.delete('/:id', async (req, res) => {
  try {
    const collection = await Collection.findByIdAndDelete(req.params.id);
    if (!collection) return res.status(404).json({ error: 'Collection not found' });
    res.json({ message: 'Collection deleted successfully', id: req.params.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
