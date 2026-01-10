//
//  GitDiffView.swift
//  CodexUI
//

import SwiftUI
import PierreDiffsSwift

/// A diff view that uses git to get the original content for comparison
struct GitDiffView: View {

  // MARK: - Properties

  /// Absolute path to the changed file
  let filePath: String

  /// Project root directory (git repo root)
  let projectPath: String

  /// Callback when expand button is pressed
  var onExpandRequest: (() -> Void)?

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
    VStack(alignment: .leading, spacing: 0) {
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
          ),
          onExpandRequest: onExpandRequest
        )
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .task {
      await loadDiffContent()
    }
  }

  // MARK: - Subviews

  private var loadingView: some View {
    HStack {
      Spacer()
      VStack(spacing: 8) {
        ProgressView()
          .controlSize(.small)
        Text("Loading diff...")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding()
      Spacer()
    }
    .frame(minHeight: 100)
  }

  private func errorView(_ message: String) -> some View {
    HStack {
      Spacer()
      VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
          .font(.title2)
          .foregroundStyle(.orange)
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding()
      Spacer()
    }
    .frame(minHeight: 100)
  }

  private var noChangesView: some View {
    HStack {
      Spacer()
      VStack(spacing: 8) {
        Image(systemName: "checkmark.circle")
          .font(.title2)
          .foregroundStyle(.green)
        Text("No changes detected")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding()
      Spacer()
    }
    .frame(minHeight: 100)
  }

  // MARK: - Private Methods

  private func loadDiffContent() async {
    print("[GitDiffView] Loading diff for: \(filePath)")

    // Get original from git
    let original = await GitDiffProvider.getOriginalContent(
      filePath: filePath,
      projectPath: projectPath
    )

    // Get current from disk
    let current: String?
    do {
      current = try String(contentsOfFile: filePath, encoding: .utf8)
      print("[GitDiffView] Read current content: \(current?.count ?? 0) characters")
    } catch {
      print("[GitDiffView] Error reading file: \(error)")
      current = nil
    }

    await MainActor.run {
      if let currentContent = current {
        // If no git original, this might be a new file
        self.oldContent = original ?? ""
        self.newContent = currentContent

        if original == nil {
          print("[GitDiffView] No git history - treating as new file")
        }
      } else {
        self.errorMessage = "Could not read file"
      }
      self.isLoading = false
    }
  }
}
