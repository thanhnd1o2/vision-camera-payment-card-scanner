export type ParsedExpiry = {
  expiryMonth: number;
  expiryYear: number;
};

export function parseExpiry(
  value: string | null | undefined
): ParsedExpiry | undefined {
  if (!value) {
    return undefined;
  }

  const normalized = value.trim().replace(/\s+/g, '').replace(/-/g, '/');
  const match = normalized.match(/^(\d{2})\/(\d{2}|\d{4})$/);

  if (!match) {
    return undefined;
  }

  const monthPart = match[1];
  const yearPart = match[2];

  if (!monthPart || !yearPart) {
    return undefined;
  }

  const expiryMonth = Number(monthPart);

  if (!Number.isInteger(expiryMonth) || expiryMonth < 1 || expiryMonth > 12) {
    return undefined;
  }

  const rawYear = Number(yearPart);
  const expiryYear = yearPart.length === 2 ? 2000 + rawYear : rawYear;

  return {
    expiryMonth,
    expiryYear,
  };
}
