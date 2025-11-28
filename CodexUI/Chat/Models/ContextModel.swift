//
//  ContextModel.swift
//  CodexUI
//

import Foundation

/// Manages the context that will be included in chat messages
struct ContextModel: Equatable {
  /// Files actively being worked on (selected via @ mentions)
  var activeFiles: [FileInfo]

  /// Maximum number of files to keep
  private let maxFiles = 10

  init(activeFiles: [FileInfo] = []) {
    self.activeFiles = activeFiles
  }

  /// Builds a formatted string representation of the context for the prompt
  func buildPromptContext() -> String {
    var contextParts: [String] = []

    // Add active files info
    if !activeFiles.isEmpty {
      contextParts.append("Referenced Files:")
      for file in activeFiles {
        contextParts.append("- \(file.name) (\(file.path))")
        if let content = file.content, !content.isEmpty {
          let preview = String(content.prefix(500))
          let language = file.language ?? "plaintext"
          contextParts.append("""
            ```\(language)
            \(preview)\(content.count > 500 ? "\n... (truncated)" : "")
            ```
            """)
        }
      }
    }

    return contextParts.joined(separator: "\n\n")
  }

  /// Clears all context
  mutating func clear() {
    activeFiles.removeAll()
  }

  /// Checks if the context is empty
  func isEmpty() -> Bool {
    activeFiles.isEmpty
  }

  /// Adds a file, maintaining the maximum limit
  mutating func addFile(_ file: FileInfo) {
    // Remove duplicate files
    activeFiles.removeAll { $0.path == file.path }

    activeFiles.insert(file, at: 0)

    // Keep only the most recent files
    if activeFiles.count > maxFiles {
      activeFiles = Array(activeFiles.prefix(maxFiles))
    }
  }

  /// Removes a specific file
  mutating func removeFile(id: UUID) {
    activeFiles.removeAll { $0.id == id }
  }

  /// Summary description for UI display
  var summary: String {
    if activeFiles.isEmpty {
      return "No context"
    }
    return "\(activeFiles.count) file\(activeFiles.count == 1 ? "" : "s")"
  }
}
