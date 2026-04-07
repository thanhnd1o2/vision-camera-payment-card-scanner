package com.visioncamerapaymentcardscanner

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReadableMap

internal interface AndroidCardScanner {
  fun isSupported(): Boolean
  fun scanCardImage(options: ReadableMap, promise: Promise)
}
