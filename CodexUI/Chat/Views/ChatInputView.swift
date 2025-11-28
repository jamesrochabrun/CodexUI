//
//  ChatInputView.swift
//  CodexUI
//

import SwiftUI

struct ChatInputView: View {

  // MARK: - Properties

  @Binding var text: String
  let isLoading: Bool
  let contextManager: ContextManager
  let projectPath: String
  let onSend: () -> Void
  let onCancel: () -> Void

  @FocusState private var isFocused: Bool
  @Binding var triggerFocus: Bool

  private let placeholder = "Type @ to search files... (Enter to send, Shift+Enter for new line)"

  // File search properties
  @State private var showingFileSearch = false
  @State private var fileSearchRange: NSRange? = nil
  @State private var fileSearchViewModel: FileSearchViewModel? = nil
  @State private var isUpdatingFileSearch = false

  // MARK: - Constants

  private let textAreaEdgeInsets = EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 15)

  // MARK: - Initialization

  init(
    text: Binding<String>,
    isLoading: Bool,
    contextManager: ContextManager,
    projectPath: String,
    onSend: @escaping () -> Void,
    onCancel: @escaping () -> Void,
    triggerFocus: Binding<Bool> = .constant(false)
  ) {
    _text = text
    self.isLoading = isLoading
    self.contextManager = contextManager
    self.projectPath = projectPath
    self.onSend = onSend
    self.onCancel = onCancel
    _triggerFocus = triggerFocus
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      // File search UI - shown when @ is typed
      if showingFileSearch {
        if let viewModel = fileSearchViewModel {
          InlineFileSearchView(
            viewModel: viewModel,
            onSelect: { result in
              insertFileReference(result)
            },
            onDismiss: {
              dismissFileSearch()
            }
          )
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color(NSColor.separatorColor), lineWidth: 1)
          )
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
          .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
          ))
        }
      }

      // Main input area
      VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
          // Context bar showing selected files
          if contextManager.hasContext {
            contextBar
          }
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
    .animation(.easeInOut(duration: 0.2), value: showingFileSearch)
    .animation(.easeInOut(duration: 0.2), value: contextManager.hasContext)
    .onAppear {
      // Initialize file search view model
      if fileSearchViewModel == nil {
        fileSearchViewModel = FileSearchViewModel(projectPath: projectPath)
      }
      // Update project path if it changed
      if !projectPath.isEmpty {
        fileSearchViewModel?.updateProjectPath(projectPath)
      }
    }
    .onChange(of: projectPath) { _, newValue in
      if !newValue.isEmpty {
        fileSearchViewModel?.updateProjectPath(newValue)
      }
    }
  }
}

// MARK: - Context Bar

extension ChatInputView {

  /// Context bar showing selected files
  private var contextBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(contextManager.activeFiles) { file in
          fileChip(for: file)
        }
      }
      .padding(.horizontal, 4)
    }
    .padding(.top, 6)
    .padding(.horizontal, 4)
    .transition(.asymmetric(
      insertion: .move(edge: .top).combined(with: .opacity),
      removal: .move(edge: .top).combined(with: .opacity)
    ))
  }

  private func fileChip(for file: FileInfo) -> some View {
    HStack(spacing: 4) {
      Image(systemName: "doc.text")
        .font(.caption2)
        .foregroundColor(.brandPrimary)

      Text(file.name)
        .font(.caption)
        .lineLimit(1)

      Button(action: {
        contextManager.removeFile(id: file.id)
      }) {
        Image(systemName: "xmark.circle.fill")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.brandPrimary.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 6))
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
        .onChange(of: text) { oldValue, newValue in
          // Simple check to avoid freezing
          if newValue.count > 1000 {
            print("[ChatInputView] Text too long, skipping @ detection")
            return
          }
          detectAtMention(oldText: oldValue, newText: newValue)
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
    // When file search is showing, handle navigation keys
    if showingFileSearch {
      switch key.key {
      case .return:
        if let result = fileSearchViewModel?.getSelectedResult() {
          insertFileReference(result)
        }
        return .handled
      case .escape:
        dismissFileSearch()
        return .handled
      case .downArrow:
        fileSearchViewModel?.selectNext()
        return .handled
      case .upArrow:
        fileSearchViewModel?.selectPrevious()
        return .handled
      default:
        return .ignored
      }
    } else {
      // Normal text editor behavior
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
    // Clear context after sending
    contextManager.clearAll()
  }
}

// MARK: - File Search

extension ChatInputView {

  /// Detect @ mention in text and trigger file search
  private func detectAtMention(oldText: String, newText: String) {
    // Prevent recursive updates
    guard !isUpdatingFileSearch else {
      return
    }

    // If text was deleted and we're showing search, check if @ was deleted
    if showingFileSearch && newText.count < oldText.count {
      // Check if the @ character is still present at the search location
      if let searchRange = fileSearchRange {
        let nsString = newText as NSString
        if searchRange.location >= nsString.length ||
            (searchRange.location < nsString.length && nsString.character(at: searchRange.location) != 64) { // 64 is @
          dismissFileSearch()
          return
        }
      }
    }

    // Check if @ was just typed
    let oldCount = oldText.filter { $0 == "@" }.count
    let newCount = newText.filter { $0 == "@" }.count

    if newCount > oldCount {
      // Find the position of the newly typed @
      if let atIndex = findNewAtPosition(oldText: oldText, newText: newText) {
        // Start file search
        fileSearchRange = NSRange(location: atIndex, length: 1)
        showingFileSearch = true
        fileSearchViewModel?.startSearch(query: "")
      }
    } else if showingFileSearch && !newText.isEmpty {
      // Update search query if we're already searching
      updateFileSearchQuery()
    } else if newText.isEmpty && showingFileSearch {
      // All text deleted, dismiss search
      dismissFileSearch()
    }
  }

  /// Find position of newly typed @ character
  private func findNewAtPosition(oldText: String, newText: String) -> Int? {
    let oldChars = Array(oldText)
    let newChars = Array(newText)

    // Find where the texts differ
    var i = 0
    while i < oldChars.count && i < newChars.count && oldChars[i] == newChars[i] {
      i += 1
    }

    // Check if @ was inserted at position i
    if i < newChars.count && newChars[i] == "@" {
      return i
    }

    return nil
  }

  /// Update file search query based on text after @
  private func updateFileSearchQuery() {
    guard let searchRange = fileSearchRange else { return }

    // Validate search range
    let nsString = text as NSString
    guard searchRange.location < nsString.length else {
      dismissFileSearch()
      return
    }

    // The search range starts at @ character
    let atLocation = searchRange.location

    // Find the end of the search query (until space, newline, or end of text)
    var queryEnd = atLocation + 1 // Start after the @ symbol
    while queryEnd < nsString.length {
      let char = nsString.character(at: queryEnd)
      if char == 32 || char == 10 { // space or newline
        break
      }
      queryEnd += 1
    }

    // Extract the full query after @ (not including @)
    let queryStart = atLocation + 1
    let queryLength = queryEnd - queryStart

    if queryStart <= nsString.length && queryLength >= 0 && queryStart + queryLength <= nsString.length {
      let query = nsString.substring(with: NSRange(location: queryStart, length: queryLength))
      fileSearchViewModel?.searchQuery = query

      // Update the search range to include @ and the query
      fileSearchRange = NSRange(location: atLocation, length: queryEnd - atLocation)
    }
  }

  /// Insert selected file reference into text
  private func insertFileReference(_ result: FileResult) {
    guard let searchRange = fileSearchRange else { return }

    // Validate that the range is still valid
    let nsString = text as NSString
    guard searchRange.location >= 0,
          searchRange.location + searchRange.length <= nsString.length else {
      dismissFileSearch()
      return
    }

    // Set flag to prevent onChange from triggering file search
    isUpdatingFileSearch = true

    // Replace the @query with @filename
    let replacement = "@\(result.fileName) "
    let newText = nsString.replacingCharacters(in: searchRange, with: replacement)
    text = newText

    // Add file to context
    contextManager.addFile(result.fileInfo)

    // Dismiss search
    dismissFileSearch()

    // Reset flag after a short delay
    DispatchQueue.main.async {
      self.isUpdatingFileSearch = false
    }
  }

  /// Dismiss file search and clear state
  private func dismissFileSearch() {
    showingFileSearch = false
    fileSearchRange = nil
    fileSearchViewModel?.clearSearch()
  }
}
