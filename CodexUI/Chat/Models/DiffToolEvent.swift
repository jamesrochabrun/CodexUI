//
//  DiffToolEvent.swift
//  CodexUI
//

import Foundation

/// Represents a captured Edit/Write/MultiEdit tool event for diff rendering
public struct DiffToolEvent: Identifiable, Codable, Equatable, Sendable {
  /// Unique identifier for this diff event
  public let id: UUID

  /// The edit tool type as a raw string ("edit", "write", "multiEdit")
  public let editToolRaw: String

  /// Tool parameters needed for diff rendering
  /// - Edit: file_path, old_string, new_string, replace_all (optional)
  /// - Write: file_path, content
  /// - MultiEdit: file_path, edits (JSON array)
  public let toolParameters: [String: String]

  /// When the tool event occurred
  public let timestamp: Date

  public init(
    id: UUID = UUID(),
    editToolRaw: String,
    toolParameters: [String: String],
    timestamp: Date = Date()
  ) {
    self.id = id
    self.editToolRaw = editToolRaw
    self.toolParameters = toolParameters
    self.timestamp = timestamp
  }
}
