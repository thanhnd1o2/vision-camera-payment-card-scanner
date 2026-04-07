package com.visioncamerapaymentcardscanner

import android.content.pm.PackageManager
import android.net.Uri
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

internal class MlKitCardScanner(
  private val reactContext: ReactApplicationContext
) : AndroidCardScanner {
  override fun isSupported(): Boolean {
    return reactContext.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
  }

  override fun scanCardImage(options: ReadableMap, promise: Promise) {
    val imageUri = if (options.hasKey("imageUri") && !options.isNull("imageUri")) {
      options.getString("imageUri")
    } else {
      null
    }

    if (imageUri.isNullOrBlank()) {
      promise.resolve(CardParser.emptyResult())
      return
    }

    val scanOptions = CardParser.fromReadableMap(options)
    val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    try {
      val inputImage = InputImage.fromFilePath(reactContext, Uri.parse(imageUri))
      recognizer.process(inputImage)
        .addOnSuccessListener { recognizedText ->
          val combinedText = recognizedText.text ?: ""
          promise.resolve(CardParser.fromOcrText(combinedText, scanOptions))
          recognizer.close()
        }
        .addOnFailureListener { error ->
          recognizer.close()
          promise.reject(
            "E_SCAN_IMAGE_FAILED",
            "ML Kit text recognition failed for the provided image.",
            error
          )
        }
    } catch (error: Exception) {
      recognizer.close()
      promise.reject(
        "E_INVALID_IMAGE_URI",
        "Failed to load the provided image URI for Android OCR scanning.",
        error
      )
    }
  }
}
