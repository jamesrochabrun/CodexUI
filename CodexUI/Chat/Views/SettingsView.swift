//
//  SettingsView.swift
//  CodexUI
//

import SwiftUI
import AppKit
import Combine

struct SettingsView: View {

  @Environment(\.dismiss) private var dismiss
  @Environment(\.permissionsService) private var permissionsService
  @State private var settings = SettingsManager.shared
  @State private var showInvalidPathAlert = false
  @State private var isAccessibilityGranted = false
  @State private var cancellables = Set<AnyCancellable>()

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

          Divider()

          xcodeIntegrationSection
        }
        .padding()
      }

      Spacer()
    }
    .frame(width: 500, height: 400)
    .alert("Invalid Directory", isPresented: $showInvalidPathAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Please select a directory that is a Git repository (contains a .git folder).")
    }
    .onAppear {
      observePermissions()
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

  // MARK: - Xcode Integration

  private var xcodeIntegrationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Xcode Integration")
        .font(.headline)

      Text("Grant accessibility permissions to enable Xcode workspace observation, including active file detection and code selection tracking.")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 12) {
        // Status indicator
        HStack(spacing: 6) {
          if isAccessibilityGranted {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
            Text("Accessibility Enabled")
              .foregroundStyle(.green)
          } else {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
            Text("Accessibility Required")
              .foregroundStyle(.orange)
          }
        }
        .font(.subheadline)

        Spacer()

        if !isAccessibilityGranted {
          Button("Grant Permission") {
            permissionsService?.requestAccessibilityPermission()
          }
          .buttonStyle(.borderedProminent)
        }
      }

      if !isAccessibilityGranted {
        HStack(spacing: 4) {
          Text("Tip: If the permission dialog doesn't appear,")
            .font(.caption2)
            .foregroundStyle(.tertiary)

          Button("open System Settings") {
            NSWorkspace.shared.open(
              URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
          }
          .font(.caption2)
          .buttonStyle(.link)

          Text("and add CodexUI manually.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }

      Divider()
        .padding(.vertical, 4)

      // CMD+I Shortcut Toggle
      xcodeShortcutToggle
    }
  }

  private var xcodeShortcutToggle: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(isOn: Binding(
        get: { settings.enableXcodeShortcut },
        set: { settings.enableXcodeShortcut = $0 }
      )) {
        VStack(alignment: .leading, spacing: 2) {
          Text("CMD+I Text Capture")
            .font(.subheadline)
          Text("Press CMD+I in Xcode to capture selected text and bring it into CodexUI")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .toggleStyle(.switch)
      .disabled(!isAccessibilityGranted)

      if !isAccessibilityGranted {
        Text("Requires accessibility permission to be enabled")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
  }

  private func observePermissions() {
    permissionsService?.isAccessibilityPermissionGrantedCurrentValuePublisher
      .receive(on: DispatchQueue.main)
      .sink { granted in
        isAccessibilityGranted = granted
      }
      .store(in: &cancellables)
  }
}

#Preview {
  SettingsView()
}
