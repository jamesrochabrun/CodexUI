//
//  ContextManager.swift
//  CodexUI
//

import Foundation
import SwiftUI

/// Manages the file context that will be included in chat messages
@Observable
@MainActor
public final class ContextManager {
  
  // MARK: - Observable Properties
  
  /// The current context model
  private(set) var context: ContextModel = ContextModel()
  
  // MARK: - Initialization
  
  init() {}
  
  // MARK: - Public Methods
  
  /// Manually adds a file to the context
  func addFile(_ file: FileInfo) {
    context.addFile(file)
  }
  
  /// Removes a specific file by ID
  func removeFile(id: UUID) {
    context.removeFile(id: id)
  }
  
  /// Clears all context
  func clearAll() {
    context.clear()
  }
  
  /// Gets the formatted context for inclusion in a prompt
  func getFormattedContext() -> String {
    context.buildPromptContext()
  }
  
  /// Checks if there's any context available
  var hasContext: Bool {
    !context.isEmpty()
  }
  
  /// Gets the context summary for UI display
  var contextSummary: String {
    context.summary
  }
  
  /// Returns all active files
  var activeFiles: [FileInfo] {
    context.activeFiles
  }
}
