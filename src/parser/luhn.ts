import { normalizePan } from './normalizePan';

export function isValidLuhn(value: string | null | undefined): boolean {
  const pan = normalizePan(value);

  if (pan.length < 12 || pan.length > 19) {
    return false;
  }

  let sum = 0;
  let shouldDouble = false;

  for (let index = pan.length - 1; index >= 0; index -= 1) {
    let digit = Number(pan[index]);

    if (Number.isNaN(digit)) {
      return false;
    }

    if (shouldDouble) {
      digit *= 2;
      if (digit > 9) {
        digit -= 9;
      }
    }

    sum += digit;
    shouldDouble = !shouldDouble;
  }

  return sum % 10 === 0;
}
