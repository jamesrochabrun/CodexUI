//
//  ChatViewModel.swift
//  CodexUI
//

import Foundation
import CodexSDK

@Observable
@MainActor
public final class ChatViewModel {

  // MARK: - Published State

  private(set) var messages: [ChatMessage] = []
  private(set) var isLoading = false
  private(set) var errorMessage: String?
  private(set) var hasError = false

  // MARK: - Settings

  private let settings = SettingsManager.shared

  var projectPath: String {
    settings.projectPath
  }

  var hasValidProjectPath: Bool {
    settings.isValidGitRepo(settings.projectPath)
  }

  // MARK: - Private

  private var client: CodexExecClient {
    createClient()
  }
  private var currentTask: Task<Void, Never>?
  private var hasSession = false

  // MARK: - Initialization

  init() {}

  // MARK: - Private Methods

  private func createClient() -> CodexExecClient {
    // Start with nvm-aware configuration
    var config = CodexExecConfiguration.withNvmSupport()
    config.enableDebugLogging = true
    config.useLoginShell = true  // Source shell profile for environment variables

    // Set working directory so codex runs from the project directory
    // This is critical for resume commands which don't accept --cd
    if !settings.projectPath.isEmpty {
      config.workingDirectory = settings.projectPath
    }

    let homeDir = NSHomeDirectory()

    // Instead of relying on PATH, explicitly set the command to the full path
    // This ensures we use the correct codex binary regardless of shell PATH

    // PRIORITY 1: Local codex installation
    let localCodexPath = "\(homeDir)/.codex/local/codex"
    if FileManager.default.fileExists(atPath: localCodexPath) {
      config.command = localCodexPath
    }
    // PRIORITY 2: NVM codex (most likely the newest version)
    else if let nvmPath = NvmPathDetector.detectNvmPath() {
      let nvmCodexPath = "\(nvmPath)/codex"
      if FileManager.default.fileExists(atPath: nvmCodexPath) {
        config.command = nvmCodexPath
      }
    }

    return CodexExecClient(configuration: config)
  }

  // MARK: - Public Methods

  func sendMessage(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard hasValidProjectPath else {
      errorMessage = "Please select a valid Git repository in Settings."
      hasError = true
      return
    }

    // Add user message
    let userMessage = ChatMessage(role: .user, content: trimmed)
    messages.append(userMessage)

    // Create placeholder assistant message for streaming
    let assistantMessage = ChatMessage(
      role: .assistant,
      content: "",
      isComplete: false
    )
    messages.append(assistantMessage)

    isLoading = true
    errorMessage = nil
    hasError = false

    currentTask = Task {
      await streamResponse(prompt: trimmed, messageId: assistantMessage.id)
    }
  }

  func cancelRequest() {
    currentTask?.cancel()
    currentTask = nil
    isLoading = false

    // Mark current streaming message as complete
    if let lastIndex = messages.indices.last,
       messages[lastIndex].role == .assistant,
       !messages[lastIndex].isComplete {
      messages[lastIndex].isComplete = true
      if messages[lastIndex].content.isEmpty {
        messages[lastIndex].content = "(Cancelled)"
      }
    }
  }

  private func streamResponse(prompt: String, messageId: UUID) async {
    var stdoutBuffer = ""
    var stderrBuffer = ""

    do {
      var options = CodexExecOptions()

      // JSON events only on first turn (resume rejects it)
      options.jsonEvents = !hasSession
      options.promptViaStdin = true

      // Full auto mode only on first turn (resume rejects it)
      options.fullAuto = !hasSession

      // Timeout to avoid indefinite hangs
      options.timeout = 90

      // Sandbox/model/changeDirectory only on first turn (resume rejects these flags)
      if !hasSession {
        options.sandbox = .readOnly
        options.model = "gpt-5.1-codex-max"
        // Set working directory via --cd flag (only on first turn)
        if !settings.projectPath.isEmpty {
          options.changeDirectory = settings.projectPath
        }
      }

      // Resume last session if we have one
      options.resumeLastSession = hasSession

      _ = try await client.run(prompt: prompt, options: options) { [weak self] event in
        guard let self else { return }

        Task { @MainActor in
          switch event {
          case .jsonEvent(let json):
            // Handle agent_message type for streaming text
            if let text = json.item?.text, json.item?.type == "agent_message" {
              stdoutBuffer += text + "\n"
              self.updateAssistantMessage(id: messageId, content: stdoutBuffer)
            }

          case .stdout(let line):
            // Append stdout lines
            stdoutBuffer += line + "\n"
            self.updateAssistantMessage(id: messageId, content: stdoutBuffer)

          case .stderr(let line):
            // Collect stderr for fallback display
            if !line.isEmpty {
              stderrBuffer += line + "\n"
            }
          }
        }
      }

      // Mark session as active for future messages
      hasSession = true

      // Finalize message
      await MainActor.run {
        let finalOutput = stdoutBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLogs = stderrBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleaned = self.cleanOutput(finalOutput)
        let logsClean = self.cleanOutput(fallbackLogs)
        if cleaned.isEmpty {
          let content = logsClean.isEmpty ? "(no output)" : logsClean
          self.updateAssistantMessage(id: messageId, content: content)
        } else {
          self.updateAssistantMessage(id: messageId, content: cleaned)
        }

        self.markMessageComplete(id: messageId)
        self.isLoading = false
      }

    } catch {
      await MainActor.run {
        if !Task.isCancelled {
          let errorMsg = self.friendlyMessage(for: error)
          self.errorMessage = errorMsg
          self.hasError = true

          // Show error with any output collected
          var content = "Error: \(errorMsg)"
          let outputSoFar = stdoutBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
          let logs = stderrBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

          if !outputSoFar.isEmpty {
            content += "\n\nOutput so far:\n\(outputSoFar)"
          } else if !logs.isEmpty {
            content += "\n\nLogs:\n\(logs)"
          }

          self.updateAssistantMessage(id: messageId, content: content)
          self.markMessageComplete(id: messageId)
        }
        self.isLoading = false
      }
    }
  }

  private func updateAssistantMessage(id: UUID, content: String) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[index].content = content
  }

  private func markMessageComplete(id: UUID) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[index].isComplete = true
  }

  private func friendlyMessage(for error: Error) -> String {
    if let codexError = error as? CodexExecError {
      return codexError.localizedDescription
    }
    return error.localizedDescription
  }

  private func cleanOutput(_ text: String) -> String {
    let lines = text
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
      .filter { line in
        let lower = line.lowercased()
        if lower.contains("openai codex") { return false }
        if lower.contains("workdir:") { return false }
        if lower.contains("model:") { return false }
        if lower.contains("provider:") { return false }
        if lower.contains("approval:") { return false }
        if lower.contains("sandbox:") { return false }
        if lower.contains("reasoning") { return false }
        if lower.trimmingCharacters(in: .whitespacesAndNewlines) == "--------" { return false }
        return true
      }
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
