//
//  ProfileManager.swift
//  CodexUI
//
//  Manages Codex configuration profiles stored in ~/.codex/config.toml
//

import Foundation
import CodexSDK

/// Errors that can occur during profile operations
enum ProfileError: LocalizedError {
    case cannotModifyBuiltIn
    case invalidProfileName
    case fileReadError(String)
    case fileWriteError(String)
    case profileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .cannotModifyBuiltIn:
            return "Built-in profiles cannot be modified or deleted"
        case .invalidProfileName:
            return "Invalid profile name. Use only letters, numbers, and hyphens."
        case .fileReadError(let message):
            return "Failed to read config file: \(message)"
        case .fileWriteError(let message):
            return "Failed to write config file: \(message)"
        case .profileNotFound(let name):
            return "Profile '\(name)' not found"
        }
    }
}

/// Manages Codex configuration profiles
@Observable
@MainActor
final class ProfileManager {

    static let shared = ProfileManager()

    // MARK: - Public Properties

    private(set) var profiles: [CodexProfile] = []
    private(set) var isLoading = false
    private(set) var error: String?

    var activeProfileId: String? {
        didSet {
            UserDefaults.standard.set(activeProfileId, forKey: activeProfileKey)
        }
    }

    var activeProfile: CodexProfile? {
        profiles.first { $0.id == activeProfileId }
    }

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let activeProfileKey = "com.codexui.activeProfileId"

    private var codexPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.codex"
    }

    private var configPath: String {
        "\(codexPath)/config.toml"
    }

    // MARK: - Init

    private init() {
        ensureBuiltInProfilesExist()
        loadProfiles()
        restoreActiveProfile()
    }

    // MARK: - Public API

    /// Reload profiles from config.toml
    func loadProfiles() {
        isLoading = true
        error = nil

        // Start with built-in profiles
        var loadedProfiles = CodexProfile.builtIn

        // Parse custom profiles from config.toml
        if let customProfiles = parseProfilesFromTOML() {
            // Custom profiles can override built-ins with same name
            let customIds = Set(customProfiles.map(\.id))
            loadedProfiles = loadedProfiles.filter { !customIds.contains($0.id) }
            loadedProfiles.append(contentsOf: customProfiles)
        }

        // Sort: built-ins first, then custom alphabetically
        profiles = loadedProfiles.sorted { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn {
                return lhs.isBuiltIn
            }
            return lhs.id < rhs.id
        }

        isLoading = false
    }

    /// Create a new custom profile
    func createProfile(_ profile: CodexProfile) throws {
        guard isValidProfileName(profile.id) else {
            throw ProfileError.invalidProfileName
        }

        // Ensure it's marked as custom
        var newProfile = profile
        newProfile.isBuiltIn = false

        try writeProfileToTOML(newProfile)
        loadProfiles()

        // Auto-select the new profile
        activeProfileId = newProfile.id
    }

    /// Update an existing profile (writes to TOML immediately)
    func updateProfile(_ profile: CodexProfile) throws {
        try writeProfileToTOML(profile)
        loadProfiles()
    }

    /// System profile IDs that cannot be deleted
    private static let systemProfileIds = ["safe", "ci", "ask", "auto", "yolo"]

    /// Delete a profile (system profiles cannot be deleted)
    func deleteProfile(_ profileId: String) throws {
        guard profiles.contains(where: { $0.id == profileId }) else {
            throw ProfileError.profileNotFound(profileId)
        }

        guard !Self.systemProfileIds.contains(profileId) else {
            throw ProfileError.cannotModifyBuiltIn
        }

        try removeProfileFromTOML(profileId)
        loadProfiles()

        // Clear active if deleted
        if activeProfileId == profileId {
            activeProfileId = nil
        }
    }

    /// Set the active profile
    func setActiveProfile(_ profileId: String?) {
        activeProfileId = profileId
    }

    // MARK: - TOML Parsing

    private func parseProfilesFromTOML() -> [CodexProfile]? {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return nil
        }

        var profiles: [CodexProfile] = []
        let lines = content.components(separatedBy: .newlines)
        var currentProfileId: String?
        var currentProfileData: [String: String] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for [profiles.NAME] section
            if let profileId = parseProfileSectionHeader(trimmed) {
                // Save previous profile if exists
                if let id = currentProfileId {
                    if let profile = buildProfile(id: id, data: currentProfileData) {
                        profiles.append(profile)
                    }
                }
                currentProfileId = profileId
                currentProfileData = [:]
            }
            // If we're inside a profile section, parse key = value
            else if currentProfileId != nil {
                // Check if we hit a new section (not profiles.*)
                if trimmed.hasPrefix("[") && !trimmed.hasPrefix("[profiles.") {
                    // Save current profile and exit profile parsing
                    if let id = currentProfileId {
                        if let profile = buildProfile(id: id, data: currentProfileData) {
                            profiles.append(profile)
                        }
                    }
                    currentProfileId = nil
                    currentProfileData = [:]
                }
                // Parse key = value or key = "value"
                else if let (key, value) = parseTomlKeyValue(trimmed) {
                    currentProfileData[key] = value
                }
            }
        }

        // Don't forget the last profile
        if let id = currentProfileId {
            if let profile = buildProfile(id: id, data: currentProfileData) {
                profiles.append(profile)
            }
        }

        return profiles.isEmpty ? nil : profiles
    }

    private func parseProfileSectionHeader(_ line: String) -> String? {
        // Match [profiles.NAME]
        let pattern = #"^\[profiles\.([a-zA-Z0-9_-]+)\]$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let nameRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[nameRange])
    }

    private func parseTomlKeyValue(_ line: String) -> (String, String)? {
        // Skip comments and empty lines
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") {
            return nil
        }

        // Match key = "value" or key = value
        let pattern = #"^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(?:"([^"]*)"|([^\s#]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let keyRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        let key = String(line[keyRange])
        var value: String?

        // Try quoted value first
        if let quotedRange = Range(match.range(at: 2), in: line) {
            value = String(line[quotedRange])
        }
        // Then unquoted value
        else if let unquotedRange = Range(match.range(at: 3), in: line) {
            value = String(line[unquotedRange])
        }

        guard let val = value else { return nil }
        return (key, val)
    }

    private func buildProfile(id: String, data: [String: String]) -> CodexProfile? {
        // Parse sandbox
        let sandbox: CodexSandboxPolicy
        if let sandboxStr = data["sandbox"],
           let policy = CodexSandboxPolicy(rawValue: sandboxStr) {
            sandbox = policy
        } else {
            sandbox = .readOnly
        }

        // Parse approval
        let approval: CodexApprovalMode
        if let approvalStr = data["approval"],
           let mode = CodexApprovalMode(rawValue: approvalStr) {
            approval = mode
        } else {
            approval = .onRequest
        }

        // Parse full_auto
        let fullAuto = data["full_auto"] == "true"

        // Parse model
        let model = data["model"]

        // Parse reasoning effort
        let reasoningEffort: ReasoningEffort
        if let effortStr = data["model_reasoning_effort"],
           let effort = ReasoningEffort(rawValue: effortStr) {
            reasoningEffort = effort
        } else {
            reasoningEffort = .medium
        }

        return CodexProfile(
            id: id,
            sandbox: sandbox,
            approval: approval,
            fullAuto: fullAuto,
            model: model,
            reasoningEffort: reasoningEffort,
            isBuiltIn: false
        )
    }

    // MARK: - TOML Writing

    private func writeProfileToTOML(_ profile: CodexProfile) throws {
        // Read existing content
        var content = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""

        // Generate new profile section
        let section = generateProfileSection(profile)

        // Check if profile already exists
        let sectionHeader = "[profiles.\(profile.id)]"
        if content.contains(sectionHeader) {
            // Replace existing section
            content = replaceProfileSection(in: content, profileId: profile.id, with: section)
        } else {
            // Append new section
            if !content.hasSuffix("\n") && !content.isEmpty {
                content += "\n"
            }
            content += "\n" + section
        }

        // Write back
        do {
            try content.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            throw ProfileError.fileWriteError(error.localizedDescription)
        }
    }

    private func generateProfileSection(_ profile: CodexProfile) -> String {
        var lines: [String] = []
        lines.append("[profiles.\(profile.id)]")
        lines.append("sandbox = \"\(profile.sandbox.rawValue)\"")
        lines.append("approval = \"\(profile.approval.rawValue)\"")
        lines.append("full_auto = \(profile.fullAuto)")
        lines.append("model_reasoning_effort = \"\(profile.reasoningEffort.rawValue)\"")
        if let model = profile.model, !model.isEmpty {
            lines.append("model = \"\(model)\"")
        }
        return lines.joined(separator: "\n")
    }

    private func replaceProfileSection(in content: String, profileId: String, with newSection: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var skipping = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if this is the target profile section
            if trimmed == "[profiles.\(profileId)]" {
                skipping = true
                // Insert new section
                result.append(contentsOf: newSection.components(separatedBy: "\n"))
                continue
            }

            // Check if we hit another section
            if skipping && trimmed.hasPrefix("[") {
                skipping = false
            }

            if !skipping {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }

    private func removeProfileFromTOML(_ profileId: String) throws {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return
        }

        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var skipping = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if this is the target profile section
            if trimmed == "[profiles.\(profileId)]" {
                skipping = true
                continue
            }

            // Check if we hit another section
            if skipping && trimmed.hasPrefix("[") {
                skipping = false
            }

            if !skipping {
                result.append(line)
            }
        }

        // Clean up extra blank lines
        var cleanedResult: [String] = []
        var lastWasBlank = false
        for line in result {
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if isBlank && lastWasBlank {
                continue
            }
            cleanedResult.append(line)
            lastWasBlank = isBlank
        }

        let newContent = cleanedResult.joined(separator: "\n")

        do {
            try newContent.write(toFile: configPath, atomically: true, encoding: .utf8)
        } catch {
            throw ProfileError.fileWriteError(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func restoreActiveProfile() {
        if let savedId = UserDefaults.standard.string(forKey: activeProfileKey),
           profiles.contains(where: { $0.id == savedId }) {
            activeProfileId = savedId
        }
    }

    private func isValidProfileName(_ name: String) -> Bool {
        let pattern = #"^[a-zA-Z][a-zA-Z0-9_-]*$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }

    /// Ensures built-in profiles exist in config.toml (required for --profile flag)
    private func ensureBuiltInProfilesExist() {
        for profile in CodexProfile.builtIn {
            if !profileExistsInTOML(profile.id) {
                try? writeProfileToTOML(profile)
            }
        }
    }

    private func profileExistsInTOML(_ profileId: String) -> Bool {
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return false
        }
        return content.contains("[profiles.\(profileId)]")
    }
}
