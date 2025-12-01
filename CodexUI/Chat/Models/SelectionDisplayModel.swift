//
//  SelectionDisplayModel.swift
//  CodexUI
//

import Foundation
import SwiftUI

/// Display model for transforming XcodeTextSelection and XcodeFileInfo into UI-friendly format
struct SelectionDisplayModel: Identifiable {
  let id: UUID
  let fileName: String
  let filePath: String
  let lineRange: ClosedRange<Int>?
  let selectedText: String?
  
  // MARK: - Factory Methods
  
  /// Create from XcodeTextSelection
  static func fromSelection(_ selection: XcodeTextSelection) -> SelectionDisplayModel {
    SelectionDisplayModel(
      id: selection.id,
      fileName: selection.fileName,
      filePath: selection.filePath,
      lineRange: selection.lineRange,
      selectedText: selection.selectedText
    )
  }
  
  /// Create from XcodeFileInfo (active file)
  static func fromFile(_ file: XcodeFileInfo) -> SelectionDisplayModel {
    SelectionDisplayModel(
      id: file.id,
      fileName: file.name,
      filePath: file.path,
      lineRange: nil,
      selectedText: nil
    )
  }
  
  // MARK: - Computed Properties
  
  /// Display text: "FileName.swift 42-56" or "FileName.swift 42" or just "FileName.swift"
  var displayText: String {
    guard let lineRange = lineRange else {
      return fileName
    }
    
    // Convert to 1-based line numbers for display
    let lower = lineRange.lowerBound
    let upper = lineRange.upperBound
    
    if lower == upper {
      return "\(fileName) \(lower)"
    } else {
      return "\(fileName) \(lower)-\(upper)"
    }
  }
  
  /// File extension for icon color mapping
  var fileExtension: String {
    URL(fileURLWithPath: filePath).pathExtension.lowercased()
  }
  
  /// Language icon configuration
  var languageIcon: (name: String, color: Color) {
    switch fileExtension {
    case "swift":
      return ("swift", .orange)
    case "js", "jsx":
      return ("curlybraces", .yellow)
    case "ts", "tsx":
      return ("curlybraces", .blue)
    case "py":
      return ("chevron.left.forwardslash.chevron.right", .green)
    case "rb":
      return ("diamond", .red)
    case "go":
      return ("chevron.left.forwardslash.chevron.right", .cyan)
    case "rs":
      return ("gearshape", .orange)
    case "java", "kt":
      return ("cup.and.saucer", .brown)
    case "c", "cpp", "h", "hpp", "m", "mm":
      return ("chevron.left.forwardslash.chevron.right", .purple)
    case "json":
      return ("curlybraces.square", .gray)
    case "xml", "plist":
      return ("chevron.left.slash.chevron.right", .orange)
    case "md", "txt":
      return ("doc.text", .gray)
    case "yml", "yaml":
      return ("list.bullet.indent", .pink)
    case "sh", "bash", "zsh":
      return ("terminal", .green)
    case "css", "scss", "sass":
      return ("paintbrush", .blue)
    case "html":
      return ("chevron.left.slash.chevron.right", .orange)
    default:
      return ("doc", .secondary)
    }
  }
}
