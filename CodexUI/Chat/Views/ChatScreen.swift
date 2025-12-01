//
//  ChatScreen.swift
//  CodexUI
//

import SwiftUI

public struct ChatScreen: View {

  @Environment(CodexConfigService.self) private var configService
  @Environment(\.xcodeObservationViewModel) private var xcodeObservationViewModel
  @Environment(\.keyboardShortcutManager) private var keyboardShortcutManager

  @State private var viewModel = ChatViewModel()
  @State private var messageText = ""
  @State private var showingSettings = false
  @State private var contextManager = ContextManager()
  @State private var xcodeContextManager = XcodeContextManager()

  // Session management state
  @State private var showSessionPicker = false
  @State private var availableSessions: [StoredSession] = []
  @State private var isLoadingSessions = false
  @State private var sessionLoadError: String?

  // Keyboard shortcut integration
  @State private var triggerFocus = false

  // Repository selection state
  @State private var showInvalidRepoAlert = false
  @State private var showRepoRequiredAlert = false

  public init() {}
  
  public var body: some View {
    VStack(spacing: 0) {
      messagesListView
        .padding(.bottom, 8)
      
      if viewModel.isLoading {
        loadingIndicator
      }
      
      if let error = viewModel.errorMessage {
        errorBanner(error)
      }

      ChatInputView(
        text: $messageText,
        isLoading: viewModel.isLoading,
        contextManager: contextManager,
        projectPath: viewModel.projectPath,
        onSend: { attachments in
          // Validate repo is selected before first message
          if !viewModel.hasSessionStarted && !viewModel.hasValidProjectPath {
            showRepoRequiredAlert = true
            return
          }

          // Get context before clearing (includes @ mentions and Xcode context)
          var contextParts: [String] = []
          if contextManager.hasContext {
            contextParts.append(contextManager.getFormattedContext())
          }

          // Include live active file from Xcode (when not pinned)
          if !xcodeContextManager.isPinnedActiveFile,
             let activeFile = xcodeObservationViewModel?.workspaceModel.activeFile {
            var fileContext = "Active file: \(activeFile.name)"
            if let content = activeFile.content, !content.isEmpty {
              fileContext += "\n```\n\(content)\n```"
            }
            contextParts.append(fileContext)
          }

          if xcodeContextManager.hasContext {
            contextParts.append(xcodeContextManager.getFormattedContext())
          }
          let context = contextParts.isEmpty ? nil : contextParts.joined(separator: "\n\n")

          viewModel.sendMessage(messageText, context: context, attachments: attachments)
          messageText = ""

          // Clear Xcode context after sending
          xcodeContextManager.clearAll()
          xcodeObservationViewModel?.dismissActiveFile()
        },
        onCancel: {
          viewModel.cancelRequest()
        },
        triggerFocus: $triggerFocus,
        xcodeContextManager: xcodeContextManager,
        xcodeObservationViewModel: xcodeObservationViewModel
      )
      // Profile selector below input (left-aligned, compact)
      HStack {
        ProfileSelectorView()
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 4)
      .padding(.bottom, 8)
    }
    .frame(minWidth: 400, minHeight: 300)
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button(action: { showSessionPicker = true }) {
          Image(systemName: "list.bullet")
            .font(.title2)
        }
        .help("Sessions")
      }
      ToolbarItem(placement: .automatic) {
        Button(action: { showingSettings = true }) {
          Image(systemName: "gearshape")
            .font(.title2)
        }
        .help("Settings")
      }
    }
    .sheet(isPresented: $showingSettings) {
      SettingsView()
    }
    .sheet(isPresented: $showSessionPicker) {
      SessionPickerContent(
        sessions: availableSessions,
        currentSessionId: viewModel.currentSessionId,
        isLoading: isLoadingSessions,
        error: sessionLoadError,
        defaultWorkingDirectory: nil,
        onStartNewSession: { directory in
          startNewSession(directory: directory)
        },
        onRestoreSession: { session in
          restoreSession(session)
        },
        onDeleteSession: { session in
          deleteSession(session)
        },
        onDeleteAllSessions: {
          deleteAllSessions()
        },
        onDismiss: {
          showSessionPicker = false
        }
      )
    }
    .task {
      viewModel.configService = configService
      await loadSessions()
    }
    .onChange(of: viewModel.currentSessionId) { oldValue, newValue in
      // Reload sessions when a new session is created
      if oldValue == nil && newValue != nil {
        Task {
          await loadSessions()
        }
      }
    }
    .onChange(of: showSessionPicker) { _, isShowing in
      // Reload sessions when the picker opens to ensure fresh data
      if isShowing {
        Task {
          await loadSessions()
        }
      }
    }
    .onChange(of: keyboardShortcutManager?.capturedText) { _, newText in
      // Handle captured text from CMD+I shortcut
      if let _ = newText, newText?.isEmpty == false {
        // Capture the selection with file info and add to context manager
        if let selection = xcodeObservationViewModel?.captureCurrentSelection() {
          xcodeContextManager.addSelection(selection)
        }
        // Reset the captured text
        keyboardShortcutManager?.resetCapturedText()
      }
    }
    .onChange(of: keyboardShortcutManager?.shouldFocusTextEditor) { _, shouldFocus in
      // Handle focus trigger from CMD+I shortcut
      if shouldFocus == true {
        triggerFocus = true
        keyboardShortcutManager?.resetFocusTrigger()
      }
    }
    .onChange(of: keyboardShortcutManager?.shouldRefreshObservation) { _, shouldRefresh in
      // Handle observation refresh trigger
      if shouldRefresh == true {
        xcodeObservationViewModel?.restartObservation()
        keyboardShortcutManager?.resetRefreshTrigger()
      }
    }
    .alert("Error", isPresented: Binding(
      get: { viewModel.hasError },
      set: { _ in }
    )) {
      Button("OK", role: .cancel) { }
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
      }
    }
    .alert("Invalid Repository", isPresented: $showInvalidRepoAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("The selected folder is not a valid Git repository. Please select a folder containing a .git directory.")
    }
    .alert("Repository Required", isPresented: $showRepoRequiredAlert) {
      Button("Select Repository") {
        selectRepository()
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("Please select a repository before sending your first message.")
    }
  }
  
  private var messagesListView: some View {
    ScrollViewReader { scrollView in
      List {
        welcomeView
          .listRowSeparator(.hidden)
        
        ForEach(viewModel.messages) { message in
          ChatMessageView(message: message)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .id(message.id)
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .onChange(of: viewModel.messages.count) { _, _ in
        if let lastMessage = viewModel.messages.last {
          withAnimation {
            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
          }
        }
      }
    }
  }
  
  private var welcomeView: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Header: >_ CodexUI (v1.0.0)
      HStack(spacing: 4) {
        Text(">_")
          .foregroundStyle(Color.brandPrimary)
        Text("CodexUI")
          .fontWeight(.semibold)
        Text("(\(appVersion))")
          .foregroundStyle(.secondary)
      }

      // Model line
      HStack(spacing: 0) {
        Text("model:")
          .foregroundStyle(.secondary)
          .frame(width: 80, alignment: .leading)
        Text(viewModel.model)
          .foregroundStyle(Color.brandPrimary)
      }

      // Reasoning effort line
      HStack(spacing: 0) {
        Text("reasoning:")
          .foregroundStyle(.secondary)
          .frame(width: 80, alignment: .leading)
        Text(viewModel.reasoningEffort)
      }

      // CLI version line
      HStack(spacing: 0) {
        Text("cli:")
          .foregroundStyle(.secondary)
          .frame(width: 80, alignment: .leading)
        Text(viewModel.cliVersion)
      }

      // Directory line
      HStack(spacing: 0) {
        Text("directory:")
          .foregroundStyle(.secondary)
          .frame(width: 80, alignment: .leading)

        if viewModel.hasValidProjectPath {
          Text(shortenedProjectPath)
            .lineLimit(1)
            .truncationMode(.middle)
        } else {
          Button(action: selectRepository) {
            HStack(spacing: 4) {
              Image(systemName: "folder.badge.plus")
              Text("Select")
            }
          }
          .buttonStyle(.bordered)
          .tint(.brandPrimary)
          .controlSize(.small)
        }
      }

      // User info separator and details
      if viewModel.userEmail != nil || viewModel.planType != nil {
        Divider()
          .padding(.vertical, 4)

        HStack(spacing: 8) {
          if let email = viewModel.userEmail {
            Text(email)
              .foregroundStyle(.secondary)
          }
          if let planType = viewModel.planType {
            Text("·")
              .foregroundStyle(.tertiary)
            Text(planType.capitalized)
              .foregroundStyle(Color.brandPrimary)
          }
        }
      }

    }
    .font(.system(.callout, design: .monospaced))
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(
      RoundedRectangle(cornerSize: .init(width: 8, height: 8))
        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
    )
    .padding(.horizontal, 6)

  }
  
  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
  }
  
  private var shortenedProjectPath: String {
    let path = viewModel.projectPath
    guard !path.isEmpty else { return "~" }
    return path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
  }
  
  private var loadingIndicator: some View {
    HStack(spacing: 8) {
      ProgressView()
        .controlSize(.small)
        .tint(.brandPrimary)
      Text("Processing...")
        .font(.caption)
        .foregroundStyle(Color.brandTertiary)
    }
    .padding(.horizontal)
    .padding(.bottom, 8)
  }
  
  private func errorBanner(_ message: String) -> some View {
    HStack {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(Color.goldenAmber)
      Text(message)
        .font(.caption)
      Spacer()
    }
    .padding(.horizontal)
    .padding(.vertical, 6)
    .background(Color.goldenAmber.opacity(0.1))
  }

  // MARK: - Session Management

  private func loadSessions() async {
    isLoadingSessions = true
    sessionLoadError = nil

    do {
      availableSessions = try await SessionManager.shared.loadAvailableSessions()
    } catch {
      sessionLoadError = error.localizedDescription
    }

    isLoadingSessions = false
  }

  private func startNewSession(directory: String?) {
    viewModel.clearConversation()

    // Update session working directory if provided
    if let dir = directory, !dir.isEmpty {
      viewModel.sessionWorkingDirectory = dir
    }
  }

  // MARK: - Repository Selection

  private func selectRepository() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.message = "Select a Git repository as your working directory"
    panel.prompt = "Select"

    if panel.runModal() == .OK, let url = panel.url {
      let path = url.path

      if SettingsManager.shared.isValidGitRepo(path) {
        viewModel.sessionWorkingDirectory = path
      } else {
        showInvalidRepoAlert = true
      }
    }
  }

  private func restoreSession(_ session: StoredSession) {
    Task {
      await SessionManager.shared.restoreSession(session: session, chatViewModel: viewModel)
    }
  }

  private func deleteSession(_ session: StoredSession) {
    Task {
      do {
        try await SessionManager.shared.deleteSession(sessionId: session.id)

        // If we deleted the current session, clear the conversation
        if viewModel.currentSessionId == session.id {
          viewModel.clearConversation()
        }

        // Reload sessions
        await loadSessions()
      } catch {
        print("Failed to delete session: \(error)")
      }
    }
  }

  private func deleteAllSessions() {
    Task {
      do {
        try await SessionManager.shared.deleteAllSessions()
        viewModel.clearConversation()
        await loadSessions()
      } catch {
        print("Failed to delete all sessions: \(error)")
      }
    }
  }
}

#Preview {
  ChatScreen()
}
