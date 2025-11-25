//
//  NSAttributedString+Trimming.swift
//  CodexUI
//

import Foundation

/// Extension to provide whitespace trimming functionality for NSAttributedString
extension NSAttributedString {
  /// Removes leading and trailing whitespace and newline characters from an attributed string
  /// while preserving all text attributes.
  ///
  /// - Returns: A new NSAttributedString with whitespace trimmed from both ends.
  ///            Returns an empty attributed string if the original contains only whitespace.
  ///
  /// - Note: This method preserves all attributes of the non-whitespace content.
  public func trimmedAttributedString() -> NSAttributedString {
    // Create character set for non-whitespace characters
    let nonWhiteSpace = CharacterSet.whitespacesAndNewlines.inverted
    
    // Find the first non-whitespace character from the start
    let startRange = string.rangeOfCharacter(from: nonWhiteSpace)
    
    // Find the first non-whitespace character from the end
    let endRange = string.rangeOfCharacter(from: nonWhiteSpace, options: .backwards)
    
    // If no non-whitespace characters found, return empty attributed string
    guard let startLocation = startRange?.lowerBound, let endLocation = endRange?.lowerBound else {
      return NSAttributedString(string: "")
    }
    
    // If the string doesn't need trimming, return self
    if startLocation == string.startIndex, endLocation == string.index(before: string.endIndex) {
      return self
    }
    
    // Create range from first to last non-whitespace character (inclusive)
    let trimmedRange = startLocation...endLocation
    
    // Extract and return the substring with preserved attributes
    return attributedSubstring(from: NSRange(trimmedRange, in: string))
  }
}
