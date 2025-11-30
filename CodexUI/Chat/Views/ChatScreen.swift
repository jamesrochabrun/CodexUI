//
//  ChatScreen.swift
//  CodexUI
//

import SwiftUI

public struct ChatScreen: View {

  @Environment(CodexConfigService.self) private var configService
  @State private var viewModel = ChatViewModel()
  @State private var messageText = ""
  @State private var showingSettings = false
  @State private var contextManager = ContextManager()

  // Session management state
  @State private var showSessionPicker = false
  @State private var availableSessions: [StoredSession] = []
  @State private var isLoadingSessions = false
  @State private var sessionLoadError: String?

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
          // Get context before clearing
          let context = contextManager.hasContext ? contextManager.getFormattedContext() : nil
          viewModel.sendMessage(messageText, context: context, attachments: attachments)
          messageText = ""
        },
        onCancel: {
          viewModel.cancelRequest()
        }
      )
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
        defaultWorkingDirectory: viewModel.projectPath.isEmpty ? nil : viewModel.projectPath,
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
        Text(shortenedProjectPath)
          .lineLimit(1)
          .truncationMode(.middle)
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

      // Settings prompt if no valid path
      if !viewModel.hasValidProjectPath {
        Text("Select a working directory in Settings to get started")
          .foregroundStyle(.secondary)
          .padding(.top, 4)

        Button("Open Settings") {
          showingSettings = true
        }
        .buttonStyle(.borderedProminent)
        .tint(.brandPrimary)
        .padding(.top, 2)
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

    // Update working directory if provided
    if let dir = directory, !dir.isEmpty {
      SettingsManager.shared.projectPath = dir
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
