//
//  ChatMessage.swift
//  CodexUI
//

import Foundation

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

  public init(
    id: UUID = UUID(),
    role: MessageRole,
    content: String,
    timestamp: Date = Date(),
    isComplete: Bool = true,
    wasCancelled: Bool = false
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.timestamp = timestamp
    self.isComplete = isComplete
    self.wasCancelled = wasCancelled
  }
}

/// Defines who sent the message
public enum MessageRole: String {
  case user
  case assistant
}
