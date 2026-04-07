import Foundation

final class BrandDetector {
  func detectBrand(for pan: String) -> String {
    if matches(pan, pattern: "^4\\d{12}(\\d{3})?(\\d{3})?$") {
      return "visa"
    }

    if matches(pan, pattern: "^(5[1-5]\\d{14}|2(2[2-9]\\d{12}|[3-6]\\d{13}|7([01]\\d{12}|20\\d{12})))$") {
      return "mastercard"
    }

    if matches(pan, pattern: "^3[47]\\d{13}$") {
      return "amex"
    }

    return "unknown"
  }

  private func matches(_ value: String, pattern: String) -> Bool {
    return value.range(of: pattern, options: .regularExpression) != nil
  }
}
