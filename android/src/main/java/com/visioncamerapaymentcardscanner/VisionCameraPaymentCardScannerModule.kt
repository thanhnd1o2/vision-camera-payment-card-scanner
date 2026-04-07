package com.visioncamerapaymentcardscanner

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap

class VisionCameraPaymentCardScannerModule(reactContext: ReactApplicationContext) :
  NativeVisionCameraPaymentCardScannerSpec(reactContext) {

  private val mlKitCardScanner: AndroidCardScanner = MlKitCardScanner(reactContext)

  override fun isSupported(promise: Promise) {
    promise.resolve(mlKitCardScanner.isSupported())
  }

  override fun scanCard(options: ReadableMap?, promise: Promise) {
    promise.reject(
      "E_SCAN_CARD_UNSUPPORTED",
      "Android scanCard() is not implemented for ML Kit option 2. Use scanCardImage() with a captured image instead."
    )
  }

  override fun scanCardImage(options: ReadableMap, promise: Promise) {
    mlKitCardScanner.scanCardImage(options, promise)
  }

  companion object {
    const val NAME = NativeVisionCameraPaymentCardScannerSpec.NAME
  }
}
