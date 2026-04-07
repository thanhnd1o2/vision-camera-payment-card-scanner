import type { CardBrand } from '../types';
import { normalizePan } from './normalizePan';

export function detectBrand(value: string | null | undefined): CardBrand {
  const pan = normalizePan(value);

  if (/^4\d{12}(?:\d{3})?(?:\d{3})?$/.test(pan)) {
    return 'visa';
  }

  if (
    /^(5[1-5]\d{14}|2(?:2[2-9]\d{12}|[3-6]\d{13}|7(?:[01]\d{12}|20\d{12})))$/.test(
      pan
    )
  ) {
    return 'mastercard';
  }

  if (/^3[47]\d{13}$/.test(pan)) {
    return 'amex';
  }

  return 'unknown';
}
