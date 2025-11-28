//
//  ChatInputView.swift
//  CodexUI
//

import SwiftUI
import UniformTypeIdentifiers

struct ChatInputView: View {

  // MARK: - Properties

  @Binding var text: String
  let isLoading: Bool
  let contextManager: ContextManager
  let projectPath: String
  let onSend: ([FileAttachment]?) -> Void
  let onCancel: () -> Void

  @FocusState private var isFocused: Bool
  @Binding var triggerFocus: Bool

  private let placeholder = "Type @ to search files... (Enter to send, Shift+Enter for new line)"

  // File search properties
  @State private var showingFileSearch = false
  @State private var fileSearchRange: NSRange? = nil
  @State private var fileSearchViewModel: FileSearchViewModel? = nil
  @State private var isUpdatingFileSearch = false

  // Attachment properties
  @State private var attachments: [FileAttachment] = []
  @State private var isDragging = false
  @State private var showingFilePicker = false
  private let processor = AttachmentProcessor()

  // MARK: - Constants

  private let textAreaEdgeInsets = EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 15)

  // MARK: - Initialization

  init(
    text: Binding<String>,
    isLoading: Bool,
    contextManager: ContextManager,
    projectPath: String,
    onSend: @escaping ([FileAttachment]?) -> Void,
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

  // MARK: - Computed Properties

  /// Allowed file types for import
  private var allowedFileTypes: [UTType] {
    [.folder, .image, .pdf, .text, .plainText, .sourceCode, .data, .item]
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
          // Attachment list
          if !attachments.isEmpty {
            AttachmentListView(attachments: $attachments)
              .padding(.horizontal, 8)
              .padding(.top, 4)
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
    .animation(.easeInOut(duration: 0.2), value: attachments.count)
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
    .fileImporter(
      isPresented: $showingFilePicker,
      allowedContentTypes: allowedFileTypes,
      allowsMultipleSelection: true
    ) { result in
      handleFileImport(result)
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

  /// Attachment button
  private var attachmentButton: some View {
    Button(action: {
      showingFilePicker = true
    }) {
      Image(systemName: "paperclip")
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
      .stroke(isDragging ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: isDragging ? 2 : 1)
      .animation(.easeInOut(duration: 0.2), value: isDragging)
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
        .overlay {
          textEditorOverlay
        }

      if text.isEmpty {
        placeholderView
          .padding(textAreaEdgeInsets)
          .padding(.leading, 4)
      }
    }
  }

  /// Text editor overlay for drag and drop
  private var textEditorOverlay: some View {
    Color.clear
      .allowsHitTesting(true)
      .onDrop(of: [.fileURL, .png, .tiff, .image], isTargeted: $isDragging) { providers in
        handleDroppedProviders(providers)
        return true
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
    // Include attachments if any
    let messageAttachments = attachments.isEmpty ? nil : attachments
    onSend(messageAttachments)
    text = ""
    // Clear context and attachments after sending
    contextManager.clearAll()
    attachments.removeAll()
  }
}

// MARK: - File Handling

extension ChatInputView {

  /// Handle file import from file picker
  private func handleFileImport(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      Task {
        for url in urls {
          var isDirectory: ObjCBool = false
          if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
              await handleDroppedFolder(url)
            } else {
              let attachment = FileAttachment(url: url)
              attachments.append(attachment)
              await processor.process(attachment)
            }
          }
        }
      }
    case .failure(let error):
      print("Failed to import files: \(error)")
    }
  }

  /// Handle dropped item providers
  private func handleDroppedProviders(_ providers: [NSItemProvider]) {
    Task {
      for provider in providers {
        // Try to load as file URL first (this handles both files and folders)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
          _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }

            Task { @MainActor in
              // Check if it's a directory
              var isDirectory: ObjCBool = false
              if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                  // Handle folder
                  await handleDroppedFolder(url)
                } else {
                  // Handle single file
                  // Check if it's a screenshot from temporary directory
                  let isScreenshot = url.path.contains("TemporaryItems") || url.path.contains("screencaptureui")
                  let attachment = FileAttachment(url: url, isTemporary: isScreenshot)
                  attachments.append(attachment)
                  await processor.process(attachment)
                }
              }
            }
          }
        }
        // If not a file URL, try to load as PNG data (for screenshots)
        else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
          _ = provider.loadDataRepresentation(for: .png) { data, error in
            guard let data = data, error == nil else { return }

            Task { @MainActor in
              // Save PNG data to temporary file
              let tempDirectory = FileManager.default.temporaryDirectory
              let fileName = "screenshot_\(UUID().uuidString).png"
              let tempURL = tempDirectory.appendingPathComponent(fileName)

              do {
                try data.write(to: tempURL)
                let attachment = FileAttachment(url: tempURL, isTemporary: true)
                attachments.append(attachment)
                await processor.process(attachment)
              } catch {
                print("Failed to save dropped screenshot: \(error)")
              }
            }
          }
        }
        // Try TIFF data (another common screenshot format)
        else if provider.hasItemConformingToTypeIdentifier(UTType.tiff.identifier) {
          _ = provider.loadDataRepresentation(for: .tiff) { data, error in
            guard let data = data, error == nil else { return }

            Task { @MainActor in
              // Save TIFF data to temporary file
              let tempDirectory = FileManager.default.temporaryDirectory
              let fileName = "screenshot_\(UUID().uuidString).tiff"
              let tempURL = tempDirectory.appendingPathComponent(fileName)

              do {
                try data.write(to: tempURL)
                let attachment = FileAttachment(url: tempURL, isTemporary: true)
                attachments.append(attachment)
                await processor.process(attachment)
              } catch {
                print("Failed to save dropped screenshot: \(error)")
              }
            }
          }
        }
        // Finally, try generic image data
        else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
          _ = provider.loadDataRepresentation(for: .image) { data, error in
            guard let data = data, error == nil else { return }

            Task { @MainActor in
              // Save image data to temporary file
              let tempDirectory = FileManager.default.temporaryDirectory
              let fileName = "dropped_image_\(UUID().uuidString).png"
              let tempURL = tempDirectory.appendingPathComponent(fileName)

              do {
                try data.write(to: tempURL)
                let attachment = FileAttachment(url: tempURL, isTemporary: true)
                attachments.append(attachment)
                await processor.process(attachment)
              } catch {
                print("Failed to save dropped image: \(error)")
              }
            }
          }
        }
      }
    }
  }

  /// Handle dropped folder
  @MainActor
  private func handleDroppedFolder(_ folderURL: URL) async {
    // Collect files synchronously first
    let filesToAdd = collectFilesFromFolder(folderURL)

    // Add files to attachments asynchronously
    for fileURL in filesToAdd {
      let attachment = FileAttachment(url: fileURL)
      attachments.append(attachment)
      await processor.process(attachment)
    }
  }

  /// Collect files from folder recursively
  private func collectFilesFromFolder(_ folderURL: URL) -> [URL] {
    let fileManager = FileManager.default

    // Get all files in the folder recursively
    guard let enumerator = fileManager.enumerator(
      at: folderURL,
      includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
      options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else { return [] }

    var filesToAdd: [URL] = []

    for case let fileURL as URL in enumerator {
      do {
        let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])

        // Only add regular files (not directories or special files)
        if let isRegularFile = resourceValues.isRegularFile, isRegularFile,
           let isHidden = resourceValues.isHidden, !isHidden {

          // Skip system files
          let fileName = fileURL.lastPathComponent
          if !isSystemFile(fileName) {
            filesToAdd.append(fileURL)
          }
        }
      } catch {
        print("Error checking file properties: \(error)")
      }
    }

    return filesToAdd
  }

  /// Check if file is a system file
  private func isSystemFile(_ fileName: String) -> Bool {
    let systemFiles = [".DS_Store", ".localized", "Thumbs.db", "desktop.ini", ".git", ".svn"]
    return systemFiles.contains(fileName) || fileName.hasPrefix("~$")
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
