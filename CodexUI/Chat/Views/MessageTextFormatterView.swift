//
//  MessageTextFormatterView.swift
//  CodexUI
//

import AppKit
import Down
import SwiftUI

struct MessageTextFormatterView: View {
  let textFormatter: TextFormatter
  let message: ChatMessage
  let fontSize: Double
  let horizontalPadding: CGFloat
  let maxWidth: CGFloat

  @Environment(\.colorScheme) private var colorScheme

  init(
    textFormatter: TextFormatter,
    message: ChatMessage,
    fontSize: Double = 14,
    horizontalPadding: CGFloat = 0,
    maxWidth: CGFloat = 600
  ) {
    self.textFormatter = textFormatter
    self.message = message
    self.fontSize = fontSize
    self.horizontalPadding = horizontalPadding
    self.maxWidth = maxWidth
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(textFormatter.elements) { element in
        textElementView(element)
      }

      // Show loading indicator if still streaming
      if !message.isComplete && textFormatter.elements.isEmpty {
        MessageLoadingIndicator(messageTint: messageTint)
      }

      // Show cancelled indicator if message was cancelled
      if message.wasCancelled {
        HStack {
          Text("Interrupted by user")
            .font(.system(size: fontSize - 1))
            .foregroundColor(.warmCoral)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
        }
      }
    }
  }

  @ViewBuilder
  private func textElementView(_ element: TextFormatter.Element) -> some View {
    switch element {
    case .text(let text):
      let attributedText = message.role == .user ? plainText(for: text) : markdown(for: text)
      LongText(attributedText, maxWidth: maxWidth - 2 * horizontalPadding)
        .textSelection(.enabled)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)

    case .codeBlock(let code):
      CodeBlockContentView(code: code, role: message.role)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)

    case .table(let table):
      TableContentView(table: table, role: message.role)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
  }

  @MainActor
  private func markdown(for text: TextFormatter.Element.TextElement) -> AttributedString {
    let markDown = Down(markdownString: text.text)
    do {
      let downStyle = makeMarkdownStyle(colorScheme: colorScheme)
      let attributedString = try markDown.toAttributedString(using: downStyle)
      return AttributedString(attributedString.trimmedAttributedString())
    } catch {
      print("Error parsing markdown: \(error)")
      return AttributedString(text.text)
    }
  }

  private func plainText(for text: TextFormatter.Element.TextElement) -> AttributedString {
    let style = MarkdownStyle(colorScheme: colorScheme)
    var attrs = AttributedString(text.text)
    attrs.foregroundColor = SwiftUI.Color(style.baseFontColor)
    attrs.font = Font(style.baseFont as CTFont)
    return attrs
  }

  private var messageTint: SwiftUI.Color {
    message.role == .assistant
      ? Color.brandSecondary
      : Color.brandPrimary
  }
}

struct MessageLoadingIndicator: View {
  let messageTint: SwiftUI.Color
  @State private var animationValues: [Bool] = [false, false, false]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<3) { index in
        Circle()
          .fill(
            LinearGradient(
              colors: [messageTint, messageTint.opacity(0.6)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 8, height: 8)
          .scaleEffect(animationValues[index] ? 1.2 : 0.8)
          .animation(
            Animation.easeInOut(duration: 0.6)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.15),
            value: animationValues[index]
          )
          .onAppear {
            animationValues[index].toggle()
          }
      }
    }
    .padding(.vertical, 4)
  }
}
