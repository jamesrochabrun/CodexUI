//
//  Color+Theme.swift
//  CodexUI
//

import AppKit
import SwiftUI

// MARK: - Theme System

/// Available app themes
public enum AppTheme: String, CaseIterable, Identifiable {
  case codex = "codex"
  // Future themes: .bat, .xcode, .custom

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .codex: return "Codex"
    }
  }

  public var description: String {
    switch self {
    case .codex: return "Teal and purple"
    }
  }
}

/// Theme color definitions
public struct ThemeColors {
  public let brandPrimary: Color
  public let brandSecondary: Color
  public let brandTertiary: Color

  public init(brandPrimary: Color, brandSecondary: Color, brandTertiary: Color) {
    self.brandPrimary = brandPrimary
    self.brandSecondary = brandSecondary
    self.brandTertiary = brandTertiary
  }
}

// MARK: - Hex/RGB Initializers

extension Color {
  /// Create a Color from 0-255 RGB values
  init(red: Int, green: Int, blue: Int, alpha: Double = 1.0) {
    self.init(
      .sRGB,
      red: Double(red) / 255.0,
      green: Double(green) / 255.0,
      blue: Double(blue) / 255.0,
      opacity: alpha
    )
  }

  /// Create a Color from a hex string like "#14B8A6" or "14B8A6"
  init(hex: String, alpha: Double = 1.0) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: hex).scanHexInt64(&int)

    let r, g, b: UInt64
    switch hex.count {
    case 6:  // RGB (24-bit)
      (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
    default:
      (r, g, b) = (0, 0, 0)
    }

    self.init(red: Int(r), green: Int(g), blue: Int(b), alpha: alpha)
  }
}

// MARK: - Theme-Aware Brand Colors

extension Color {
  /// Primary brand color (teal in Codex theme)
  static var brandPrimary: Color {
    getCurrentThemeColors().brandPrimary
  }

  /// Secondary brand color (purple in Codex theme)
  static var brandSecondary: Color {
    getCurrentThemeColors().brandSecondary
  }

  /// Tertiary brand color (slate in Codex theme)
  static var brandTertiary: Color {
    getCurrentThemeColors().brandTertiary
  }

  private static func getCurrentThemeColors() -> ThemeColors {
    // For now, hardcode .codex. Later: read from UserDefaults
    let theme: AppTheme = .codex

    switch theme {
    case .codex:
      return ThemeColors(
        brandPrimary: Color(hex: "#14B8A6"),  // teal
        brandSecondary: Color(hex: "#9333EA"),  // purple
        brandTertiary: Color(hex: "#64748B")  // slate
      )
    }
  }
}

// MARK: - Primary Palette (Teal)

extension Color {
  static let primaryTeal = Color(hex: "#14B8A6")  // Vibrant teal
  static let deepTeal = Color(hex: "#0D9488")  // Deep teal
  static let lightTeal = Color(hex: "#5EEAD4")  // Light teal
  static let ultraLightTeal = Color(hex: "#99F6E4")  // Ultra light teal
  static let darkTeal = Color(hex: "#0F766E")  // Dark teal
}

// MARK: - Secondary Palette (Purple)

extension Color {
  static let primaryPurple = Color(hex: "#9333EA")  // Vibrant purple
  static let deepPurple = Color(hex: "#7C3AED")  // Deep purple
  static let lightPurple = Color(hex: "#A78BFA")  // Light purple
  static let ultraLightPurple = Color(hex: "#C4B5FD")  // Ultra light purple
  static let darkPurple = Color(hex: "#5B21B6")  // Dark purple
}

// MARK: - Complementary Colors

extension Color {
  static let purpleAccent = Color(hex: "#D946EF")  // Pink-purple accent
  static let indigoPurple = Color(hex: "#6366F1")  // Indigo-purple
  static let bluePurple = Color(hex: "#818CF8")  // Blue-purple
  static let tealAccent = Color(hex: "#2DD4BF")  // Teal accent
}

// MARK: - Supporting Colors (Semantic)

extension Color {
  static let warmCoral = Color(hex: "#FB7185")  // Errors
  static let softGreen = Color(hex: "#86EFAC")  // Success
  static let goldenAmber = Color(hex: "#FBBF24")  // Warnings
  static let skyBlue = Color(hex: "#7DD3FC")  // Info
  static let lavenderGray = Color(hex: "#E9D5FF")  // Subtle purple accent
}

// MARK: - Background Colors

extension Color {
  static let backgroundDark = Color(hex: "#262624")
  static let backgroundLight = Color(hex: "#FAF9F5")
  static let expandedContentBackgroundDark = Color(hex: "#1F2421")
  static let expandedContentBackgroundLight = Color.white

  static func adaptiveBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? backgroundDark : backgroundLight
  }

  static func adaptiveExpandedContentBackground(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? expandedContentBackgroundDark : expandedContentBackgroundLight
  }
}

// MARK: - Semantic Chat Colors

extension Color {
  struct Chat {
    // Assistant message colors
    static let assistantPrimary = brandSecondary  // purple
    static let assistantSecondary = lightPurple
    static let assistantAccent = purpleAccent

    // User message colors
    static let userPrimary = brandPrimary  // teal
    static let userSecondary = lightTeal

    // Tool colors
    static let toolUse = goldenAmber
    static let toolResult = softGreen
    static let toolError = warmCoral
    static let thinking = skyBlue
    static let webSearch = Color(hex: "#8B5CF6")  // Violet
  }
}

// MARK: - Terminal UI Colors

extension Color {
  struct Terminal {
    static let userPrompt = primaryTeal        // Teal (#14B8A6) - ">" prefix
    static let reasoning = lightTeal           // Light teal (#5EEAD4) - "*" prefix
    static let command = deepTeal              // Deep teal (#0D9488) - "$" prefix
    static let success = ultraLightTeal        // Ultra light (#99F6E4) - "✓" prefix
    static let error = darkTeal                // Dark teal (#0F766E) - "!" prefix
    static let assistant = primaryTeal         // Teal (#14B8A6) - "◆" prefix
    static let output = deepTeal               // Deep teal (#0D9488) - "|" prefix
  }
}

// MARK: - Gradients

extension Color {
  static let brandGradient = LinearGradient(
    colors: [brandPrimary, brandSecondary],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let tealGradient = LinearGradient(
    colors: [primaryTeal, deepTeal],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let purpleGradient = LinearGradient(
    colors: [primaryPurple, deepPurple],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let lightPurpleGradient = LinearGradient(
    colors: [lightPurple, ultraLightPurple],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let subtlePurpleGradient = LinearGradient(
    colors: [primaryPurple.opacity(0.3), primaryPurple.opacity(0.1)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let subtleTealGradient = LinearGradient(
    colors: [primaryTeal.opacity(0.3), primaryTeal.opacity(0.1)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

// MARK: - Hex <-> NSColor Bridging

extension Color {
  /// Convert an NSColor to a hex string like #RRGGBB
  static func hexString(from nsColor: NSColor) -> String {
    let color = nsColor.usingColorSpace(.sRGB) ?? nsColor
    let r = Int(round(color.redComponent * 255))
    let g = Int(round(color.greenComponent * 255))
    let b = Int(round(color.blueComponent * 255))
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}

extension NSColor {
  /// Create an NSColor from a hex string like #RRGGBB
  static func fromHex(_ hex: String) -> NSColor {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: cleaned).scanHexInt64(&int)
    let r, g, b: UInt64
    switch cleaned.count {
    case 6:
      (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
    default:
      (r, g, b) = (20, 184, 166)  // fallback teal
    }
    return NSColor(
      srgbRed: CGFloat(r) / 255.0,
      green: CGFloat(g) / 255.0,
      blue: CGFloat(b) / 255.0,
      alpha: 1.0
    )
  }

  /// Hex string like #RRGGBB
  func toHexString() -> String {
    Color.hexString(from: self)
  }
}

