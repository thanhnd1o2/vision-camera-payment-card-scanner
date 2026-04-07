export function normalizePan(value: string | null | undefined): string {
  if (!value) {
    return '';
  }

  return value.replace(/[^\d]/g, '');
}

export function getLast4(pan: string | null | undefined): string | undefined {
  const normalizedPan = normalizePan(pan);

  if (normalizedPan.length < 4) {
    return undefined;
  }

  return normalizedPan.slice(-4);
}
