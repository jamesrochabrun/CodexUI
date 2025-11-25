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
        if viewModel.messages.isEmpty {
          welcomeView
            .listRowSeparator(.hidden)
        }

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
    VStack(spacing: 12) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 48))
        .foregroundStyle(Color.brandPrimary)

      Text("CodexUI Chat")
        .font(.title2)
        .fontWeight(.medium)

      if viewModel.hasValidProjectPath {
        HStack(spacing: 4) {
          Image(systemName: "folder.fill")
            .foregroundStyle(Color.brandPrimary)
          Text(viewModel.projectPath)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .font(.caption)
        .foregroundStyle(.secondary)

        Text("Send a message to start chatting")
          .font(.body)
          .foregroundStyle(.secondary)
      } else {
        Text("Select a working directory in Settings to get started")
          .font(.body)
          .foregroundStyle(.secondary)

        Button("Open Settings") {
          showingSettings = true
        }
        .buttonStyle(.borderedProminent)
        .tint(.brandPrimary)
        .padding(.top, 8)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
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
