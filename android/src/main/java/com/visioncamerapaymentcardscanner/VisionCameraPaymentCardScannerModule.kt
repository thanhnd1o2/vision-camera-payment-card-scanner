package com.visioncamerapaymentcardscanner

import com.facebook.react.bridge.ReactApplicationContext

class VisionCameraPaymentCardScannerModule(reactContext: ReactApplicationContext) :
  NativeVisionCameraPaymentCardScannerSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativeVisionCameraPaymentCardScannerSpec.NAME
  }
}
