//
//  SessionManager.swift
//  CodexUI
//

import Foundation

// MARK: - SessionManager

/// Manages session lifecycle for CodexUI
public final class SessionManager: @unchecked Sendable {
  
  public static let shared = SessionManager()
  
  private let storage: SessionStorageProtocol
  
  private init() {
    self.storage = CodexSQLiteStorage()
  }
  
  /// Starts a new session
  @MainActor
  public func startNewSession(chatViewModel: ChatViewModel, workingDirectory: String? = nil) {
    // Clear any existing conversation
    chatViewModel.clearConversation()

    // Set the session working directory if provided
    if let dir = workingDirectory, !dir.isEmpty {
      chatViewModel.sessionWorkingDirectory = dir
    }

    // Note: Actual session saving happens when the first message is sent
    // and we have a session ID
  }
  
  /// Restores a session from storage
  public func restoreSession(session: StoredSession, chatViewModel: ChatViewModel) async {
    // Fetch fresh session data from storage to get all messages
    let freshSession: StoredSession
    do {
      if let loadedSession = try await storage.getSession(id: session.id) {
        freshSession = loadedSession
      } else {
        freshSession = session
      }
    } catch {
      freshSession = session
    }
    
    await MainActor.run {
      // Use the session's stored working directory
      let workingDirectory = freshSession.workingDirectory

      // Inject the session into the chat view model
      chatViewModel.injectSession(
        sessionId: freshSession.id,
        messages: freshSession.messages,
        workingDirectory: workingDirectory?.isEmpty == false ? workingDirectory : nil
      )
    }
  }
  
  /// Loads all available sessions
  public func loadAvailableSessions() async throws -> [StoredSession] {
    try await storage.getAllSessions()
  }
  
  /// Deletes a session
  public func deleteSession(sessionId: String) async throws {
    try await storage.deleteSession(id: sessionId)
  }
  
  /// Deletes all sessions
  public func deleteAllSessions() async throws {
    try await storage.deleteAllSessions()
  }
  
  /// Saves a new session
  public func saveSession(
    id: String,
    firstMessage: String,
    workingDirectory: String?,
    branchName: String?,
    isWorktree: Bool
  ) async throws {
    try await storage.saveSession(
      id: id,
      firstMessage: firstMessage,
      workingDirectory: workingDirectory,
      branchName: branchName,
      isWorktree: isWorktree
    )
  }
  
  /// Updates session messages
  public func saveMessages(sessionId: String, messages: [ChatMessage]) async throws {
    try await storage.updateSessionMessages(id: sessionId, messages: messages)
  }
  
  /// Updates the session ID
  public func updateSessionId(oldId: String, newId: String) async throws {
    try await storage.updateSessionId(oldId: oldId, newId: newId)
  }
  
  /// Updates last accessed time
  public func updateLastAccessed(sessionId: String) async throws {
    try await storage.updateLastAccessed(id: sessionId)
  }
}
