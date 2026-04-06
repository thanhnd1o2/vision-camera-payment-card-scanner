package com.visioncamerapaymentcardscanner

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import java.util.HashMap

class VisionCameraPaymentCardScannerPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == VisionCameraPaymentCardScannerModule.NAME) {
      VisionCameraPaymentCardScannerModule(reactContext)
    } else {
      null
    }
  }

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
      VisionCameraPaymentCardScannerModule.NAME to ReactModuleInfo(
        name = VisionCameraPaymentCardScannerModule.NAME,
        className = VisionCameraPaymentCardScannerModule.NAME,
        canOverrideExistingModule = false,
        needsEagerInit = false,
        isCxxModule = false,
        isTurboModule = true
      )
    )
  }
}
