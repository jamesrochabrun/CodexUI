//
//  SessionRow.swift
//  CodexUI
//

import Foundation
import SwiftUI

// MARK: - SessionRow

struct SessionRow: View {
  let session: StoredSession
  let isCurrentSession: Bool
  let onTap: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack {
      Button(action: onTap) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(session.firstUserMessage.truncateIntelligently(to: 100))
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)

              if isCurrentSession {
                Image(systemName: "circle.fill")
                  .font(.caption2)
                  .foregroundColor(.brandTertiary)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SessionMetadata(
              messageCount: session.messages.count,
              lastAccessedAt: session.lastAccessedAt,
              workingDirectory: session.workingDirectory,
              branchName: session.branchName,
              isWorktree: session.isWorktree
            )
          }
          Spacer()
        }
        .padding(10)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onDelete) {
        Image(systemName: "trash")
          .font(.caption)
      }
      .buttonStyle(.plain)
      .padding(.leading, 8)
    }
    .padding(.horizontal, 8)
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(isCurrentSession ? Color.brandPrimary : Color.clear, lineWidth: isCurrentSession ? 1 : 0)
    )
  }

  @Environment(\.colorScheme) private var colorScheme
}

#Preview {
  VStack(spacing: 16) {
    // Current session
    SessionRow(
      session: StoredSession(
        id: UUID().uuidString,
        createdAt: Date(),
        firstUserMessage: "Help me implement a new feature for handling git worktrees",
        lastAccessedAt: Date(),
        messages: [
          ChatMessage(role: .user, content: "Help me implement a new feature"),
          ChatMessage(role: .assistant, content: "I'll help you implement that."),
          ChatMessage(role: .user, content: "Can you show me how?")
        ],
        workingDirectory: "/Users/dev/project",
        branchName: "feature/worktree-support",
        isWorktree: true
      ),
      isCurrentSession: true,
      onTap: { print("Tapped current session") },
      onDelete: { print("Delete current session") }
    )

    // Regular session
    SessionRow(
      session: StoredSession(
        id: UUID().uuidString,
        createdAt: Date().addingTimeInterval(-3600),
        firstUserMessage: "Fix the navigation bug in the sidebar",
        lastAccessedAt: Date().addingTimeInterval(-3600),
        messages: [
          ChatMessage(role: .user, content: "Fix the navigation bug"),
          ChatMessage(role: .assistant, content: "I'll help you fix that.")
        ],
        workingDirectory: "/Users/dev/project",
        branchName: "main",
        isWorktree: false
      ),
      isCurrentSession: false,
      onTap: { print("Tapped session") },
      onDelete: { print("Delete session") }
    )

    Spacer()
  }
  .padding()
  .frame(width: 500)
}
