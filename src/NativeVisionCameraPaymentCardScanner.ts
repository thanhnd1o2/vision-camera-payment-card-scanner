import { TurboModuleRegistry, type TurboModule } from 'react-native';

export type NativeCardBrand = 'visa' | 'mastercard' | 'amex' | 'unknown';

export type NativeScanCardOptions = {
  scanExpiry?: boolean;
  restrictToBrands?: NativeCardBrand[];
};

export type NativeCardImageScanOptions = {
  imageUri: string;
  scanExpiry?: boolean;
  restrictToBrands?: NativeCardBrand[];
};

export type NativeCardScanResult = {
  pan?: string;
  last4?: string;
  expiryMonth?: number;
  expiryYear?: number;
  brand?: NativeCardBrand;
  cardholderName?: string;
  complete: boolean;
};

export interface Spec extends TurboModule {
  isSupported(): Promise<boolean>;
  scanCard(options?: NativeScanCardOptions): Promise<NativeCardScanResult>;
  scanCardImage(
    options: NativeCardImageScanOptions
  ): Promise<NativeCardScanResult>;
}

export default TurboModuleRegistry.get<Spec>('VisionCameraPaymentCardScanner');
