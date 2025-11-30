//
//  NewSessionRow.swift
//  CodexUI
//

import Foundation
import SwiftUI

/// Row component for creating a new session
struct NewSessionRow: View {
  let defaultWorkingDirectory: String?
  let onTap: (String?) -> Void

  var body: some View {
    Button(action: {
      // Use default directory if set, otherwise nil
      onTap(defaultWorkingDirectory?.isEmpty == false ? defaultWorkingDirectory : nil)
    }) {
      HStack {
        Image(systemName: "plus.circle.fill")
          .foregroundColor(.brandPrimary)
          .font(.title3)

        VStack(alignment: .leading, spacing: 4) {
          Text("New Session")
            .font(.headline)
            .foregroundColor(.primary)
          if let defaultDir = defaultWorkingDirectory, !defaultDir.isEmpty {
            Text("Using: \(defaultDir.split(separator: "/").last.map(String.init) ?? "folder")")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text("Start fresh conversation")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
          .font(.caption)
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  VStack(spacing: 16) {
    NewSessionRow(
      defaultWorkingDirectory: "/Users/dev/project",
      onTap: { dir in print("New session with directory: \(dir ?? "none")") }
    )

    NewSessionRow(
      defaultWorkingDirectory: nil,
      onTap: { dir in print("New session with directory: \(dir ?? "none")") }
    )
  }
  .padding()
  .frame(width: 400)
}
