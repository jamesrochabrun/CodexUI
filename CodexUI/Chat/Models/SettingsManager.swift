//
//  SettingsManager.swift
//  CodexUI
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsManager {

  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard
  private let enableXcodeShortcutKey = "com.codexui.enableXcodeShortcut"

  /// Whether the CMD+I shortcut for Xcode text capture is enabled
  var enableXcodeShortcut: Bool {
    didSet {
      defaults.set(enableXcodeShortcut, forKey: enableXcodeShortcutKey)
    }
  }

  private init() {
    // Default to enabled for CMD+I shortcut
    self.enableXcodeShortcut = defaults.object(forKey: enableXcodeShortcutKey) as? Bool ?? true
  }

  /// Validates if the path exists and is a git repository
  func isValidGitRepo(_ path: String) -> Bool {
    guard !path.isEmpty else { return false }

    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false

    // Check path exists and is a directory
    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      return false
    }

    // Check for .git directory or file
    let gitPath = (path as NSString).appendingPathComponent(".git")
    return fileManager.fileExists(atPath: gitPath)
  }
}
