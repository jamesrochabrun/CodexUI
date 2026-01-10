//
//  DiffContentView.swift
//  CodexUI
//

import SwiftUI

/// A container view that renders diff events for a message using git-based comparison
struct DiffContentView: View {

  // MARK: - Properties

  let messageId: UUID
  let diffEvents: [DiffToolEvent]
  let projectPath: String

  /// Callback when user wants to expand a diff to full screen
  var onExpandRequest: ((DiffToolEvent) -> Void)?

  // MARK: - Body

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(diffEvents) { event in
        if let filePath = event.toolParameters["file_path"] {
          GitDiffView(
            filePath: filePath,
            projectPath: projectPath,
            onExpandRequest: {
              onExpandRequest?(event)
            }
          )
          .frame(minHeight: 300)  // Ensure WebView has room to render
          .id(event.id)  // Force view recreation on event change
          .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity
          ))
          .onAppear {
            print("[DiffContentView] Rendering git diff for: \(filePath)")
          }
        }
      }
    }
    .animation(.easeInOut(duration: 0.2), value: diffEvents.count)
    .onAppear {
      print("[DiffContentView] Rendering \(diffEvents.count) diff events")
    }
  }
}
