import { describe, expect, it } from 'vitest';
import { assertValidSku, parseBoundedInt, ValidationError } from '../src/lib/validate.js';

describe('parseBoundedInt', () => {
  it('accepts an in-range number', () => {
    expect(parseBoundedInt(5, 'qty', 1, 10)).toBe(5);
  });

  it('accepts a numeric string with surrounding whitespace', () => {
    expect(parseBoundedInt('  7 ', 'qty', 1, 10)).toBe(7);
  });

  it('rejects a non-integer', () => {
    expect(() => parseBoundedInt('2.5', 'qty', 1, 10)).toThrow(ValidationError);
  });

  it('rejects a value below the minimum', () => {
    expect(() => parseBoundedInt(0, 'qty', 1, 10)).toThrow(/between 1 and 10/);
  });

  it('rejects a value above the maximum', () => {
    expect(() => parseBoundedInt(11, 'qty', 1, 10)).toThrow(/between 1 and 10/);
  });

  it('rejects a wrong type', () => {
    expect(() => parseBoundedInt(null, 'qty', 1, 10)).toThrow(ValidationError);
  });

  it('carries the field name', () => {
    try {
      parseBoundedInt(null, 'qty', 1, 10);
    } catch (err) {
      expect((err as ValidationError).field).toBe('qty');
    }
  });
});

describe('assertValidSku', () => {
  it('accepts a plain sku', () => {
    expect(assertValidSku('ABC123')).toBe('ABC123');
  });

  it('accepts a suffixed sku', () => {
    expect(assertValidSku('ABC123-X1')).toBe('ABC123-X1');
  });

  it('rejects lowercase', () => {
    expect(() => assertValidSku('abc123')).toThrow(ValidationError);
  });

  it('rejects a non-string', () => {
    expect(() => assertValidSku(42)).toThrow(ValidationError);
  });
});
