//
//  ChatInputView.swift
//  CodexUI
//

import SwiftUI

struct ChatInputView: View {

  // MARK: - Properties

  @Binding var text: String
  let isLoading: Bool
  let onSend: () -> Void
  let onCancel: () -> Void

  @FocusState private var isFocused: Bool
  @Binding var triggerFocus: Bool

  private let placeholder = "Type a message... (Enter to send, Shift+Enter for new line)"

  // MARK: - Constants

  private let textAreaEdgeInsets = EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 15)

  // MARK: - Initialization

  init(
    text: Binding<String>,
    isLoading: Bool,
    onSend: @escaping () -> Void,
    onCancel: @escaping () -> Void,
    triggerFocus: Binding<Bool> = .constant(false)
  ) {
    _text = text
    self.isLoading = isLoading
    self.onSend = onSend
    self.onCancel = onCancel
    _triggerFocus = triggerFocus
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      // Main input area
      VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
          HStack(alignment: .center) {
            attachmentButton
            textEditor
            actionButton
          }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(inputBorder)
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 12)
    }
  }
}

// MARK: - Main UI Components

extension ChatInputView {

  /// Attachment button (placeholder for future functionality)
  private var attachmentButton: some View {
    Button(action: {
      // TODO: Implement file attachment
    }) {
      Image(systemName: "paperclip")
        .foregroundColor(.brandTertiary)
    }
    .buttonStyle(.plain)
    .padding(.leading, 8)
    .help("Attach files")
  }

  /// Action button (send/cancel)
  private var actionButton: some View {
    Group {
      if isLoading {
        cancelButton
      } else {
        sendButton
      }
    }
  }

  /// Cancel request button
  private var cancelButton: some View {
    Button(action: {
      onCancel()
    }) {
      Image(systemName: "stop.fill")
        .foregroundColor(.warmCoral)
    }
    .padding(10)
    .buttonStyle(.plain)
  }

  /// Send message button
  private var sendButton: some View {
    Button(action: {
      sendMessage()
    }) {
      Image(systemName: "arrow.up.circle.fill")
        .foregroundColor(isTextEmpty ? .brandTertiary : .brandPrimary)
        .font(.title2)
    }
    .padding(10)
    .buttonStyle(.plain)
    .disabled(isTextEmpty)
  }

  /// Input area border
  private var inputBorder: some View {
    RoundedRectangle(cornerRadius: 12)
      .stroke(Color(NSColor.separatorColor), lineWidth: 1)
  }

  /// Placeholder view
  private var placeholderView: some View {
    Text(placeholder)
      .font(.body)
      .foregroundColor(.brandTertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .onTapGesture {
        isFocused = true
      }
  }
}

// MARK: - Text Editor

extension ChatInputView {

  /// Main text editor component
  private var textEditor: some View {
    ZStack(alignment: .center) {
      TextEditor(text: $text)
        .scrollContentBackground(.hidden)
        .focused($isFocused)
        .font(.body)
        .frame(minHeight: 20, maxHeight: 200)
        .fixedSize(horizontal: false, vertical: true)
        .padding(textAreaEdgeInsets)
        .onAppear {
          isFocused = true
        }
        .onChange(of: triggerFocus) { _, shouldFocus in
          if shouldFocus {
            isFocused = true
            triggerFocus = false
          }
        }
        .onKeyPress { key in
          handleKeyPress(key)
        }

      if text.isEmpty {
        placeholderView
          .padding(textAreaEdgeInsets)
          .padding(.leading, 4)
      }
    }
  }

  /// Handle keyboard events
  private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
    switch key.key {
    case .return:
      // Check if shift is pressed - if so, allow new line
      if key.modifiers.contains(.shift) {
        // Return .ignored to let TextEditor handle the newline insertion naturally
        return .ignored
      } else {
        // Don't send message if already loading/streaming
        if isLoading {
          return .handled  // Prevent any action including new line
        }
        // Send message on regular return (without shift)
        sendMessage()
        return .handled
      }
    case .escape:
      if isLoading {
        onCancel()
        return .handled
      }
      return .ignored
    default:
      return .ignored
    }
  }
}

// MARK: - Helper Properties

extension ChatInputView {

  /// Check if text is empty
  private var isTextEmpty: Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

// MARK: - Actions

extension ChatInputView {

  /// Send message
  private func sendMessage() {
    guard !isTextEmpty else { return }
    onSend()
    text = ""
  }
}
