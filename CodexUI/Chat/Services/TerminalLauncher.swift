//
//  TerminalLauncher.swift
//  CodexUI
//

import Foundation
import AppKit

/// Helper to launch Terminal.app with Codex session resume command
public struct TerminalLauncher {

  /// Launches Terminal with a Codex session resume command
  /// - Parameters:
  ///   - sessionId: The session ID to resume
  ///   - projectPath: The project path to cd into before resuming
  /// - Returns: An error if launching fails, nil on success
  public static func launchTerminalWithSession(
    _ sessionId: String,
    projectPath: String
  ) -> Error? {
    // Find the codex executable
    guard let codexPath = findCodexExecutable() else {
      return NSError(
        domain: "TerminalLauncher",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not find 'codex' command. Please ensure Codex CLI is installed."]
      )
    }

    // Escape paths for shell
    let escapedPath = projectPath
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedCodexPath = codexPath
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedSessionId = sessionId
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")

    // Construct the command
    // Use `codex resume <session-id>` with the CLI's actual thread ID
    var command = ""
    if !projectPath.isEmpty {
      command = "cd \"\(escapedPath)\" && \"\(escapedCodexPath)\" resume \"\(escapedSessionId)\""
    } else {
      command = "\"\(escapedCodexPath)\" resume \"\(escapedSessionId)\""
    }

    // Create a temporary .command script
    let tempDir = NSTemporaryDirectory()
    let scriptPath = (tempDir as NSString).appendingPathComponent("codex_resume_\(UUID().uuidString).command")

    let scriptContent = """
    #!/bin/bash
    \(command)
    """

    do {
      // Write script file
      try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)

      // Make executable (755)
      let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
      try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptPath)

      // Open with Terminal.app
      let url = URL(fileURLWithPath: scriptPath)
      NSWorkspace.shared.open(url)

      // Clean up after 5 seconds
      Task {
        try? await Task.sleep(for: .seconds(5))
        try? FileManager.default.removeItem(atPath: scriptPath)
      }

      return nil
    } catch {
      return NSError(
        domain: "TerminalLauncher",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to launch Terminal: \(error.localizedDescription)"]
      )
    }
  }

  /// Finds the full path to the codex executable
  /// - Returns: The full path if found, nil otherwise
  public static func findCodexExecutable() -> String? {
    let fileManager = FileManager.default
    let homeDir = NSHomeDirectory()

    // Priority 1: Local codex installation
    let localCodexPath = "\(homeDir)/.codex/local/codex"
    if fileManager.fileExists(atPath: localCodexPath) {
      return localCodexPath
    }

    // Priority 2: NVM paths (common node versions)
    let nvmPaths = [
      "\(homeDir)/.nvm/current/bin",
      "\(homeDir)/.nvm/versions/node/v22.16.0/bin",
      "\(homeDir)/.nvm/versions/node/v20.11.1/bin",
      "\(homeDir)/.nvm/versions/node/v18.19.0/bin"
    ]

    for nvmPath in nvmPaths {
      let codexPath = "\(nvmPath)/codex"
      if fileManager.fileExists(atPath: codexPath) {
        return codexPath
      }
    }

    // Priority 3: Default system paths
    let defaultPaths = [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin"
    ]

    for path in defaultPaths {
      let codexPath = "\(path)/codex"
      if fileManager.fileExists(atPath: codexPath) {
        return codexPath
      }
    }

    // Fallback: use 'which' command
    let task = Process()
    task.launchPath = "/usr/bin/which"
    task.arguments = ["codex"]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()

    do {
      try task.run()
      task.waitUntilExit()

      if task.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
          return path
        }
      }
    } catch {
      // Ignore which command errors
    }

    return nil
  }
}
