package com.visioncamerapaymentcardscanner

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap

internal data class AndroidScanOptions(
  val scanExpiry: Boolean = true,
  val restrictToBrands: Set<String> = emptySet()
)

internal object CardParser {
  private val expiryRegex = Regex("(0[1-9]|1[0-2])\\s*/\\s*(\\d{2}|\\d{4})")
  private val panCandidateRegex = Regex("(?:\\d[ -]?){12,19}")
  private val mastercardRegex = Regex("^(5[1-5]|2(2[2-9]|[3-6][0-9]|7[01]|720)).*")
  private val amexRegex = Regex("^3[47].*")
  private val nonNameCharactersRegex = Regex("[^A-Z .'-]")
  private val collapseWhitespaceRegex = Regex("\\s+")
  private val blockedNameTokens = setOf(
    "VISA",
    "MASTERCARD",
    "MASTERCARDID",
    "AMEX",
    "AMERICAN",
    "EXPRESS",
    "VALID",
    "THRU",
    "FROM",
    "MONTH",
    "YEAR",
    "CARD",
    "DEBIT",
    "CREDIT",
    "PLATINUM",
    "GOLD",
    "BANK",
    "BANQUE",
    "ELECTRON",
    "SIGNATURE",
    "MEMBER",
    "SINCE"
  )

  fun emptyResult(): WritableMap {
    return Arguments.createMap().apply {
      putBoolean("complete", false)
    }
  }

  fun emptyResultMap(): Map<String, Any> {
    return mapOf("complete" to false)
  }

  fun fromReadableMap(options: ReadableMap?): AndroidScanOptions {
    if (options == null) {
      return AndroidScanOptions()
    }

    val scanExpiry = if (options.hasKey("scanExpiry") && !options.isNull("scanExpiry")) {
      options.getBoolean("scanExpiry")
    } else {
      true
    }

    val restrictToBrands = if (
      options.hasKey("restrictToBrands") &&
      !options.isNull("restrictToBrands")
    ) {
      val brands = options.getArray("restrictToBrands")
      buildSet {
        if (brands != null) {
          for (index in 0 until brands.size()) {
            val brand = brands.getString(index)?.trim()?.lowercase()
            if (!brand.isNullOrEmpty()) {
              add(brand)
            }
          }
        }
      }
    } else {
      emptySet()
    }

    return AndroidScanOptions(
      scanExpiry = scanExpiry,
      restrictToBrands = restrictToBrands
    )
  }

  fun fromFrameProcessorMap(options: Map<String, Any>?): AndroidScanOptions {
    if (options == null) {
      return AndroidScanOptions()
    }

    val scanExpiry = (options["scanExpiry"] as? Boolean) ?: true
    val restrictToBrands = ((options["restrictToBrands"] as? List<*>) ?: emptyList<Any>())
      .mapNotNull { it?.toString()?.trim()?.lowercase() }
      .filter { it.isNotEmpty() }
      .toSet()

    return AndroidScanOptions(
      scanExpiry = scanExpiry,
      restrictToBrands = restrictToBrands
    )
  }

  fun fromOcrText(recognizedText: String, options: AndroidScanOptions): WritableMap {
    val result = fromOcrTextMap(recognizedText, options)
    return Arguments.createMap().apply {
      result["pan"]?.let { putString("pan", it as String) }
      result["last4"]?.let { putString("last4", it as String) }
      result["brand"]?.let { putString("brand", it as String) }
      result["cardholderName"]?.let { putString("cardholderName", it as String) }
      result["expiryMonth"]?.let { putInt("expiryMonth", it as Int) }
      result["expiryYear"]?.let { putInt("expiryYear", it as Int) }
      putBoolean("complete", result["complete"] as? Boolean ?: false)
    }
  }

  fun fromOcrTextMap(recognizedText: String, options: AndroidScanOptions): Map<String, Any> {
    val normalizedPan = extractPan(recognizedText)
    if (normalizedPan.isEmpty()) {
      return emptyResultMap()
    }

    val brand = detectBrand(normalizedPan)
    if (options.restrictToBrands.isNotEmpty() && !options.restrictToBrands.contains(brand)) {
      return emptyResultMap()
    }

    val expiry = if (options.scanExpiry) extractExpiry(recognizedText) else null
    val cardholderName = extractCardholderName(recognizedText)
    val result = linkedMapOf<String, Any>(
      "pan" to normalizedPan,
      "last4" to getLast4(normalizedPan),
      "brand" to brand,
      "complete" to (
        normalizedPan.length in 12..19 &&
          isValidLuhn(normalizedPan) &&
          (!options.scanExpiry || expiry != null)
      )
    )

    cardholderName?.let { result["cardholderName"] = it }
    expiry?.first?.let { result["expiryMonth"] = it }
    expiry?.second?.let { result["expiryYear"] = it }

    return result
  }

  private fun extractPan(text: String): String {
    val candidates = panCandidateRegex.findAll(text)
      .map { normalizePan(it.value) }
      .filter { it.length in 12..19 }
      .toList()

    return candidates.firstOrNull { isValidLuhn(it) }
      ?: candidates.maxByOrNull { it.length }
      ?: ""
  }

  private fun extractExpiry(text: String): Pair<Int, Int>? {
    val match = expiryRegex.find(text) ?: return null
    val month = match.groupValues.getOrNull(1)?.toIntOrNull() ?: return null
    val rawYear = match.groupValues.getOrNull(2)?.toIntOrNull() ?: return null
    val year = if (rawYear < 100) 2000 + rawYear else rawYear
    return month to year
  }

  private fun extractCardholderName(text: String): String? {
    val lines = text.lines()
      .map { collapseWhitespaceRegex.replace(it.trim(), " ") }
      .filter { it.isNotEmpty() }

    val scoredCandidates = lines.mapNotNull { line ->
      val normalized = normalizeNameCandidate(line) ?: return@mapNotNull null
      val tokens = normalized.split(' ').filter { it.isNotBlank() }
      if (tokens.size !in 2..4) {
        return@mapNotNull null
      }
      if (tokens.any { token -> token.length < 2 }) {
        return@mapNotNull null
      }
      if (tokens.any { token -> blockedNameTokens.contains(token) }) {
        return@mapNotNull null
      }

      val score = tokens.sumOf { it.length } + if (line == line.uppercase()) 3 else 0
      normalized to score
    }

    return scoredCandidates.maxByOrNull { it.second }?.first
  }

  private fun normalizeNameCandidate(line: String): String? {
    if (line.any { it.isDigit() }) {
      return null
    }
    if (expiryRegex.containsMatchIn(line)) {
      return null
    }

    val cleaned = collapseWhitespaceRegex.replace(
      nonNameCharactersRegex.replace(line.uppercase(), " "),
      " "
    ).trim()

    if (cleaned.isEmpty()) {
      return null
    }

    val tokens = cleaned.split(' ').filter { it.isNotBlank() }
    if (tokens.isEmpty()) {
      return null
    }
    if (tokens.any { token -> token.length > 20 }) {
      return null
    }

    return tokens.joinToString(" ")
  }

  private fun normalizePan(pan: String?): String {
    if (pan.isNullOrBlank()) {
      return ""
    }

    val builder = StringBuilder()
    pan.forEach { char ->
      if (char.isDigit()) {
        builder.append(char)
      }
    }
    return builder.toString()
  }

  private fun getLast4(pan: String): String {
    return if (pan.length <= 4) pan else pan.takeLast(4)
  }

  private fun detectBrand(pan: String): String {
    return when {
      pan.startsWith("4") -> "visa"
      pan.matches(mastercardRegex) -> "mastercard"
      pan.matches(amexRegex) -> "amex"
      else -> "unknown"
    }
  }

  private fun isValidLuhn(pan: String): Boolean {
    if (pan.isEmpty()) {
      return false
    }

    var sum = 0
    var shouldDouble = false

    for (index in pan.length - 1 downTo 0) {
      var digit = pan[index].digitToIntOrNull() ?: return false
      if (shouldDouble) {
        digit *= 2
        if (digit > 9) {
          digit -= 9
        }
      }
      sum += digit
      shouldDouble = !shouldDouble
    }

    return sum % 10 == 0
  }
}
