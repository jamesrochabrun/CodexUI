//
//  SettingsManager.swift
//  CodexUI
//

import Foundation
import SwiftUI

@Observable
final class SettingsManager {

  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard
  private let projectPathKey = "com.codexui.projectPath"

  var projectPath: String {
    didSet {
      defaults.set(projectPath, forKey: projectPathKey)
    }
  }

  private init() {
    self.projectPath = defaults.string(forKey: projectPathKey) ?? ""
  }

  func clearProjectPath() {
    projectPath = ""
    defaults.removeObject(forKey: projectPathKey)
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
