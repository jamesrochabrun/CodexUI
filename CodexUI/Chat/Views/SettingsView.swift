//
//  SettingsView.swift
//  CodexUI
//

import SwiftUI
import AppKit

struct SettingsView: View {

  @Environment(\.dismiss) private var dismiss
  @State private var settings = SettingsManager.shared
  @State private var showInvalidPathAlert = false

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Settings")
          .font(.title2)
          .fontWeight(.semibold)
        Spacer()
        Button(action: { dismiss() }) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding()

      Divider()

      // Content
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          projectPathSection
        }
        .padding()
      }

      Spacer()
    }
    .frame(width: 500, height: 300)
    .alert("Invalid Directory", isPresented: $showInvalidPathAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Please select a directory that is a Git repository (contains a .git folder).")
    }
  }

  private var projectPathSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Working Directory")
        .font(.headline)

      HStack(spacing: 12) {
        // Path display
        pathDisplay

        // Buttons
        Button("Browse") {
          selectDirectory()
        }
        .buttonStyle(.bordered)

        if !settings.projectPath.isEmpty {
          Button("Clear") {
            settings.clearProjectPath()
          }
          .buttonStyle(.bordered)
          .foregroundStyle(.red)
        }
      }

      // Status indicator
      statusIndicator

      Text("Select a Git repository to use as the working directory for Codex.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var pathDisplay: some View {
    HStack {
      if settings.projectPath.isEmpty {
        Text("No directory selected")
          .foregroundStyle(.secondary)
      } else {
        Image(systemName: "folder.fill")
          .foregroundStyle(.blue)
        Text(settings.projectPath)
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  @ViewBuilder
  private var statusIndicator: some View {
    if !settings.projectPath.isEmpty {
      HStack(spacing: 6) {
        if settings.isValidGitRepo(settings.projectPath) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text("Valid Git repository")
            .foregroundStyle(.green)
        } else {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
          Text("Not a Git repository")
            .foregroundStyle(.orange)
        }
      }
      .font(.caption)
    }
  }

  private func selectDirectory() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.message = "Select a Git repository as your working directory"
    panel.prompt = "Select"

    if panel.runModal() == .OK, let url = panel.url {
      let path = url.path

      if settings.isValidGitRepo(path) {
        settings.projectPath = path
      } else {
        showInvalidPathAlert = true
      }
    }
  }
}

#Preview {
  SettingsView()
}
