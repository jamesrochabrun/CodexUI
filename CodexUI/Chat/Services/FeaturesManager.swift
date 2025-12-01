//
//  FeaturesManager.swift
//  CodexUI
//
//  Manages global feature toggles in ~/.codex/config.toml [features] section
//

import Foundation

/// Manages global feature toggles that persist to config.toml
@Observable
@MainActor
final class FeaturesManager {

    static let shared = FeaturesManager()

    // MARK: - Public Properties

    /// Current feature values (keyed by feature ID)
    private(set) var featureValues: [String: Bool] = [:]

    /// Whether to show advanced/experimental settings in UI
    /// This is stored in UserDefaults as it's a UI preference, not a CLI config
    var showAdvancedSettings: Bool {
        didSet {
            UserDefaults.standard.set(showAdvancedSettings, forKey: showAdvancedKey)
        }
    }

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let showAdvancedKey = "com.codexui.showAdvancedSettings"

    private var codexPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.codex"
    }

    private var configPath: String {
        "\(codexPath)/config.toml"
    }

    // MARK: - Init

    private init() {
        self.showAdvancedSettings = UserDefaults.standard.bool(forKey: showAdvancedKey)
        loadFeatures()
    }

    // MARK: - Public API

    /// Check if a feature is enabled
    func isEnabled(_ featureId: String) -> Bool {
        if let value = featureValues[featureId] {
            return value
        }
        // Return default value if not set
        return CodexFeature.feature(for: featureId)?.defaultValue ?? false
    }

    /// Set a feature's enabled state
    func setEnabled(_ enabled: Bool, for featureId: String) {
        featureValues[featureId] = enabled
        saveFeatures()
    }

    /// Reload features from config.toml
    func loadFeatures() {
        // Start with default values
        var values: [String: Bool] = [:]
        for feature in CodexFeature.all {
            values[feature.id] = feature.defaultValue
        }

        // Override with values from config.toml
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            featureValues = values
            return
        }

        var inFeaturesSection = false
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for [features] section
            if trimmed == "[features]" {
                inFeaturesSection = true
                continue
            }

            // Check if we hit another section
            if inFeaturesSection && trimmed.hasPrefix("[") {
                break
            }

            // Parse feature values
            if inFeaturesSection {
                if let (key, value) = parseFeatureLine(trimmed) {
                    values[key] = value
                }
            }
        }

        featureValues = values
    }

    // MARK: - Private Methods

    private func parseFeatureLine(_ line: String) -> (String, Bool)? {
        // Skip comments and empty lines
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") {
            return nil
        }

        // Match key = true/false
        let pattern = #"^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(true|false)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let keyRange = Range(match.range(at: 1), in: line),
              let valueRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let key = String(line[keyRange])
        let value = String(line[valueRange]) == "true"
        return (key, value)
    }

    private func saveFeatures() {
        // Ensure .codex directory exists
        try? fileManager.createDirectory(atPath: codexPath, withIntermediateDirectories: true)

        // Read existing content
        var content = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""

        // Generate [features] section
        let featuresSection = generateFeaturesSection()

        // Check if [features] section exists
        if content.contains("[features]") {
            content = replaceFeaturesSection(in: content, with: featuresSection)
        } else {
            // Append new section
            if !content.isEmpty && !content.hasSuffix("\n") {
                content += "\n"
            }
            if !content.isEmpty {
                content += "\n"
            }
            content += featuresSection + "\n"
        }

        try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    private func generateFeaturesSection() -> String {
        var lines: [String] = ["[features]"]

        // Write all features in consistent order
        for feature in CodexFeature.all {
            let value = featureValues[feature.id] ?? feature.defaultValue
            lines.append("\(feature.id) = \(value)")
        }

        return lines.joined(separator: "\n")
    }

    private func replaceFeaturesSection(in content: String, with newSection: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var skipping = false
        var inserted = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if this is the [features] section
            if trimmed == "[features]" {
                skipping = true
                // Insert new section
                result.append(contentsOf: newSection.components(separatedBy: "\n"))
                inserted = true
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

        // If we never found [features] section, append it
        if !inserted {
            if !result.isEmpty && result.last?.isEmpty == false {
                result.append("")
            }
            result.append(contentsOf: newSection.components(separatedBy: "\n"))
        }

        return result.joined(separator: "\n")
    }
}
