//
//  FileInfo.swift
//  CodexUI
//

import Foundation

/// Represents information about a file
public struct FileInfo: Equatable, Identifiable, Codable, Hashable {
  public let id: UUID

  /// Full path to the file
  public let path: String

  /// File name without path
  public let name: String

  /// File content (optional, loaded on demand)
  public let content: String?

  /// File extension
  public var fileExtension: String? {
    URL(fileURLWithPath: path).pathExtension.isEmpty ? nil : URL(fileURLWithPath: path).pathExtension
  }

  /// Programming language based on file extension
  public var language: String? {
    guard let ext = fileExtension else { return nil }
    switch ext.lowercased() {
    case "swift": return "swift"
    case "m", "mm": return "objective-c"
    case "h", "hpp": return "c++"
    case "js", "jsx": return "javascript"
    case "ts", "tsx": return "typescript"
    case "py": return "python"
    case "rb": return "ruby"
    case "java": return "java"
    case "kt": return "kotlin"
    case "go": return "go"
    case "rs": return "rust"
    case "php": return "php"
    case "cs": return "csharp"
    case "sh", "bash": return "bash"
    case "yml", "yaml": return "yaml"
    case "json": return "json"
    case "xml": return "xml"
    case "md": return "markdown"
    default: return nil
    }
  }

  public init(id: UUID = UUID(), path: String, name: String? = nil, content: String? = nil) {
    self.id = id
    self.path = path
    self.name = name ?? URL(fileURLWithPath: path).lastPathComponent
    self.content = content
  }
}
