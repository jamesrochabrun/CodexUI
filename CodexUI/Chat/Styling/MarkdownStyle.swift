//
//  MarkdownStyle.swift
//  CodexUI
//

import AppKit
import Down
import SwiftUI

/// Creates a DownStyle configured for the given color scheme
/// Using a function instead of a subclass to avoid actor isolation issues with Swift 6
@MainActor
func makeMarkdownStyle(colorScheme: ColorScheme) -> DownStyle {
  let style = DownStyle()

  style.baseFont = NSFont.systemFont(ofSize: 14, weight: .regular)
  style.baseFontColor = colorScheme.primaryForeground.nsColor

  let paragraphStyle = NSMutableParagraphStyle()
  paragraphStyle.paragraphSpacingBefore = 0
  paragraphStyle.paragraphSpacing = 0
  paragraphStyle.lineSpacing = 3
  style.baseParagraphStyle = paragraphStyle

  style.h1Size = 18
  style.h2Size = 16
  style.h3Size = 15
  style.codeFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
  // Use brand secondary (purple) for inline code
  style.codeColor = Color.brandSecondary.nsColor
  style.quoteColor = .secondaryLabelColor

  return style
}

// Wrapper class to make the style usable from non-MainActor contexts
final class MarkdownStyle {
  let colorScheme: ColorScheme

  init(colorScheme: ColorScheme) {
    self.colorScheme = colorScheme
  }

  var baseFont: NSFont {
    NSFont.systemFont(ofSize: 14, weight: .regular)
  }

  var baseFontColor: NSColor {
    colorScheme == .dark ? NSColor.white : NSColor.black
  }

  @MainActor
  func createDownStyle() -> DownStyle {
    makeMarkdownStyle(colorScheme: colorScheme)
  }
}

// Extension to add NSFont size adjustment
extension NSFont {
  func withSize(_ size: CGFloat) -> NSFont {
    return NSFont(descriptor: fontDescriptor, size: size) ?? self
  }
}

// Extension to convert SwiftUI Color to NSColor
extension SwiftUI.Color {
  var nsColor: NSColor {
    return NSColor(self)
  }
}

// Add theme colors to ColorScheme
extension ColorScheme {
  var primaryForeground: SwiftUI.Color {
    self == .dark ? .white : .black
  }
}
