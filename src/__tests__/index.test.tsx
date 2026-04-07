import { beforeEach, describe, expect, it, jest } from '@jest/globals';

const mockNativeModule = {
  isSupported: jest.fn<() => Promise<boolean>>(),
  scanCard: jest.fn<(options?: unknown) => Promise<any>>(),
};

jest.mock('../NativeVisionCameraPaymentCardScanner', () => ({
  __esModule: true,
  default: mockNativeModule,
}));

import {
  detectBrand,
  getLast4,
  isSupported,
  isValidLuhn,
  normalizePan,
  parseExpiry,
  scanCard,
} from '../index';

describe('parser utilities', () => {
  it('normalizes PAN values', () => {
    expect(normalizePan('4111 1111-1111 1111')).toBe('4111111111111111');
  });

  it('extracts the last four digits', () => {
    expect(getLast4('4111 1111 1111 1234')).toBe('1234');
    expect(getLast4('123')).toBeUndefined();
  });

  it('validates PAN values with Luhn', () => {
    expect(isValidLuhn('4111 1111 1111 1111')).toBe(true);
    expect(isValidLuhn('4111 1111 1111 1112')).toBe(false);
  });

  it('detects supported brands', () => {
    expect(detectBrand('4111111111111111')).toBe('visa');
    expect(detectBrand('5555555555554444')).toBe('mastercard');
    expect(detectBrand('378282246310005')).toBe('amex');
    expect(detectBrand('1234567890123456')).toBe('unknown');
  });

  it('parses expiry dates', () => {
    expect(parseExpiry('04/29')).toEqual({ expiryMonth: 4, expiryYear: 2029 });
    expect(parseExpiry('04/2029')).toEqual({
      expiryMonth: 4,
      expiryYear: 2029,
    });
    expect(parseExpiry('13/29')).toBeUndefined();
  });
});

describe('public API behavior', () => {
  beforeEach(() => {
    mockNativeModule.isSupported.mockReset();
    mockNativeModule.scanCard.mockReset();
  });

  it('delegates support checks to the native module', async () => {
    mockNativeModule.isSupported.mockResolvedValue(true);

    await expect(isSupported()).resolves.toBe(true);
  });

  it('delegates card scanning to the native module', async () => {
    const result = {
      pan: '4111111111111111',
      last4: '1111',
      expiryMonth: 4,
      expiryYear: 2029,
      brand: 'visa' as const,
      complete: true,
    };

    mockNativeModule.scanCard.mockResolvedValue(result);

    await expect(scanCard({ scanExpiry: true })).resolves.toEqual(result);
    expect(mockNativeModule.scanCard).toHaveBeenCalledWith({
      scanExpiry: true,
    });
  });
});
