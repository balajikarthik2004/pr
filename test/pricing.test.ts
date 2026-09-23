import { describe, expect, it } from 'vitest';
import {
  applyDiscount,
  formatCents,
  subtotalCents,
  totalCents,
  type LineItem,
} from '../src/lib/pricing.js';

const cart: LineItem[] = [
  { sku: 'ABC123', unitPriceCents: 1999, quantity: 2 },
  { sku: 'XYZ-9', unitPriceCents: 500, quantity: 3 },
];

describe('subtotalCents', () => {
  it('sums line items', () => {
    expect(subtotalCents(cart)).toBe(1999 * 2 + 500 * 3);
  });

  it('returns 0 for an empty cart', () => {
    expect(subtotalCents([])).toBe(0);
  });

  it('rejects a fractional price', () => {
    expect(() => subtotalCents([{ sku: 'A1B2C3', unitPriceCents: 1.5, quantity: 1 }])).toThrow(
      RangeError,
    );
  });

  it('rejects a negative quantity', () => {
    expect(() => subtotalCents([{ sku: 'A1B2C3', unitPriceCents: 100, quantity: -1 }])).toThrow(
      RangeError,
    );
  });
});

describe('applyDiscount', () => {
  it('applies a whole percentage', () => {
    expect(applyDiscount(1000, { code: 'TEN', percentOff: 10 })).toBe(900);
  });

  it('rounds half-up to the nearest cent', () => {
    expect(applyDiscount(1005, { code: 'HALF', percentOff: 50 })).toBe(502);
  });

  it('is a no-op at 0 percent', () => {
    expect(applyDiscount(1234, { code: 'NONE', percentOff: 0 })).toBe(1234);
  });

  it('rejects an out-of-range percentage', () => {
    expect(() => applyDiscount(100, { code: 'BAD', percentOff: 101 })).toThrow(RangeError);
    expect(() => applyDiscount(100, { code: 'BAD', percentOff: -1 })).toThrow(RangeError);
  });
});

describe('totalCents', () => {
  it('returns the subtotal when there is no discount', () => {
    expect(totalCents(cart)).toBe(subtotalCents(cart));
  });

  it('applies the discount when present', () => {
    expect(totalCents(cart, { code: 'TEN', percentOff: 10 })).toBe(4948);
  });
});

describe('formatCents', () => {
  it('pads the minor unit', () => {
    expect(formatCents(1905)).toBe('$19.05');
  });

  it('handles negatives', () => {
    expect(formatCents(-250)).toBe('-$2.50');
  });

  it('handles zero', () => {
    expect(formatCents(0)).toBe('$0.00');
  });
});
