const express = require('express');
const router = express.Router();
const Shop = require('../models/Shop');
const Collection = require('../models/Collection');

// GET all shops
router.get('/', async (req, res) => {
  try {
    const shops = await Shop.find().sort({ name: 1 });
    res.json(shops);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET single shop
router.get('/:id', async (req, res) => {
  try {
    const shop = await Shop.findById(req.params.id);
    if (!shop) return res.status(404).json({ error: 'Shop not found' });
    res.json(shop);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// CREATE shop
router.post('/', async (req, res) => {
  try {
    const { name, notes, phone, address, active } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Shop name is required' });
    }
    const existing = await Shop.findOne({ name: name.trim() });
    if (existing) {
      return res.status(400).json({ error: 'A medical shop with this name already exists' });
    }
    const shop = new Shop({
      name: name.trim(),
      notes: notes || '',
      phone: phone || '',
      address: address || '',
      active: active !== undefined ? active : true,
    });
    await shop.save();
    res.status(201).json(shop);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// UPDATE shop
router.put('/:id', async (req, res) => {
  try {
    const { name, notes, phone, address, active } = req.body;
    const shop = await Shop.findById(req.params.id);
    if (!shop) return res.status(404).json({ error: 'Shop not found' });

    if (name && name.trim() !== shop.name) {
      const existing = await Shop.findOne({ name: name.trim() });
      if (existing) {
        return res.status(400).json({ error: 'A medical shop with this name already exists' });
      }
      shop.name = name.trim();
    }
    if (notes !== undefined) shop.notes = notes;
    if (phone !== undefined) shop.phone = phone;
    if (address !== undefined) shop.address = address;
    if (active !== undefined) shop.active = active;

    await shop.save();
    res.json(shop);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE shop
router.delete('/:id', async (req, res) => {
  try {
    const count = await Collection.countDocuments({ shopId: req.params.id });
    if (count > 0) {
      return res.status(400).json({
        error: `Cannot delete: Shop has ${count} recorded collection(s). Deactivate it instead.`,
      });
    }
    const shop = await Shop.findByIdAndDelete(req.params.id);
    if (!shop) return res.status(404).json({ error: 'Shop not found' });
    res.json({ message: 'Shop deleted successfully', id: req.params.id });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
