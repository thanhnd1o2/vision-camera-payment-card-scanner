import Foundation

final class CardParser {
  private let blockedNameTokens: Set<String> = [
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
  ]

  func normalizePAN(_ value: String) -> String {
    return value.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
  }

  func extractLast4(from pan: String?) -> String? {
    guard let pan, pan.count >= 4 else {
      return nil
    }

    return String(pan.suffix(4))
  }

  func parseExpiry(from text: String) -> (month: Int, year: Int)? {
    let normalized = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "-", with: "/")

    let pattern = "^(\\d{2})/(\\d{2}|\\d{4})$"

    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return nil
    }

    let range = NSRange(location: 0, length: normalized.utf16.count)
    guard let match = regex.firstMatch(in: normalized, options: [], range: range),
          let monthRange = Range(match.range(at: 1), in: normalized),
          let yearRange = Range(match.range(at: 2), in: normalized),
          let month = Int(normalized[monthRange]),
          month >= 1,
          month <= 12 else {
      return nil
    }

    let yearToken = String(normalized[yearRange])
    guard let rawYear = Int(yearToken) else {
      return nil
    }

    let year = yearToken.count == 2 ? 2000 + rawYear : rawYear
    return (month: month, year: year)
  }

  func findFirstExpiry(in texts: [String]) -> (month: Int, year: Int)? {
    for text in texts {
      if let expiry = parseExpiry(from: text) {
        return expiry
      }

      let normalized = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      let tokens = normalized
        .components(separatedBy: CharacterSet.whitespacesAndNewlines)
        .filter { !$0.isEmpty }

      for token in tokens {
        if let expiry = parseExpiry(from: token) {
          return expiry
        }
      }
    }

    return nil
  }

  func findCandidatePANs(in text: String) -> [String] {
    let pattern = "(?:\\d[ -]?){12,19}"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return []
    }

    let range = NSRange(location: 0, length: text.utf16.count)
    return regex.matches(in: text, options: [], range: range).compactMap { match in
      guard let swiftRange = Range(match.range, in: text) else {
        return nil
      }

      let candidate = normalizePAN(String(text[swiftRange]))
      return candidate.isEmpty ? nil : candidate
    }
  }

  func findCardholderName(in texts: [String]) -> String? {
    let scoredCandidates: [(name: String, score: Int)] = texts.compactMap { text in
      let trimmed = text
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      guard let normalized = normalizeNameCandidate(trimmed) else {
        return nil
      }

      let tokens = normalized.split(separator: " ").map(String.init)
      guard (2...4).contains(tokens.count) else {
        return nil
      }
      guard !tokens.contains(where: { $0.count < 2 }) else {
        return nil
      }
      guard !tokens.contains(where: { blockedNameTokens.contains($0) }) else {
        return nil
      }

      let score = tokens.reduce(0) { $0 + $1.count } + (trimmed == trimmed.uppercased() ? 3 : 0)
      return (normalized, score)
    }

    return scoredCandidates.max(by: { $0.score < $1.score })?.name
  }

  private func normalizeNameCandidate(_ line: String) -> String? {
    guard !line.isEmpty else {
      return nil
    }
    guard line.rangeOfCharacter(from: .decimalDigits) == nil else {
      return nil
    }
    guard parseExpiry(from: line) == nil else {
      return nil
    }

    let uppercase = line.uppercased()
    let cleaned = uppercase
      .replacingOccurrences(of: "[^A-Z .'-]", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleaned.isEmpty else {
      return nil
    }

    let tokens = cleaned.split(separator: " ").map(String.init)
    guard !tokens.isEmpty else {
      return nil
    }
    guard !tokens.contains(where: { $0.count > 20 }) else {
      return nil
    }

    return tokens.joined(separator: " ")
  }
}
