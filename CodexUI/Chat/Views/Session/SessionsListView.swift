//
//  SessionsListView.swift
//  CodexUI
//

import Foundation
import SwiftUI

// MARK: - SessionsListView

struct SessionsListView: View {
  let availableSessions: [StoredSession]
  let currentSessionId: String?
  let defaultWorkingDirectory: String?
  let onStartNewSession: (String?) -> Void
  let onRestoreSession: (StoredSession) -> Void
  let onDeleteSession: (StoredSession) -> Void

  var body: some View {
    List {
      NewSessionRow(
        defaultWorkingDirectory: defaultWorkingDirectory,
        onTap: { directory in
          onStartNewSession(directory)
        }
      )

      if !availableSessions.isEmpty {
        Section("Previous Sessions") {
          ForEach(availableSessions) { session in
            SessionRow(
              session: session,
              isCurrentSession: session.id == currentSessionId,
              onTap: { onRestoreSession(session) },
              onDelete: { onDeleteSession(session) }
            )
            .listRowSeparator(.hidden)
          }
        }
      }
    }
  }
}

#Preview {
  SessionsListView(
    availableSessions: [
      StoredSession(
        id: "1",
        createdAt: Date(),
        firstUserMessage: "First session message",
        lastAccessedAt: Date(),
        messages: [ChatMessage(role: .user, content: "First session")],
        workingDirectory: "/Users/dev/project1",
        branchName: "main",
        isWorktree: false
      ),
      StoredSession(
        id: "2",
        createdAt: Date().addingTimeInterval(-3600),
        firstUserMessage: "Second session with a much longer message that should be truncated",
        lastAccessedAt: Date().addingTimeInterval(-3600),
        messages: [
          ChatMessage(role: .user, content: "Second session"),
          ChatMessage(role: .assistant, content: "Response")
        ],
        workingDirectory: "/Users/dev/project2",
        branchName: "feature/sessions",
        isWorktree: true
      )
    ],
    currentSessionId: "1",
    defaultWorkingDirectory: "/Users/dev/project1",
    onStartNewSession: { _ in },
    onRestoreSession: { _ in },
    onDeleteSession: { _ in }
  )
  .frame(width: 500, height: 400)
}
