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

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
        terminalLine(line)
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.adaptiveBackground(for: colorScheme))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private func terminalLine(_ line: String) -> some View {
    let parsed = parsePrefix(line)

    HStack(alignment: .top, spacing: 0) {
      // Indentation for child events (commands under reasoning)
      if parsed.isIndented {
        Text("  ")
          .foregroundStyle(.clear)
      }

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

  /// Parse a line into its prefix, content, color, and whether it's indented
  private func parsePrefix(_ line: String) -> (prefix: String, content: String, color: Color, isIndented: Bool) {
    // Check each prefix pattern (status lines only)
    // Indented versions must come first to match before non-indented
    let prefixPatterns: [(String, Color)] = [
      ("  $ ", Color.Terminal.command),   // Indented command execution
      ("  ✓ ", Color.Terminal.success),   // Indented success
      ("  ! ", Color.Terminal.error),     // Indented error/failure
      ("* ", Color.Terminal.reasoning),   // Reasoning/thinking
      ("$ ", Color.Terminal.command),     // Command execution
      ("✓ ", Color.Terminal.success),     // Success
      ("! ", Color.Terminal.error),       // Error/failure
    ]

    for (prefix, color) in prefixPatterns {
      if line.hasPrefix(prefix) {
        let content = String(line.dropFirst(prefix.count))
        let isIndented = prefix.hasPrefix("  ")
        // For indented prefixes, just return the symbol (indentation handled by view)
        let displayPrefix = isIndented ? String(prefix.trimmingCharacters(in: .whitespaces).first!) : String(prefix.first!)
        return (displayPrefix, content, color, isIndented)
      }
    }

    // No prefix found - return as plain content
    return (" ", line, .primary, false)
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
        "  $ git status",
        "* Found 15 Swift files",
        "  $ npm install",
      ]
    )
  }
  .padding()
  .frame(width: 500)
}
