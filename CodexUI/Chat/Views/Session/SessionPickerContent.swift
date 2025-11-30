//
//  SessionPickerContent.swift
//  CodexUI
//

import Foundation
import SwiftUI

// MARK: - SessionPickerContent

struct SessionPickerContent: View {
  let sessions: [StoredSession]
  let currentSessionId: String?
  let isLoading: Bool
  let error: String?
  let defaultWorkingDirectory: String?
  let onStartNewSession: (String?) -> Void
  let onRestoreSession: (StoredSession) -> Void
  let onDeleteSession: (StoredSession) -> Void
  let onDeleteAllSessions: () -> Void
  let onDismiss: () -> Void

  @State private var showDeleteAllConfirmation = false

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Sessions")
          .font(.headline)

        Spacer()

        if !sessions.isEmpty {
          Button(action: { showDeleteAllConfirmation = true }) {
            Image(systemName: "trash")
              .font(.caption)
          }
          .buttonStyle(.plain)
          .foregroundColor(.secondary)
          .help("Delete all sessions")
        }

        Button(action: onDismiss) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding()

      Divider()

      // Content
      if isLoading {
        loadingView
      } else if let error = error {
        errorView(error)
      } else {
        SessionsListView(
          availableSessions: sessions,
          currentSessionId: currentSessionId,
          defaultWorkingDirectory: defaultWorkingDirectory,
          onStartNewSession: { dir in
            onStartNewSession(dir)
            onDismiss()
          },
          onRestoreSession: { session in
            onRestoreSession(session)
            onDismiss()
          },
          onDeleteSession: onDeleteSession
        )
      }
    }
    .frame(minWidth: 400, minHeight: 300)
    .alert("Delete All Sessions", isPresented: $showDeleteAllConfirmation) {
      Button("Cancel", role: .cancel) { }
      Button("Delete All", role: .destructive) {
        onDeleteAllSessions()
      }
    } message: {
      Text("Are you sure you want to delete all \(sessions.count) sessions? This cannot be undone.")
    }
  }

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .controlSize(.large)
      Text("Loading sessions...")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func errorView(_ message: String) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundColor(.goldenAmber)
      Text("Failed to load sessions")
        .font(.headline)
      Text(message)
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview("Loading") {
  SessionPickerContent(
    sessions: [],
    currentSessionId: nil,
    isLoading: true,
    error: nil,
    defaultWorkingDirectory: nil,
    onStartNewSession: { _ in },
    onRestoreSession: { _ in },
    onDeleteSession: { _ in },
    onDeleteAllSessions: { },
    onDismiss: { }
  )
}

#Preview("Error") {
  SessionPickerContent(
    sessions: [],
    currentSessionId: nil,
    isLoading: false,
    error: "Could not connect to database",
    defaultWorkingDirectory: nil,
    onStartNewSession: { _ in },
    onRestoreSession: { _ in },
    onDeleteSession: { _ in },
    onDeleteAllSessions: { },
    onDismiss: { }
  )
}

#Preview("With Sessions") {
  SessionPickerContent(
    sessions: [
      StoredSession(
        id: "1",
        createdAt: Date(),
        firstUserMessage: "First session",
        lastAccessedAt: Date(),
        messages: [ChatMessage(role: .user, content: "Hello")],
        workingDirectory: "/Users/dev/project",
        branchName: "main",
        isWorktree: false
      ),
      StoredSession(
        id: "2",
        createdAt: Date().addingTimeInterval(-3600),
        firstUserMessage: "Second session with longer text",
        lastAccessedAt: Date().addingTimeInterval(-3600),
        messages: [
          ChatMessage(role: .user, content: "Second"),
          ChatMessage(role: .assistant, content: "Response")
        ],
        workingDirectory: "/Users/dev/project2",
        branchName: "feature/test",
        isWorktree: true
      )
    ],
    currentSessionId: "1",
    isLoading: false,
    error: nil,
    defaultWorkingDirectory: "/Users/dev/project",
    onStartNewSession: { _ in },
    onRestoreSession: { _ in },
    onDeleteSession: { _ in },
    onDeleteAllSessions: { },
    onDismiss: { }
  )
}
