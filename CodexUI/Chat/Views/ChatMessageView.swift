//
//  ChatMessageView.swift
//  CodexUI
//

import SwiftUI

struct ChatMessageView: View {

  let message: ChatMessage

  @Environment(\.colorScheme) private var colorScheme
  @State private var textFormatter: TextFormatter?

  var body: some View {
    GeometryReader { geometry in
      VStack(alignment: .leading, spacing: 0) {
        messageContent(maxWidth: geometry.size.width - 24)  // Account for horizontal padding
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(minHeight: estimatedHeight)
    .onAppear {
      initializeTextFormatter()
    }
    .onChange(of: message.content) { _, newContent in
      handleContentChange(newContent: newContent)
    }
  }

  @ViewBuilder
  private func messageContent(maxWidth: CGFloat) -> some View {
    switch message.role {
    case .user:
      userMessageView
    case .assistant:
      assistantMessageView(maxWidth: maxWidth)
    }
  }

  private var userMessageView: some View {
    HStack(alignment: .top, spacing: 8) {
      Text(">")
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.secondary)

      Text(message.content)
        .font(.body)
        .textSelection(.enabled)
    }
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private func assistantMessageView(maxWidth: CGFloat) -> some View {
    if let formatter = textFormatter {
      MessageTextFormatterView(
        textFormatter: formatter,
        message: message,
        fontSize: 14,
        horizontalPadding: 0,
        maxWidth: maxWidth
      )
    } else {
      // Fallback to plain text while formatter initializes
      Text(message.content)
        .font(.body)
        .textSelection(.enabled)
        .padding(.vertical, 8)
    }
  }

  // MARK: - Private Methods

  private func initializeTextFormatter() {
    guard message.role == .assistant else { return }

    let formatter = TextFormatter(projectRoot: nil)
    if !message.content.isEmpty {
      formatter.ingest(delta: message.content)
    }
    textFormatter = formatter
  }

  private func handleContentChange(newContent: String) {
    guard message.role == .assistant, let formatter = textFormatter else { return }

    // Calculate the delta (new content since last update)
    let currentLength = formatter.deltas.joined().count
    if newContent.count > currentLength {
      let newDelta = String(newContent.dropFirst(currentLength))
      formatter.ingest(delta: newDelta)
    }
  }

  /// Estimate minimum height based on content
  private var estimatedHeight: CGFloat {
    let lineCount = message.content.components(separatedBy: .newlines).count
    let hasCodeBlocks = message.content.contains("```")

    // Base height per line
    var height: CGFloat = CGFloat(lineCount) * 20

    // Add extra height for code blocks
    if hasCodeBlocks {
      let codeBlockCount = message.content.components(separatedBy: "```").count / 2
      height += CGFloat(codeBlockCount) * 100
    }

    // Minimum heights
    return max(height, message.role == .user ? 44 : 60)
  }
}
