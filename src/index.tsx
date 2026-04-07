import NativeVisionCameraPaymentCardScanner from './NativeVisionCameraPaymentCardScanner';

import {
  VisionCameraProxy,
  type Frame,
  type FrameProcessorPlugin,
} from 'react-native-vision-camera';
import type {
  CardImageScanOptions,
  CardScanResult,
  ScanCardOptions,
} from './types';

export type {
  CardBrand,
  CardImageScanOptions,
  CardScanResult,
  ScanCardOptions,
} from './types';
export { detectBrand } from './parser/detectBrand';
export { isValidLuhn } from './parser/luhn';
export { getLast4, normalizePan } from './parser/normalizePan';
export { parseExpiry } from './parser/parseExpiry';

type FrameProcessorPluginOptions = Parameters<FrameProcessorPlugin['call']>[1];

const EMPTY_SCAN_RESULT: CardScanResult = {
  complete: false,
};

const scanPaymentCardFrameProcessorPlugin =
  VisionCameraProxy.initFrameProcessorPlugin('scanPaymentCard', {});

export async function isSupported(): Promise<boolean> {
  return NativeVisionCameraPaymentCardScanner?.isSupported?.() ?? false;
}

export async function scanCard(
  options?: ScanCardOptions
): Promise<CardScanResult> {
  if (!NativeVisionCameraPaymentCardScanner?.scanCard) {
    return EMPTY_SCAN_RESULT;
  }

  return NativeVisionCameraPaymentCardScanner.scanCard(options);
}

export async function scanCardImage(
  options: CardImageScanOptions
): Promise<CardScanResult> {
  if (!NativeVisionCameraPaymentCardScanner?.scanCardImage) {
    return EMPTY_SCAN_RESULT;
  }

  return NativeVisionCameraPaymentCardScanner.scanCardImage(options);
}

export function scanPaymentCard(
  frame: Frame,
  options?: ScanCardOptions
): CardScanResult | null {
  'worklet';

  if (scanPaymentCardFrameProcessorPlugin == null) {
    throw new Error('Failed to load Frame Processor Plugin "scanPaymentCard"!');
  }

  const result = scanPaymentCardFrameProcessorPlugin.call(frame, {
    scanExpiry: options?.scanExpiry ?? true,
    restrictToBrands: options?.restrictToBrands,
  } as FrameProcessorPluginOptions) as CardScanResult | undefined;

  return result ?? null;
}
