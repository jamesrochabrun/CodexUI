//
//  CodexSQLiteStorage.swift
//  CodexUI
//

import Foundation
import SQLite

// MARK: - CodexSQLiteStorage

/// SQLite storage for CodexUI sessions using SQLite.swift
public actor CodexSQLiteStorage: SessionStorageProtocol {
  
  private var migrationManager: CodexSQLiteMigrationManager?
  
  public init() {}
  
  public func saveSession(id: String, firstMessage: String, workingDirectory: String?, branchName: String?, isWorktree: Bool) async throws {
    try await initializeDatabaseIfNeeded()
    
    let insert = sessionsTable.insert(
      sessionIdColumn <- id,
      createdAtColumn <- Date(),
      firstUserMessageColumn <- firstMessage,
      lastAccessedAtColumn <- Date(),
      workingDirectoryColumn <- workingDirectory,
      branchNameColumn <- branchName,
      isWorktreeColumn <- isWorktree
    )
    
    try database.run(insert)
  }
  
  public func getAllSessions() async throws -> [StoredSession] {
    try await initializeDatabaseIfNeeded()
    
    var storedSessions = [StoredSession]()
    
    for sessionRow in try database.prepare(sessionsTable.order(lastAccessedAtColumn.desc)) {
      let sessionId = sessionRow[sessionIdColumn]
      
      // Load messages for this session
      let messages = try await getMessagesForSession(sessionId: sessionId)
      
      let storedSession = await StoredSession(
        id: sessionId,
        createdAt: sessionRow[createdAtColumn],
        firstUserMessage: sessionRow[firstUserMessageColumn],
        lastAccessedAt: sessionRow[lastAccessedAtColumn],
        messages: messages,
        workingDirectory: sessionRow[workingDirectoryColumn],
        branchName: sessionRow[branchNameColumn],
        isWorktree: sessionRow[isWorktreeColumn]
      )
      
      storedSessions.append(storedSession)
    }
    return storedSessions
  }
  
  public func getSession(id: String) async throws -> StoredSession? {
    try await initializeDatabaseIfNeeded()
    
    guard let sessionRow = try database.pluck(sessionsTable.filter(sessionIdColumn == id)) else {
      return nil
    }
    
    // Load messages for this session
    let messages = try await getMessagesForSession(sessionId: id)
    
    let storedSession = await StoredSession(
      id: sessionRow[sessionIdColumn],
      createdAt: sessionRow[createdAtColumn],
      firstUserMessage: sessionRow[firstUserMessageColumn],
      lastAccessedAt: sessionRow[lastAccessedAtColumn],
      messages: messages,
      workingDirectory: sessionRow[workingDirectoryColumn],
      branchName: sessionRow[branchNameColumn],
      isWorktree: sessionRow[isWorktreeColumn]
    )
    return storedSession
  }
  
  public func updateLastAccessed(id: String) async throws {
    try await initializeDatabaseIfNeeded()
    
    let session = sessionsTable.filter(sessionIdColumn == id)
    let update = session.update(lastAccessedAtColumn <- Date())
    try database.run(update)
  }
  
  public func deleteSession(id: String) async throws {
    try await initializeDatabaseIfNeeded()
    
    // Delete session (foreign key constraints will cascade to messages and attachments)
    let deleteSession = sessionsTable.filter(sessionIdColumn == id)
    try database.run(deleteSession.delete())
  }
  
  public func deleteAllSessions() async throws {
    try await initializeDatabaseIfNeeded()
    
    // Delete all sessions (foreign key constraints will cascade to messages and attachments)
    try database.run(sessionsTable.delete())
  }
  
  public func updateSessionMessages(id: String, messages: [ChatMessage]) async throws {
    try await initializeDatabaseIfNeeded()
    
    // Delete existing messages for this session (foreign key constraints will cascade to attachments)
    let deleteMessages = messagesTable.filter(messageSessionIdColumn == id)
    _ = try database.run(deleteMessages.delete())
    
    // Insert new messages
    for message in messages {
      let insertMessage = messagesTable.insert(
        messageIdColumn <- message.id.uuidString,
        messageSessionIdColumn <- id,
        messageContentColumn <- message.content,
        messageRoleColumn <- message.role.rawValue,
        messageTimestampColumn <- message.timestamp,
        messageIsCompleteColumn <- message.isComplete,
        messageWasCancelledColumn <- message.wasCancelled
      )
      
      try database.run(insertMessage)
      
      // Insert attachments if any
      if let attachments = message.attachments {
        for (index, attachment) in attachments.enumerated() {
          let insertAttachment = attachmentsTable.insert(
            attachmentIdColumn <- "\(message.id.uuidString)_\(index)",
            attachmentMessageIdColumn <- message.id.uuidString,
            attachmentFileNameColumn <- attachment.fileName,
            attachmentFilePathColumn <- attachment.filePath ?? "",
            attachmentFileTypeColumn <- attachment.type
          )
          
          try database.run(insertAttachment)
        }
      }
    }
  }
  
  public func updateSessionId(oldId: String, newId: String) async throws {
    try await initializeDatabaseIfNeeded()
    
    // First, check if the new session already exists
    let existingNewSession = try database.pluck(sessionsTable.filter(sessionIdColumn == newId))
    if existingNewSession != nil {
      return
    }
    
    // Get the old session details
    guard let oldSessionRow = try database.pluck(sessionsTable.filter(sessionIdColumn == oldId)) else {
      return
    }
    
    // Create new session record FIRST with data from old session
    let insertNewSession = sessionsTable.insert(
      sessionIdColumn <- newId,
      createdAtColumn <- oldSessionRow[createdAtColumn],
      firstUserMessageColumn <- oldSessionRow[firstUserMessageColumn],
      lastAccessedAtColumn <- Date(),
      workingDirectoryColumn <- oldSessionRow[workingDirectoryColumn],
      branchNameColumn <- oldSessionRow[branchNameColumn],
      isWorktreeColumn <- oldSessionRow[isWorktreeColumn]
    )
    try database.run(insertNewSession)
    
    // Now update message session IDs (foreign key constraint satisfied)
    let messages = messagesTable.filter(messageSessionIdColumn == oldId)
    let updateMessages = messages.update(messageSessionIdColumn <- newId)
    _ = try database.run(updateMessages)
    
    // Finally, delete the old session record
    let deleteOldSession = sessionsTable.filter(sessionIdColumn == oldId)
    try database.run(deleteOldSession.delete())
  }
  
  private var database: Connection!
  private var isInitialized = false
  
  // Table definitions
  private let sessionsTable = Table("sessions")
  private let messagesTable = Table("messages")
  private let attachmentsTable = Table("attachments")
  
  // Session columns
  private let sessionIdColumn = Expression<String>("id")
  private let createdAtColumn = Expression<Date>("created_at")
  private let firstUserMessageColumn = Expression<String>("first_user_message")
  private let lastAccessedAtColumn = Expression<Date>("last_accessed_at")
  private let workingDirectoryColumn = Expression<String?>("working_directory")
  private let branchNameColumn = Expression<String?>("branch_name")
  private let isWorktreeColumn = Expression<Bool>("is_worktree")
  
  // Message columns
  private let messageIdColumn = Expression<String>("id")
  private let messageSessionIdColumn = Expression<String>("session_id")
  private let messageContentColumn = Expression<String>("content")
  private let messageRoleColumn = Expression<String>("role")
  private let messageTimestampColumn = Expression<Date>("timestamp")
  private let messageIsCompleteColumn = Expression<Bool>("is_complete")
  private let messageWasCancelledColumn = Expression<Bool>("was_cancelled")
  
  // Attachment columns
  private let attachmentIdColumn = Expression<String>("id")
  private let attachmentMessageIdColumn = Expression<String>("message_id")
  private let attachmentFileNameColumn = Expression<String>("file_name")
  private let attachmentFilePathColumn = Expression<String>("file_path")
  private let attachmentFileTypeColumn = Expression<String>("file_type")
  
  private func initializeDatabaseIfNeeded() async throws {
    guard !isInitialized else { return }
    
    // Create database in Application Support directory
    let fileManager = FileManager.default
    let appSupportDir = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    
    // Create application-specific directory within Application Support
    // Structure: ~/Library/Application Support/CodexUI/
    let appDir = appSupportDir.appendingPathComponent("CodexUI", isDirectory: true)
    try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
    
    // Create SQLite database file path
    // Final path: ~/Library/Application Support/CodexUI/codex_sessions.sqlite
    let dbPath = appDir.appendingPathComponent("codex_sessions.sqlite").path
    
    // Initialize SQLite connection using SQLite.swift
    // This creates the database file if it doesn't exist
    database = try Connection(dbPath)
    
    // Enable foreign key constraints (disabled by default in SQLite)
    try database.execute("PRAGMA foreign_keys = ON")
    
    // Initialize migration manager
    migrationManager = CodexSQLiteMigrationManager(
      database: database,
      databasePath: dbPath
    )
    
    // Run any pending migrations
    try await migrationManager?.runMigrationsIfNeeded()
    
    // Validate database integrity
    try await migrationManager?.validateDatabase()
    
    // Create tables (if they don't exist)
    try await createTables()
    
    // Clean up old backups
    try await migrationManager?.cleanupOldBackups()
    
    isInitialized = true
  }
  
  private func createTables() async throws {
    // Create sessions table
    try database.run(sessionsTable.create(ifNotExists: true) { table in
      table.column(sessionIdColumn, primaryKey: true)
      table.column(createdAtColumn)
      table.column(firstUserMessageColumn)
      table.column(lastAccessedAtColumn)
      table.column(workingDirectoryColumn)
      table.column(branchNameColumn)
      table.column(isWorktreeColumn, defaultValue: false)
    })
    
    // Create messages table
    try database.run(messagesTable.create(ifNotExists: true) { table in
      table.column(messageIdColumn, primaryKey: true)
      table.column(messageSessionIdColumn)
      table.column(messageContentColumn)
      table.column(messageRoleColumn)
      table.column(messageTimestampColumn)
      table.column(messageIsCompleteColumn)
      table.column(messageWasCancelledColumn)
      table.foreignKey(messageSessionIdColumn, references: sessionsTable, sessionIdColumn, delete: .cascade)
    })
    
    // Create attachments table
    try database.run(attachmentsTable.create(ifNotExists: true) { table in
      table.column(attachmentIdColumn, primaryKey: true)
      table.column(attachmentMessageIdColumn)
      table.column(attachmentFileNameColumn)
      table.column(attachmentFilePathColumn)
      table.column(attachmentFileTypeColumn)
      table.foreignKey(attachmentMessageIdColumn, references: messagesTable, messageIdColumn, delete: .cascade)
    })
  }
  
  private func getMessagesForSession(sessionId: String) async throws -> [ChatMessage] {
    var messages = [ChatMessage]()
    
    let query = messagesTable
      .filter(messageSessionIdColumn == sessionId)
      .order(messageTimestampColumn.asc)
    
    for messageRow in try database.prepare(query) {
      let roleString = messageRow[messageRoleColumn]
      let idString = messageRow[messageIdColumn]
      
      guard
        let role = MessageRole(rawValue: roleString),
        let messageId = UUID(uuidString: idString)
      else {
        continue
      }
      
      // Load attachments for this message
      let attachments = try await getAttachmentsForMessage(messageId: idString)
      
      let message = await ChatMessage(
        id: messageId,
        role: role,
        content: messageRow[messageContentColumn],
        timestamp: messageRow[messageTimestampColumn],
        isComplete: messageRow[messageIsCompleteColumn],
        wasCancelled: messageRow[messageWasCancelledColumn],
        attachments: attachments.isEmpty ? nil : attachments
      )
      
      messages.append(message)
    }
    
    return messages
  }
  
  private func getAttachmentsForMessage(messageId: String) async throws -> [StoredAttachment] {
    var attachments = [StoredAttachment]()
    
    let query = attachmentsTable.filter(attachmentMessageIdColumn == messageId)
    
    for attachmentRow in try database.prepare(query) {
      let attachment = await StoredAttachment(
        fileName: attachmentRow[attachmentFileNameColumn],
        type: attachmentRow[attachmentFileTypeColumn],
        filePath: attachmentRow[attachmentFilePathColumn]
      )
      attachments.append(attachment)
    }
    
    return attachments
  }
}
