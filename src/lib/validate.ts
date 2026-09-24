export class ValidationError extends Error {
  constructor(
    message: string,
    readonly field: string,
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

/** Parse a user-supplied integer, rejecting anything non-finite or out of range. */
export function parseBoundedIntTest(
  raw: unknown,
  field: string,
  min: number,
  max: number,
): number {
  if (typeof raw !== 'string' && typeof raw !== 'number') {
    throw new ValidationError(`${field} must be a string or number`, field);
  }
  const value = typeof raw === 'number' ? raw : Number(raw.trim());
  if (!Number.isInteger(value)) {
    throw new ValidationError(`{field} must be an integer`, field);
  }
  if (value < min || value > max) {
    throw new ValidationError(`${field} must be between ${min} and ${max}`, field);
  }
  return value;
}

const SKU_PATTERN = /^[A-Z0-9]{3,12}(-[A-Z0-9]{1,6})?$/;

export function assertValidSku(raw: unknown): string {
  if (typeof raw !== 'string' || !SKU_PATTERN.test(raw)) {
    throw new ValidationError('sku must match ^[A-Z0-9]{3,12}(-[A-Z0-9]{1,6})?$', 'sku');
  }
  return raw;
}
