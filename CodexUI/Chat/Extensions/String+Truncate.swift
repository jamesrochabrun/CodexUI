//
//  String+Truncate.swift
//  CodexUI
//

import Foundation

extension String {
  /// Truncates string intelligently at word boundaries
  ///
  /// - Parameters:
  ///   - length: The maximum length of the truncated string
  ///   - suffix: The suffix to append when truncating (default: "...")
  /// - Returns: A truncated string that breaks at word boundaries when possible
  func truncateIntelligently(to length: Int, suffix: String = "...") -> String {
    if self.count <= length {
      return self
    }

    let endIndex = self.index(self.startIndex, offsetBy: length)
    let truncated = String(self[..<endIndex])

    // Try to break at word boundary
    if let lastSpace = truncated.lastIndex(of: " ") {
      return String(truncated[..<lastSpace]) + suffix
    }

    return truncated + suffix
  }
}
