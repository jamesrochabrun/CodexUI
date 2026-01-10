//
//  GitDiffProvider.swift
//  CodexUI
//

import Foundation

/// Provides git-based file content for diff comparison
enum GitDiffProvider {

  /// Get original file content from git HEAD
  /// - Parameters:
  ///   - filePath: Absolute path to the file
  ///   - projectPath: Project root directory (git repo root)
  /// - Returns: Original file content from git HEAD, or nil if not in git or error
  static func getOriginalContent(filePath: String, projectPath: String) async -> String? {
    // Convert absolute path to relative path for git
    let relativePath: String
    if filePath.hasPrefix(projectPath + "/") {
      relativePath = String(filePath.dropFirst(projectPath.count + 1))
    } else if filePath.hasPrefix(projectPath) {
      relativePath = String(filePath.dropFirst(projectPath.count))
    } else {
      relativePath = filePath
    }

    print("[GitDiffProvider] Getting original content for: \(relativePath)")
    print("[GitDiffProvider] Project path: \(projectPath)")

    return await withCheckedContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
      process.arguments = ["show", "HEAD:\(relativePath)"]
      process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
          let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
          let content = String(data: data, encoding: .utf8)
          print("[GitDiffProvider] Got original content: \(content?.count ?? 0) characters")
          continuation.resume(returning: content)
        } else {
          let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
          let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
          print("[GitDiffProvider] Git error (exit \(process.terminationStatus)): \(errorString)")
          // File might be new (not in git yet)
          continuation.resume(returning: nil)
        }
      } catch {
        print("[GitDiffProvider] Process error: \(error)")
        continuation.resume(returning: nil)
      }
    }
  }

  /// Check if a file has uncommitted changes
  static func hasUncommittedChanges(filePath: String, projectPath: String) async -> Bool {
    let relativePath: String
    if filePath.hasPrefix(projectPath + "/") {
      relativePath = String(filePath.dropFirst(projectPath.count + 1))
    } else {
      relativePath = filePath
    }

    return await withCheckedContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
      process.arguments = ["diff", "--quiet", "HEAD", "--", relativePath]
      process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

      process.standardOutput = Pipe()
      process.standardError = Pipe()

      do {
        try process.run()
        process.waitUntilExit()
        // Exit code 0 = no changes, 1 = has changes
        continuation.resume(returning: process.terminationStatus != 0)
      } catch {
        continuation.resume(returning: false)
      }
    }
  }
}
