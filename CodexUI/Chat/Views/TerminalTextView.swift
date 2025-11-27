//
//  TerminalTextView.swift
//  CodexUI
//
//  Terminal-style text rendering with colorized prefixes for status events.
//

import SwiftUI

/// Terminal-style view for status lines (reasoning, commands, exit codes)
/// Only handles *, $, ✓, ! prefixes - assistant content (◆) is rendered separately with markdown
struct TerminalStatusView: View {
  let lines: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
        terminalLine(line)
      }
    }
  }

  @ViewBuilder
  private func terminalLine(_ line: String) -> some View {
    let parsed = parsePrefix(line)

    HStack(alignment: .top, spacing: 0) {
      // Prefix with color
      Text(parsed.prefix)
        .foregroundStyle(parsed.color)
        .frame(width: 16, alignment: .leading)

      // Content
      Text(parsed.content)
        .textSelection(.enabled)
    }
    .font(.system(size: 13, design: .monospaced))
  }

  /// Parse a line into its prefix and content, returning the appropriate color
  private func parsePrefix(_ line: String) -> (prefix: String, content: String, color: Color) {
    // Check each prefix pattern (status lines only)
    let prefixPatterns: [(String, Color)] = [
      ("* ", Color.Terminal.reasoning),   // Reasoning/thinking
      ("$ ", Color.Terminal.command),     // Command execution
      ("✓ ", Color.Terminal.success),     // Success
      ("! ", Color.Terminal.error),       // Error/failure
    ]

    for (prefix, color) in prefixPatterns {
      if line.hasPrefix(prefix) {
        let content = String(line.dropFirst(prefix.count))
        return (String(prefix.first!), content, color)
      }
    }

    // No prefix found - return as plain content
    return (" ", line, .primary)
  }
}

/// Blinking cursor for streaming indication
struct BlinkingCursor: View {
  @State private var isVisible = true

  var body: some View {
    Text("▋")
      .font(.system(size: 13, design: .monospaced))
      .foregroundStyle(Color.Terminal.assistant)
      .opacity(isVisible ? 1 : 0)
      .onAppear {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
          isVisible = false
        }
      }
  }
}

#Preview("Terminal Status View") {
  VStack(alignment: .leading, spacing: 16) {
    TerminalStatusView(
      lines: [
        "* Analyzing the codebase structure",
        "* Found 15 Swift files",
        "$ git status",
        "✓ exit 0",
        "$ npm install",
        "! exit 1",
      ]
    )
    .padding()
    .background(Color.backgroundDark)
  }
  .frame(width: 500)
}
