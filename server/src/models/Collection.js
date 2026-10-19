const mongoose = require('mongoose');

const collectionSchema = new mongoose.Schema(
  {
    receiptNumber: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    shopId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Shop',
      required: true,
    },
    shopName: {
      type: String,
      required: true,
      trim: true,
    },
    date: {
      type: Date,
      required: true,
    },
    cash: {
      type: Number,
      default: 0,
    },
    gpay: {
      type: Number,
      default: 0,
    },
    cheque: {
      type: Number,
      default: 0,
    },
    total: {
      type: Number,
      default: 0,
    },
    notes: {
      type: String,
      default: '',
    },
  },
  {
    timestamps: true,
  }
);

collectionSchema.pre('save', function (next) {
  this.total = (this.cash || 0) + (this.gpay || 0) + (this.cheque || 0);
  next();
});

module.exports = mongoose.model('Collection', collectionSchema);
