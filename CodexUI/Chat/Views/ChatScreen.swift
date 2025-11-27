//
//  ChatScreen.swift
//  CodexUI
//

import SwiftUI

public struct ChatScreen: View {
  
  @State private var viewModel = ChatViewModel()
  @State private var messageText = ""
  @State private var showingSettings = false
  
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
        onSend: {
          viewModel.sendMessage(messageText)
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
      
      // Directory line
      HStack(spacing: 0) {
        Text("directory:")
          .foregroundStyle(.secondary)
          .frame(width: 80, alignment: .leading)
        Text(shortenedProjectPath)
          .lineLimit(1)
          .truncationMode(.middle)
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
}

#Preview {
  ChatScreen()
}
