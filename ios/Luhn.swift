import Foundation

final class Luhn {
  func isValid(_ pan: String) -> Bool {
    let digits = pan.compactMap { $0.wholeNumberValue }

    guard digits.count >= 12 else {
      return false
    }

    var sum = 0
    let reversed = digits.reversed()

    for (index, digit) in reversed.enumerated() {
      if index % 2 == 1 {
        let doubled = digit * 2
        sum += doubled > 9 ? doubled - 9 : doubled
      } else {
        sum += digit
      }
    }

    return sum % 10 == 0
  }
}
