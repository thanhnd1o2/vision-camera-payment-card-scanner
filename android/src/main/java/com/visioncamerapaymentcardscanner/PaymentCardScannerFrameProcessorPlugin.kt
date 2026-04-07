package com.visioncamerapaymentcardscanner

import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.mrousavy.camera.frameprocessors.Frame
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin
import java.util.concurrent.TimeUnit

class PaymentCardScannerFrameProcessorPlugin : FrameProcessorPlugin() {
  private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
  @Volatile private var lastProcessedTimestamp: Long = 0L
  @Volatile private var lastResult: Map<String, Any>? = null
  override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any? {

    val timestamp = try {
      frame.timestamp
    } catch (_: Throwable) {
      0L
    }

    val cachedResult = lastResult
    if (timestamp != 0L && timestamp == lastProcessedTimestamp) {
      return cachedResult
    }

    val options = CardParser.fromFrameProcessorMap(params)
    val image = createInputImage(frame) ?: return cachedResult ?: CardParser.emptyResultMap()

    val recognizedText = try {
      val result = Tasks.await(recognizer.process(image), 120, TimeUnit.MILLISECONDS)
      result.text ?: ""
    } catch (_: Throwable) {
      return cachedResult ?: CardParser.emptyResultMap()
    }

    val parsedResult = CardParser.fromOcrTextMap(recognizedText, options)
    lastProcessedTimestamp = timestamp
    lastResult = parsedResult
    return parsedResult
  }

  @OptIn(ExperimentalGetImage::class)
  private fun createInputImage(frame: Frame): InputImage? {
    val mediaImage = try {
      frame.image
    } catch (_: Throwable) {
      null
    } ?: return null

    val rotationDegrees = try {
      frame.imageProxy.imageInfo.rotationDegrees
    } catch (_: Throwable) {
      0
    }

    return InputImage.fromMediaImage(mediaImage, rotationDegrees)
  }
}
