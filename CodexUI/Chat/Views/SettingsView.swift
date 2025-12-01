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
  @State private var featuresManager = FeaturesManager.shared
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
          xcodeIntegrationSection

          Divider()

          globalFeaturesSection
        }
        .padding()
      }

      Spacer()
    }
    .frame(width: 500, height: 550)
    .onAppear {
      observePermissions()
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

  // MARK: - Global Features

  private var globalFeaturesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Global Features")
        .font(.headline)

      Text("These settings apply to all Codex sessions regardless of the selected profile.")
        .font(.caption)
        .foregroundStyle(.secondary)

      // Standard features (always visible)
      ForEach(CodexFeature.standard) { feature in
        featureToggle(for: feature)
      }

      // Advanced settings toggle
      advancedSettingsSection
    }
  }

  private func featureToggle(for feature: CodexFeature) -> some View {
    Toggle(isOn: Binding(
      get: { featuresManager.isEnabled(feature.id) },
      set: { featuresManager.setEnabled($0, for: feature.id) }
    )) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(feature.name)
            .font(.subheadline)
          if feature.isExperimental {
            Text("experimental")
              .font(.caption2)
              .foregroundStyle(.orange)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.orange.opacity(0.15))
              .clipShape(Capsule())
          }
        }
        Text(feature.description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .toggleStyle(.switch)
  }

  private var advancedSettingsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(isOn: $featuresManager.showAdvancedSettings) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Show Advanced Settings")
            .font(.subheadline)
          Text("Display experimental features (may be unstable)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .toggleStyle(.switch)

      if featuresManager.showAdvancedSettings {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(CodexFeature.experimental) { feature in
            featureToggle(for: feature)
          }
        }
        .padding(.leading, 16)
        .padding(.top, 4)
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
