//
//  CodexSQLiteMigrations.swift
//  CodexUI
//

import Foundation
import SQLite

// MARK: - DatabaseMigration Protocol

/// Protocol defining a database migration
protocol DatabaseMigration {
  /// The version this migration upgrades to
  var version: Int { get }
  
  /// Human-readable description of what this migration does
  var description: String { get }
  
  /// Execute the migration
  func migrate(database: Connection) async throws
  
  /// Rollback the migration (optional)
  func rollback(database: Connection) async throws
}

// Default implementation for rollback (most migrations don't need rollback)
extension DatabaseMigration {
  func rollback(database: Connection) async throws {
    // Default: no rollback available
    throw MigrationError.rollbackNotSupported(version: version)
  }
}

// MARK: - Migration Errors

enum MigrationError: LocalizedError {
  case invalidVersion(current: Int, target: Int)
  case migrationFailed(version: Int, underlying: Error)
  case backupFailed(Error)
  case rollbackNotSupported(version: Int)
  case databaseCorrupted
  
  var errorDescription: String? {
    switch self {
    case .invalidVersion(let current, let target):
      return "Invalid migration: current version \(current) cannot migrate to \(target)"
    case .migrationFailed(let version, let error):
      return "Migration to version \(version) failed: \(error.localizedDescription)"
    case .backupFailed(let error):
      return "Failed to backup database: \(error.localizedDescription)"
    case .rollbackNotSupported(let version):
      return "Rollback not supported for version \(version)"
    case .databaseCorrupted:
      return "Database appears to be corrupted"
    }
  }
}

// MARK: - Migration Manager

/// Manages database schema migrations for CodexSQLiteStorage
public actor CodexSQLiteMigrationManager {
  
  /// Current schema version - increment this when adding new migrations
  /// Version 1: Initial schema with sessions, messages, and attachments tables (includes worktree support)
  public static let CURRENT_SCHEMA_VERSION = 1
  
  private let database: Connection
  private let databasePath: String
  
  public init(database: Connection, databasePath: String) {
    self.database = database
    self.databasePath = databasePath
  }
  
  /// Get the current database schema version
  public func getCurrentVersion() throws -> Int {
    let version = try database.scalar("PRAGMA user_version") as? Int64 ?? 0
    return Int(version)
  }
  
  /// Set the database schema version
  private func setVersion(_ version: Int) throws {
    try database.execute("PRAGMA user_version = \(version)")
  }
  
  /// Run any pending migrations
  public func runMigrationsIfNeeded() async throws {
    let currentVersion = try getCurrentVersion()
        
    // Guard against downgrade attempts
    if currentVersion > CodexSQLiteMigrationManager.CURRENT_SCHEMA_VERSION {
      return
    }
    
    // If we're already at the current version, nothing to do
    if currentVersion == CodexSQLiteMigrationManager.CURRENT_SCHEMA_VERSION {
      return
    }
    
    // If this is a fresh database (version 0), just set to current version
    if currentVersion == 0 {
      try setVersion(CodexSQLiteMigrationManager.CURRENT_SCHEMA_VERSION)
      return
    }
    
    // Backup before migrations
    try await createBackup()
    
    // Get migrations to run
    let migrations = getMigrations(from: currentVersion, to: CodexSQLiteMigrationManager.CURRENT_SCHEMA_VERSION)
    
    if migrations.isEmpty {
      try setVersion(CodexSQLiteMigrationManager.CURRENT_SCHEMA_VERSION)
      return
    }
    
    // Run migrations sequentially
    try await runMigrations(migrations)
  }
  
  /// Get all migrations that need to run
  private func getMigrations(from currentVersion: Int, to targetVersion: Int) -> [DatabaseMigration] {
    let migrations: [DatabaseMigration] = []
    
    // Register migrations here as needed
    // Example:
    // if currentVersion < 2 {
    //   migrations.append(MigrationV2_AddNewColumn())
    // }
    
    return migrations
  }
  
  /// Run migrations sequentially
  private func runMigrations(_ migrations: [DatabaseMigration]) async throws {
    for migration in migrations {
      do {
        // Run migration
        try await migration.migrate(database: database)
        
        // Update version immediately after successful migration
        try await setVersion(migration.version)
        
      } catch {
        // Attempt rollback if available
        do {
          try await migration.rollback(database: database)
        } catch {
          print("[Migration] Rollback failed or not available: \(error)")
        }
        
        throw await MigrationError.migrationFailed(version: migration.version, underlying: error)
      }
    }
  }
  
  /// Create a backup of the database
  private func createBackup() async throws {
    let backupPath = databasePath + ".backup_\(Date().timeIntervalSince1970)"
        
    do {
      // SQLite backup using VACUUM INTO (creates a fresh, optimized copy)
      try database.execute("VACUUM INTO '\(backupPath)'")
    } catch {
      throw MigrationError.backupFailed(error)
    }
  }
  
  /// Validate database integrity
  public func validateDatabase() async throws {
    let result = try database.scalar("PRAGMA integrity_check") as? String
    
    if result != "ok" {
      throw MigrationError.databaseCorrupted
    }
  }
  
  /// Clean up old backup files (keep only last 3)
  public func cleanupOldBackups() async throws {
    let fileManager = FileManager.default
    let directory = URL(fileURLWithPath: databasePath).deletingLastPathComponent()
    
    do {
      let files = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.creationDateKey],
        options: .skipsHiddenFiles
      )
      
      // Filter backup files
      let backupFiles = files.filter { url in
        url.lastPathComponent.contains(".backup_")
      }
      
      // Sort by creation date (newest first)
      let sortedBackups = backupFiles.sorted { url1, url2 in
        let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
        let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
        return date1! > date2!
      }
      
      // Keep only the 3 most recent backups
      if sortedBackups.count > 3 {
        for backup in sortedBackups.dropFirst(3) {
          try fileManager.removeItem(at: backup)
        }
      }
    } catch {
      // Non-critical error, don't throw
    }
  }
}
