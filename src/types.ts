export type CardBrand = 'visa' | 'mastercard' | 'amex' | 'unknown';

export type CardScanResult = {
  pan?: string;
  last4?: string;
  expiryMonth?: number;
  expiryYear?: number;
  brand?: CardBrand;
  cardholderName?: string;
  complete: boolean;
};

export type ScanCardOptions = {
  scanExpiry?: boolean;
  restrictToBrands?: CardBrand[];
};

export type CardImageScanOptions = ScanCardOptions & {
  imageUri: string;
};
