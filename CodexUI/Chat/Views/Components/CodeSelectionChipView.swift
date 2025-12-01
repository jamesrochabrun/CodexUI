//
//  CodeSelectionChipView.swift
//  CodexUI
//

import SwiftUI

/// Chip component for displaying code selections and active files
struct CodeSelectionChipView: View {
  
  let model: SelectionDisplayModel
  var onRemove: (() -> Void)?
  var isPinned: Bool = false
  var onTogglePin: (() -> Void)?
  
  var body: some View {
    HStack(spacing: 6) {
      // Language icon with color
      Image(systemName: model.languageIcon.name)
        .foregroundColor(model.languageIcon.color)
        .font(.system(size: 12))
      
      // File name + line range
      Text(model.displayText)
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
        .truncationMode(.middle)
      
      // Pin button (for active file only)
      if let onTogglePin = onTogglePin {
        Button(action: onTogglePin) {
          Image(systemName: isPinned ? "pin.fill" : "pin")
            .foregroundColor(isPinned ? .accentColor : .secondary.opacity(0.6))
            .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .help(isPinned ? "Unpin file" : "Pin file")
      }
      
      // Dismiss button
      if let onRemove = onRemove {
        Button(action: onRemove) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary.opacity(0.6))
            .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .help("Remove")
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.secondary.opacity(isPinned ? 0.15 : 0.1))
        .animation(.easeInOut(duration: 0.2), value: isPinned)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color.accentColor.opacity(isPinned ? 0.3 : 0), lineWidth: 1)
        .animation(.easeInOut(duration: 0.2), value: isPinned)
    )
  }
}

// MARK: - Preview

#Preview("Selection Chip") {
  VStack(spacing: 12) {
    // Swift file with line range
    CodeSelectionChipView(
      model: SelectionDisplayModel(
        id: UUID(),
        fileName: "ContentView.swift",
        filePath: "/path/to/ContentView.swift",
        lineRange: 42...56,
        selectedText: "some code"
      ),
      onRemove: {}
    )
    
    // Active file (no line range, with pin)
    CodeSelectionChipView(
      model: SelectionDisplayModel(
        id: UUID(),
        fileName: "AppDelegate.swift",
        filePath: "/path/to/AppDelegate.swift",
        lineRange: nil,
        selectedText: nil
      ),
      onRemove: {},
      isPinned: false,
      onTogglePin: {}
    )
    
    // Pinned active file
    CodeSelectionChipView(
      model: SelectionDisplayModel(
        id: UUID(),
        fileName: "ViewModel.swift",
        filePath: "/path/to/ViewModel.swift",
        lineRange: nil,
        selectedText: nil
      ),
      onRemove: {},
      isPinned: true,
      onTogglePin: {}
    )
    
    // Single line selection
    CodeSelectionChipView(
      model: SelectionDisplayModel(
        id: UUID(),
        fileName: "Utils.swift",
        filePath: "/path/to/Utils.swift",
        lineRange: 10...10,
        selectedText: "let x = 1"
      ),
      onRemove: {}
    )
  }
  .padding()
}
