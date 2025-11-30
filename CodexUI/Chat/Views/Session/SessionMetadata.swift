//
//  SessionMetadata.swift
//  CodexUI
//

import Foundation
import SwiftUI

// MARK: - SessionMetadata

struct SessionMetadata: View {
  let messageCount: Int
  let lastAccessedAt: Date
  let workingDirectory: String?
  let branchName: String?
  let isWorktree: Bool

  var body: some View {
    HStack(spacing: 8) {
      Text("\(messageCount) messages")
        .font(.caption)
        .foregroundColor(.secondary)

      // Show branch/worktree info if available
      if let branch = branchName {
        Text("•")
          .font(.caption)
          .foregroundColor(.secondary)

        HStack(spacing: 2) {
          Image(systemName: isWorktree ? "arrow.triangle.branch" : "arrow.branch")
            .font(.caption2)
          Text(branch)
            .font(.caption)
        }
        .foregroundColor(isWorktree ? Color.brandSecondary : Color.brandPrimary)
      }

      if let dir = workingDirectory, !dir.isEmpty {
        Text("•")
          .font(.caption)
          .foregroundColor(.secondary)

        HStack(spacing: 2) {
          Image(systemName: "folder")
            .font(.caption2)
          Text(dir.split(separator: "/").last.map(String.init) ?? "folder")
            .font(.caption)
        }
        .foregroundColor(.secondary)
      }
    }
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    SessionMetadata(
      messageCount: 5,
      lastAccessedAt: Date(),
      workingDirectory: "/Users/dev/project",
      branchName: "main",
      isWorktree: false
    )

    SessionMetadata(
      messageCount: 12,
      lastAccessedAt: Date(),
      workingDirectory: "/Users/dev/project-worktree",
      branchName: "feature/sessions",
      isWorktree: true
    )

    SessionMetadata(
      messageCount: 3,
      lastAccessedAt: Date(),
      workingDirectory: nil,
      branchName: nil,
      isWorktree: false
    )
  }
  .padding()
}
