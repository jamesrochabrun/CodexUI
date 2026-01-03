//
//  FileResult+InlineSearchResult.swift
//  CodexUI
//

import SwiftUI

extension FileResult: InlineSearchResult {
  var title: String { fileName }
  var subtitle: String { filePath }

  var iconName: String {
    switch fileExtension {
    case "swift":
      return "swift"
    case "folder":
      return "folder"
    case "md":
      return "doc.richtext"
    case "json", "yml", "yaml", "xml":
      return "doc.badge.gearshape"
    default:
      return "doc.text"
    }
  }

  var iconColor: Color {
    switch fileExtension {
    case "swift":
      return .orange
    case "js", "jsx", "ts", "tsx":
      return .yellow
    case "py":
      return .blue
    case "rb":
      return .red
    case "go":
      return .cyan
    case "rs":
      return .brown
    case "java", "kt":
      return .purple
    case "cs":
      return .green
    case "md":
      return .gray
    default:
      return .secondary
    }
  }
}

extension FileSearchViewModel: InlineSearchViewModelProtocol {
  typealias Result = FileResult
}
