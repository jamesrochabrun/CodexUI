//
//  ChatMessageView.swift
//  CodexUI
//

import SwiftUI

struct ChatMessageView: View {

  let message: ChatMessage
  let projectPath: String

  /// Callback when user wants to expand a diff to full screen
  var onExpandDiff: ((DiffToolEvent) -> Void)?

  @Environment(\.colorScheme) private var colorScheme
  @State private var textFormatter: TextFormatter?
  @State private var containerWidth: CGFloat = 0
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Zero-height GeometryReader to capture width without affecting layout
      GeometryReader { geometry in
        Color.clear
          .onAppear { containerWidth = geometry.size.width }
          .onChange(of: geometry.size) { _, newSize in
            containerWidth = newSize.width
          }
      }
      .frame(height: 0)
      
      // Content determines its own height naturally
      messageContent(maxWidth: containerWidth - 24)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear {
      initializeTextFormatter()
    }
    .onChange(of: message.content) { _, newContent in
      handleContentChange(newContent: newContent)
    }
    .background(message.role == .user ? .black.opacity(0.1) : .clear)
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
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .top, spacing: 8) {
        Text(">")
          .font(.system(size: 13, design: .monospaced))
          .foregroundStyle(Color.Terminal.userPrompt)

        Text(message.content)
          .font(.system(size: 13, design: .monospaced))
          .textSelection(.enabled)
      }

      // Display attachments if present
      if let attachments = message.attachments, !attachments.isEmpty {
        AttachmentsSectionView(attachments: attachments)
          .padding(.top, 4)
      }
    }
    .padding(.vertical, 4)
  }
  
  @ViewBuilder
  private func assistantMessageView(maxWidth: CGFloat) -> some View {
    let (statusLines, assistantContent) = splitContent(message.content)

    VStack(alignment: .leading, spacing: 4) {
      // Terminal-style status lines (reasoning, commands, exit codes)
      if !statusLines.isEmpty {
        TerminalStatusView(lines: statusLines)
      }

      // Diff views for Edit/Write tool responses
      if let diffEvents = message.diffEvents, !diffEvents.isEmpty {
        let _ = print("[ChatMessageView] Message has \(diffEvents.count) diff events")
        DiffContentView(
          messageId: message.id,
          diffEvents: diffEvents,
          projectPath: projectPath,
          onExpandRequest: onExpandDiff
        )
        .padding(.vertical, 8)
      }

      // Assistant message with markdown rendering
      if !assistantContent.isEmpty {
        HStack(alignment: .top, spacing: 0) {
          // Use TextFormatter for markdown
          if let formatter = textFormatter {
            MessageTextFormatterView(
              textFormatter: formatter,
              message: message,
              fontSize: 14,
              horizontalPadding: 0,
              maxWidth: maxWidth
            )
          } else {
            Text(assistantContent)
              .font(.body)
              .textSelection(.enabled)
          }
        }
      }

      // Streaming cursor when no content yet
      if !message.isComplete && statusLines.isEmpty && assistantContent.isEmpty {
        BlinkingCursor()
      }
    }
    .padding(.vertical, 4)
  }
  
  // MARK: - Content Splitting
  
  /// Split content into status lines (*, $, ✓, !) and assistant content (◆)
  private func splitContent(_ content: String) -> (statusLines: [String], assistantContent: String) {
    var statusLines: [String] = []
    var assistantContent = ""
    
    for line in content.components(separatedBy: "\n") {
      if line.hasPrefix("◆ ") {
        // Strip prefix, accumulate for markdown rendering
        assistantContent += String(line.dropFirst(2)) + "\n"
      } else if line.hasPrefix("* ") || line.hasPrefix("$ ") ||
                  line.hasPrefix("✓ ") || line.hasPrefix("! ") ||
                  line.hasPrefix("  $ ") || line.hasPrefix("  ✓ ") || line.hasPrefix("  ! ") {
        statusLines.append(line)
      } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
        // Non-prefixed content goes to assistant (fallback)
        assistantContent += line + "\n"
      }
    }
    
    return (statusLines, assistantContent.trimmingCharacters(in: .whitespacesAndNewlines))
  }
  
  // MARK: - Private Methods
  
  private func initializeTextFormatter() {
    guard message.role == .assistant else { return }
    
    let formatter = TextFormatter(projectRoot: nil)
    // Extract only assistant content for the formatter
    let (_, assistantContent) = splitContent(message.content)
    if !assistantContent.isEmpty {
      formatter.ingest(delta: assistantContent)
    }
    textFormatter = formatter
  }
  
  private func handleContentChange(newContent: String) {
    guard message.role == .assistant, let formatter = textFormatter else { return }
    
    // Extract only assistant content for formatting
    let (_, assistantContent) = splitContent(newContent)
    
    let currentLength = formatter.deltas.joined().count
    if assistantContent.count > currentLength {
      let newDelta = String(assistantContent.dropFirst(currentLength))
      formatter.ingest(delta: newDelta)
    }
  }
  
}
