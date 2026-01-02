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

  // MARK: - Session State

  /// Current session ID (nil if no session started)
  private(set) var currentSessionId: String?

  /// Whether a session has been started (for UI purposes)
  private(set) var hasSessionStarted: Bool = false

  /// Working directory for the current session (set per session, not globally)
  var sessionWorkingDirectory: String?

  // MARK: - Settings

  private let settings = SettingsManager.shared
  private let sessionManager = SessionManager.shared
  private let profileManager = ProfileManager.shared
  var configService: CodexConfigService?

  var projectPath: String {
    sessionWorkingDirectory ?? ""
  }

  var hasValidProjectPath: Bool {
    guard let dir = sessionWorkingDirectory, !dir.isEmpty else { return false }
    return settings.isValidGitRepo(dir)
  }

  var model: String {
    configService?.model ?? "unknown"
  }

  var reasoningEffort: String {
    UserDefaults.standard.string(forKey: "com.codexui.reasoningEffort") ?? "medium"
  }

  var cliVersion: String {
    configService?.cliVersion ?? "unknown"
  }

  var userEmail: String? {
    configService?.userEmail
  }

  var planType: String? {
    configService?.planType
  }

  // MARK: - Private

  private var client: CodexExecClient {
    createClient()
  }
  private var currentTask: Task<Void, Never>?
  private var hasSession = false

  /// State for parsing stderr during resume sessions
  private enum StderrParseState {
    case idle
    case awaitingReasoning  // After "thinking" line
    case awaitingCommand    // After "exec" line
    case collectingOutput   // After command line, collecting output
  }

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
    if let workingDir = sessionWorkingDirectory, !workingDir.isEmpty {
      config.workingDirectory = workingDir
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

  @discardableResult
  func sendMessage(_ text: String, context: String? = nil, attachments: [FileAttachment]? = nil) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    guard hasValidProjectPath else {
      errorMessage = "Please select a valid Git repository in Settings."
      hasError = true
      return false
    }

    // Convert FileAttachment to StoredAttachment for the message
    let storedAttachments = attachments?.map { attachment in
      StoredAttachment(
        id: attachment.id,
        fileName: attachment.fileName,
        type: attachment.type.rawValue,
        filePath: attachment.filePath
      )
    }

    // Add user message with attachments
    let userMessage = ChatMessage(role: .user, content: trimmed, attachments: storedAttachments)
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

    // Build prompt with context if provided
    var fullPrompt = trimmed
    if let context = context, !context.isEmpty {
      fullPrompt = "\(context)\n\n---\n\n\(trimmed)"
    }

    // Build prompt with attachment info
    if let attachments = attachments, !attachments.isEmpty {
      let attachmentInfo = AttachmentProcessor.formatAttachmentsForXML(attachments)
      fullPrompt = "\(attachmentInfo)\n\n\(fullPrompt)"
    }

    currentTask = Task {
      // Start a new session if this is the first message
      if !hasSessionStarted {
        await startSession(withFirstMessage: trimmed)
      }

      await streamResponse(prompt: fullPrompt, messageId: assistantMessage.id)

      // Save messages after the response completes
      await saveCurrentSession()
    }

    return true
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

  /// Buffer class to hold streaming output (reference type for proper capture in closures)
  private final class StreamBuffer: @unchecked Sendable {
    var stdout = ""
    var stderr = ""
    var stderrParseState: StderrParseState = .idle
  }

  private func streamResponse(prompt: String, messageId: UUID) async {
    let buffer = StreamBuffer()

    do {
      var options = CodexExecOptions()

      // JSON events only on first turn (resume rejects it)
      options.jsonEvents = !hasSession
      options.promptViaStdin = true

      // Timeout to avoid indefinite hangs (5 minutes for complex queries)
      options.timeout = 300

      // Profile and changeDirectory only on first turn (resume rejects these flags)
      if !hasSession {
        // Use --profile flag if a profile is selected (encapsulates sandbox, approval, fullAuto, model, reasoningEffort)
        if let profileId = profileManager.activeProfileId {
          options.profile = profileId
        } else {
          // Default behavior when no profile is selected
          options.sandbox = .readOnly
          options.fullAuto = true
          options.model = model
        }

        // Set working directory via --cd flag (only on first turn)
        if let workingDir = sessionWorkingDirectory, !workingDir.isEmpty {
          options.changeDirectory = workingDir
        }
      }

      // Resume last session if we have one
      options.resumeLastSession = hasSession

      _ = try await client.run(prompt: prompt, options: options) { [weak self] event in
        guard let self else { return }

        Task { @MainActor in
          switch event {
          case .jsonEvent(let json):

            // Handle different event types based on (type, item.type)
            // Terminal-style prefixes: * reasoning, $ command, ✓/! status, ◆ assistant
            switch (json.type, json.item?.type) {
            case ("item.completed", "reasoning"):
              // Show reasoning/thinking steps with * prefix
              if let text = json.item?.text {
                let lines = text.components(separatedBy: "\n")
                  .map { "* \($0)" }
                  .joined(separator: "\n")
                buffer.stdout += "\(lines)\n"
                self.updateAssistantMessage(id: messageId, content: buffer.stdout)
              }

            case ("item.started", "command_execution"):
              // Show command starting with $ prefix
              if let command = json.item?.command {
                let shortCommand = self.shortenCommand(command)
                buffer.stdout += "$ \(shortCommand)\n"
                self.updateAssistantMessage(id: messageId, content: buffer.stdout)
              }

            case ("item.completed", "command_execution"):
              // Show command completion with ✓ or ! prefix
              if let exitCode = json.item?.exitCode {
                let prefix = exitCode == 0 ? "✓" : "!"
                buffer.stdout += "\(prefix) exit \(exitCode)\n"
                self.updateAssistantMessage(id: messageId, content: buffer.stdout)
              }

            case ("item.completed", "agent_message"):
              // Final assistant message with ◆ prefix
              if let text = json.item?.text {
                buffer.stdout += "◆ \(text)\n"
                self.updateAssistantMessage(id: messageId, content: buffer.stdout)
              }

            case ("thread.started", _):
              // Capture the CLI's actual session ID from the thread.started event
              if let threadId = json.threadId {
                self.updateCliSessionId(threadId)
              }

            default:
              break
            }

          case .stdout(let line):
            // Append stdout lines (fallback when JSON not available)
            buffer.stdout += line + "\n"
            self.updateAssistantMessage(id: messageId, content: buffer.stdout)

          case .stderr(let line):
            // Collect stderr for fallback display
            if !line.isEmpty {
              buffer.stderr += line + "\n"
            }

            // Capture the CLI session ID if present
            if line.lowercased().contains("session id:") {
              self.extractAndUpdateSessionId(from: line)
            }

            // When in resume mode (no JSON events), parse stderr for display
            if self.hasSession && !line.isEmpty {
              if let displayLine = self.parseStderrLine(line, state: &buffer.stderrParseState) {
                buffer.stdout += displayLine + "\n"
                self.updateAssistantMessage(id: messageId, content: buffer.stdout)
              }
            }
          }
        }
      }

      // Mark session as active for future messages
      hasSession = true

      // Finalize message
      await MainActor.run {
        let finalOutput = buffer.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLogs = buffer.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

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
          let outputSoFar = buffer.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
          let logs = buffer.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

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

  /// Shorten a shell command for display (removes /bin/zsh -lc wrapper)
  private func shortenCommand(_ command: String) -> String {
    // Commands come as: /bin/zsh -lc "actual command" or /bin/zsh -lc 'actual command'
    if command.hasPrefix("/bin/zsh -lc ") {
      var shortened = String(command.dropFirst("/bin/zsh -lc ".count))
      // Remove surrounding quotes if present
      if (shortened.hasPrefix("\"") && shortened.hasSuffix("\"")) ||
         (shortened.hasPrefix("'") && shortened.hasSuffix("'")) {
        shortened = String(shortened.dropFirst().dropLast())
      }
      return shortened
    }
    return command
  }

  private func cleanOutput(_ text: String) -> String {
    let lines = text
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
      .filter { line in
        let lower = line.lowercased()
        // Keep terminal-prefixed lines (*, $, ✓, !, ◆)
        let terminalPrefixes = ["* ", "$ ", "✓ ", "! ", "◆ "]
        let hasTerminalPrefix = terminalPrefixes.contains { line.hasPrefix($0) }
        if hasTerminalPrefix { return true }

        // Filter out CLI banner/metadata lines
        if lower.contains("openai codex") { return false }
        if lower.contains("workdir:") { return false }
        if lower.contains("model:") { return false }
        if lower.contains("provider:") { return false }
        if lower.contains("approval:") { return false }
        if lower.contains("sandbox:") { return false }
        if lower.trimmingCharacters(in: .whitespacesAndNewlines) == "--------" { return false }
        return true
      }
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Stderr Parsing (for resume sessions)

  /// Check if a line should be filtered out (CLI banner/metadata)
  private func shouldFilterLine(_ line: String) -> Bool {
    let lower = line.lowercased()
    if lower.contains("openai codex") { return true }
    if lower.contains("workdir:") { return true }
    if lower.contains("model:") { return true }
    if lower.contains("provider:") { return true }
    if lower.contains("approval:") { return true }
    if lower.contains("sandbox:") { return true }
    if lower.contains("reasoning effort") { return true }
    if lower.contains("reasoning summaries") { return true }
    if lower.contains("session id:") { return true }
    if lower.contains("mcp startup") { return true }
    if line.trimmingCharacters(in: .whitespaces) == "--------" { return true }
    // Filter out conversation markers
    if line.trimmingCharacters(in: .whitespaces) == "user" { return true }
    if line.trimmingCharacters(in: .whitespaces) == "assistant" { return true }
    return false
  }

  /// Parse a stderr line and return terminal-formatted output if applicable
  private func parseStderrLine(_ line: String, state: inout StderrParseState) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    // Skip CLI banner/metadata lines
    if shouldFilterLine(trimmed) { return nil }

    // State machine for parsing
    switch state {
    case .idle:
      if trimmed == "thinking" {
        state = .awaitingReasoning
        return nil
      } else if trimmed == "exec" {
        state = .awaitingCommand
        return nil
      }
      return nil

    case .awaitingReasoning:
      state = .idle
      // Reasoning lines often wrapped in **...**
      let reasoning = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
      return "* \(reasoning)"

    case .awaitingCommand:
      // Command line format: /bin/zsh -lc 'cmd' in /path succeeded/failed in Xms:
      if trimmed.contains("succeeded in") || trimmed.contains("failed in") {
        let shortCmd = extractAndShortenCommand(from: trimmed)
        let success = trimmed.contains("succeeded")
        let status = extractStatus(from: trimmed)
        state = success ? .collectingOutput : .idle
        // To show exit status, use: return "  $ \(shortCmd)\n  \(success ? "✓" : "!") \(status)"
        return "  $ \(shortCmd)"
      }
      state = .idle
      return nil

    case .collectingOutput:
      // Skip command output to keep display clean (per user preference)
      // Just watch for next marker
      if trimmed == "thinking" {
        state = .awaitingReasoning
        return nil
      } else if trimmed == "exec" {
        state = .awaitingCommand
        return nil
      }
      return nil // Skip detailed command output
    }
  }

  /// Extract command from stderr line and shorten it
  /// Input format: "/bin/zsh -lc 'ls Sources' in /path succeeded in 54ms:"
  private func extractAndShortenCommand(from line: String) -> String {
    // Find the command part before " in /"
    guard let inIndex = line.range(of: " in /") else {
      return shortenCommand(line)
    }
    let commandPart = String(line[..<inIndex.lowerBound])
    return shortenCommand(commandPart)
  }

  /// Extract status (succeeded/failed in Xms) from stderr line
  private func extractStatus(from line: String) -> String {
    // Find "succeeded in" or "failed in" and extract the timing
    if let range = line.range(of: "succeeded in ") {
      let afterSucceeded = line[range.upperBound...]
      // Extract timing like "54ms:"
      if let colonIndex = afterSucceeded.firstIndex(of: ":") {
        return "exit 0 (\(String(afterSucceeded[..<colonIndex])))"
      }
      return "exit 0"
    } else if let range = line.range(of: "failed in ") {
      let afterFailed = line[range.upperBound...]
      if let colonIndex = afterFailed.firstIndex(of: ":") {
        return "exit 1 (\(String(afterFailed[..<colonIndex])))"
      }
      return "exit 1"
    }
    return ""
  }

  // MARK: - Session Management

  /// Clears the current conversation and resets session state
  func clearConversation() {
    messages.removeAll()
    currentSessionId = nil
    hasSession = false
    hasSessionStarted = false
    sessionWorkingDirectory = nil
    errorMessage = nil
    hasError = false
  }

  /// Clears UI while keeping the session active for continued conversation
  /// This allows starting fresh visually while maintaining the CLI session
  func resumeInNewSession() {
    guard currentSessionId != nil else { return }

    // Clear messages but preserve session state
    messages.removeAll()
    errorMessage = nil
    hasError = false

    // Keep: currentSessionId, hasSession, hasSessionStarted, sessionWorkingDirectory
    // Next message will continue the CLI session via --resume-last-session
  }

  /// Launches Terminal.app with the current session
  /// - Returns: An error if launching fails, nil on success
  func launchTerminalWithSession() -> Error? {
    guard let sessionId = currentSessionId else {
      return NSError(
        domain: "ChatViewModel",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No active session to launch"]
      )
    }

    return TerminalLauncher.launchTerminalWithSession(sessionId, projectPath: projectPath)
  }

  /// Sets an error message to be displayed
  func setError(_ message: String) {
    errorMessage = message
    hasError = true
  }

  /// Updates the session ID with the CLI's actual thread ID
  private func updateCliSessionId(_ cliSessionId: String) {
    guard !cliSessionId.isEmpty else { return }

    // Only update if different from current
    guard let oldId = currentSessionId, oldId != cliSessionId else { return }

    print("[Session] Updating session ID from \(oldId) to CLI thread ID: \(cliSessionId)")

    // Update in-memory
    currentSessionId = cliSessionId

    // Update in storage
    Task {
      do {
        try await sessionManager.updateSessionId(oldId: oldId, newId: cliSessionId)
        print("[Session] Session ID updated in storage to CLI ID")
      } catch {
        print("[Session] Failed to update session ID in storage: \(error)")
      }
    }
  }

  /// Extracts the CLI session ID from a stderr line and updates the stored session
  private func extractAndUpdateSessionId(from line: String) {
    // Line format is typically "Session ID: <uuid>" or "session id: <uuid>"
    let lowercased = line.lowercased()
    guard let range = lowercased.range(of: "session id:") else { return }

    // Extract everything after "session id:"
    let afterPrefix = line[range.upperBound...].trimmingCharacters(in: .whitespaces)

    // The session ID should be the first word/token
    let cliSessionId = afterPrefix.components(separatedBy: .whitespaces).first ?? afterPrefix

    guard !cliSessionId.isEmpty else { return }

    // Only update if different from current
    guard let oldId = currentSessionId, oldId != cliSessionId else { return }

    print("[Session] Updating session ID from \(oldId) to CLI ID: \(cliSessionId)")

    // Update in-memory
    currentSessionId = cliSessionId

    // Update in storage
    Task {
      do {
        try await sessionManager.updateSessionId(oldId: oldId, newId: cliSessionId)
        print("[Session] Session ID updated in storage")
      } catch {
        print("[Session] Failed to update session ID in storage: \(error)")
      }
    }
  }

  /// Injects a restored session into the view model
  func injectSession(sessionId: String, messages: [ChatMessage], workingDirectory: String?) {
    // Clear existing state
    self.messages.removeAll()

    // Set session state
    self.currentSessionId = sessionId
    self.hasSession = true
    self.hasSessionStarted = true

    // Load messages
    self.messages = messages

    // Update session working directory if provided
    if let dir = workingDirectory, !dir.isEmpty {
      self.sessionWorkingDirectory = dir
    }

    // Clear any error state
    errorMessage = nil
    hasError = false
  }

  /// Saves the current session to storage
  func saveCurrentSession() async {
    guard let sessionId = currentSessionId, !messages.isEmpty else {
      print("[Session] Skipping save - no session ID or no messages")
      return
    }

    print("[Session] Saving \(messages.count) messages for session: \(sessionId)")

    do {
      try await sessionManager.saveMessages(sessionId: sessionId, messages: messages)
      print("[Session] Messages saved successfully")
    } catch {
      print("[Session] Failed to save session messages: \(error)")
    }
  }

  /// Starts a new session with the first message
  func startSession(withFirstMessage message: String) async {
    // Generate a session ID
    let sessionId = UUID().uuidString
    currentSessionId = sessionId
    hasSessionStarted = true

    print("[Session] Creating session with ID: \(sessionId)")

    // Detect git worktree info using session working directory
    let workingDir = sessionWorkingDirectory ?? ""
    let gitInfo = await GitWorktreeDetector.detectWorktreeInfo(for: workingDir)

    do {
      try await sessionManager.saveSession(
        id: sessionId,
        firstMessage: message,
        workingDirectory: workingDir.isEmpty ? nil : workingDir,
        branchName: gitInfo?.branch,
        isWorktree: gitInfo?.isWorktree ?? false
      )
      print("[Session] Session saved successfully: \(sessionId)")
    } catch {
      print("[Session] Failed to save session: \(error)")
    }
  }
}
