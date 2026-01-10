//
//  DiffModalView.swift
//  CodexUI
//

import SwiftUI
import PierreDiffsSwift

/// Full-screen modal view for expanded diff viewing
struct DiffModalView: View {

  // MARK: - Properties

  let filePath: String
  let projectPath: String
  let baselineContent: String
  let useGitHead: Bool
  let onDismiss: () -> Void

  // MARK: - State

  @State private var oldContent: String = ""
  @State private var newContent: String = ""
  @State private var isLoading = true
  @State private var errorMessage: String?

  // MARK: - Computed

  private var fileName: String {
    URL(fileURLWithPath: filePath).lastPathComponent
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      // Close button bar
      HStack {
        Spacer()
        Button(action: onDismiss) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Close")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

      // Content
      if isLoading {
        loadingView
      } else if let error = errorMessage {
        errorView(error)
      } else if oldContent == newContent {
        noChangesView
      } else {
        DiffEditsView(
          input: .direct(
            oldContent: oldContent,
            newContent: newContent,
            fileName: fileName
          )
        )
      }
    }
    .background(Color(NSColor.windowBackgroundColor))
    .task {
      await loadDiffContent()
    }
  }

  // MARK: - Subviews

  private var loadingView: some View {
    VStack {
      Spacer()
      VStack(spacing: 12) {
        ProgressView()
          .controlSize(.regular)
        Text("Loading diff...")
          .font(.body)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func errorView(_ message: String) -> some View {
    VStack {
      Spacer()
      VStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle")
          .font(.largeTitle)
          .foregroundStyle(.orange)
        Text(message)
          .font(.body)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var noChangesView: some View {
    VStack {
      Spacer()
      VStack(spacing: 12) {
        Image(systemName: "checkmark.circle")
          .font(.largeTitle)
          .foregroundStyle(.green)
        Text("No changes detected")
          .font(.body)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Private Methods

  private func loadDiffContent() async {
    print("[DiffModalView] Loading diff for: \(filePath) (useGitHead: \(useGitHead))")

    // Get baseline content
    let original: String
    if useGitHead {
      // First turn: use git HEAD as baseline
      let gitContent = await GitDiffProvider.getOriginalContent(
        filePath: filePath,
        projectPath: projectPath
      )
      original = gitContent ?? ""
      print("[DiffModalView] Using git HEAD as baseline (\(original.count) chars)")
    } else {
      // Subsequent turns: use stored baseline from previous turn
      original = baselineContent
      print("[DiffModalView] Using stored baseline (\(original.count) chars)")
    }

    // Get current from disk
    let current: String?
    do {
      current = try String(contentsOfFile: filePath, encoding: .utf8)
      print("[DiffModalView] Read current content: \(current?.count ?? 0) characters")
    } catch {
      print("[DiffModalView] Error reading file: \(error)")
      current = nil
    }

    await MainActor.run {
      if let currentContent = current {
        self.oldContent = original
        self.newContent = currentContent
      } else {
        self.errorMessage = "Could not read file"
      }
      self.isLoading = false
    }
  }
}
