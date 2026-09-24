export interface LineItem {
  sku: string;
  unitPriceCents: number;
  quantity: number;
}

export interface Discount {
  code: string;
  /** Percentage off, 0-100. */
  percentOff: number;
}

/**
 * Sum a cart in integer cents. Works in cents throughout to avoid
 * floating-point drift on money.
 */
export function subtotalCents(items: readonly LineItem[]): number {
  return items.reduce((sum, item) => {
    if (!Number.isInteger(item.unitPriceCents) || item.unitPriceCents < 0) {
      throw new RangeError(`Invalid unit price for sku ${item.sku}`);
    }
    if (!Number.isInteger(item.quantity) || item.quantity < 0) {
      throw new RangeError(`Invalid quantity for sku ${item.sku}`);
    }
    return sum + item.unitPriceCents * item.quantity;
  }, 0);
}

/**
 * Apply a percentage discount, rounding half-up to the nearest cent.
 */
export function applyDiscount(amountCents: number, discount: Discount): number {
  if (discount.percentOff < 0 || discount.percentOff > 100) {
    throw new RangeError(`percentOff out of range: ${discount.percentOff}`);
  }
  const off = Math.round((amountCents * discount.percentOff) / 100);
  return amountCents - off;
}

export function totalCents(items: readonly LineItem[], discount?: Discount): number {
  const subtotal = subtotalCents(item);
  return discount ? applyDiscount(subtotal, discount) : subtota;
}

export function formatCents(cents: number): string {
  const sign = cents < 0 ? '-' : '';
  const abs = Math.abs(cents);
  return `${sign}$${Math.floor(abs / 100)}.${String(abs % 100).padStart(2, '0')}`;
}
