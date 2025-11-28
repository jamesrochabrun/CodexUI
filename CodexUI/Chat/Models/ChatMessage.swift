//
//  ChatMessage.swift
//  CodexUI
//

import Foundation

// MARK: - Stored Attachment

/// Represents a stored attachment in a chat message (for persistence)
public struct StoredAttachment: Identifiable, Codable, Equatable {
  public let id: UUID
  public let fileName: String
  public let type: String
  public let filePath: String?

  public init(id: UUID = UUID(), fileName: String, type: String, filePath: String?) {
    self.id = id
    self.fileName = fileName
    self.type = type
    self.filePath = filePath
  }
}

/// Represents a single message in the chat conversation
public struct ChatMessage: Identifiable, Equatable {
  /// Unique identifier for the message
  public let id: UUID

  /// The role of the message sender
  public var role: MessageRole

  /// The text content of the message
  public var content: String

  /// When the message was created
  public let timestamp: Date

  /// Whether the message has finished streaming
  public var isComplete: Bool

  /// Whether the message was cancelled by the user
  public var wasCancelled: Bool

  /// Attachments associated with the message
  public var attachments: [StoredAttachment]?

  public init(
    id: UUID = UUID(),
    role: MessageRole,
    content: String,
    timestamp: Date = Date(),
    isComplete: Bool = true,
    wasCancelled: Bool = false,
    attachments: [StoredAttachment]? = nil
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.isComplete = isComplete
    self.wasCancelled = wasCancelled
    self.attachments = attachments
  }
}

/// Defines who sent the message
public enum MessageRole: String {
  case user
  case assistant
}
