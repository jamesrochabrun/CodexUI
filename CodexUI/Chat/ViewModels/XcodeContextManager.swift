//
//  XcodeContextManager.swift
//  CodexUI
//

import Foundation
import SwiftUI

/// Manages captured code selections and pinned active file for Xcode context
@Observable
@MainActor
final class XcodeContextManager {
  
  // MARK: - Properties
  
  /// Array of captured code selections
  private(set) var codeSelections: [XcodeTextSelection] = []
  
  /// Pinned active file (persists even when Xcode focus changes)
  private(set) var pinnedActiveFile: XcodeFileInfo?
  
  /// Whether active file is pinned
  private(set) var isPinnedActiveFile: Bool = false
  
  /// Maximum number of selections to keep
  private let maxSelections = 10
  
  // MARK: - Computed Properties
  
  /// Whether there are any code selections
  var hasSelections: Bool {
    !codeSelections.isEmpty
  }
  
  /// Whether there's any context to show (pinned file or selections)
  var hasContext: Bool {
    isPinnedActiveFile || !codeSelections.isEmpty
  }
  
  // MARK: - Selection Management
  
  /// Add a new selection (deduplicates by file+lineRange)
  func addSelection(_ selection: XcodeTextSelection) {
    // Remove duplicates with same file path and line range
    codeSelections.removeAll { existing in
      existing.filePath == selection.filePath &&
      existing.lineRange == selection.lineRange
    }
    
    // Insert at the beginning (most recent first)
    codeSelections.insert(selection, at: 0)
    
    // Maintain maximum limit
    if codeSelections.count > maxSelections {
      codeSelections = Array(codeSelections.prefix(maxSelections))
    }
  }
  
  /// Remove selection by ID
  func removeSelection(id: UUID) {
    codeSelections.removeAll { $0.id == id }
  }
  
  /// Clear all selections
  func clearAllSelections() {
    codeSelections.removeAll()
  }
  
  // MARK: - Active File Management
  
  /// Pin the current active file
  func pinActiveFile(_ file: XcodeFileInfo) {
    pinnedActiveFile = file
    isPinnedActiveFile = true
  }
  
  /// Unpin active file
  func unpinActiveFile() {
    pinnedActiveFile = nil
    isPinnedActiveFile = false
  }
  
  /// Toggle pin state for active file
  func togglePinActiveFile(currentFile: XcodeFileInfo?) {
    if isPinnedActiveFile {
      unpinActiveFile()
    } else if let file = currentFile {
      pinActiveFile(file)
    }
  }
  
  // MARK: - Context Formatting
  
  /// Get formatted context for sending with message
  func getFormattedContext() -> String {
    var contextParts: [String] = []
    
    // Add pinned file context
    if let pinnedFile = pinnedActiveFile, isPinnedActiveFile {
      var fileContext = "Active file: \(pinnedFile.name)"
      if let content = pinnedFile.content, !content.isEmpty {
        fileContext += "\n```\n\(content)\n```"
      }
      contextParts.append(fileContext)
    }
    
    // Add selection contexts
    for selection in codeSelections {
      let lineInfo = selection.lineRangeDescription
      var selectionContext = "Selection from \(selection.fileName) (\(lineInfo)):"
      selectionContext += "\n```\n\(selection.selectedText)\n```"
      contextParts.append(selectionContext)
    }
    
    return contextParts.joined(separator: "\n\n")
  }
  
  /// Clear all context (selections and pinned file)
  func clearAll() {
    clearAllSelections()
    unpinActiveFile()
  }
}
