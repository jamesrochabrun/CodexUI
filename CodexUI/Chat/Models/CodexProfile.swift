//
//  CodexProfile.swift
//  CodexUI
//
//  Configuration profile for Codex CLI execution.
//

import Foundation
import SwiftUI
import CodexSDK

/// Risk level for visual indicators
enum ProfileRiskLevel: String, Codable, CaseIterable, Sendable {
    case low      // Green - read-only, approval required
    case medium   // Yellow - workspace write, some approval
    case high     // Red - full access, no approval

    var color: Color {
        switch self {
        case .low: return .riskLow
        case .medium: return .riskMedium
        case .high: return .riskHigh
        }
    }

    var icon: String {
        switch self {
        case .low: return "shield.checkmark.fill"
        case .medium: return "shield.fill"
        case .high: return "exclamationmark.shield.fill"
        }
    }

    var displayName: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }

    var shortName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
}

/// Reasoning effort level
enum ReasoningEffort: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high

    var displayName: String {
        rawValue.capitalized
    }
}

/// A configuration profile stored in ~/.codex/config.toml
struct CodexProfile: Identifiable, Codable, Equatable, Sendable {
    var id: String              // Profile name (e.g., "safe", "auto", "my-custom")
    var sandbox: CodexSandboxPolicy
    var approval: CodexApprovalMode
    var fullAuto: Bool
    var model: String?          // Optional model override
    var isBuiltIn: Bool         // true for safe/auto/yolo

    /// Computed risk level based on settings
    var riskLevel: ProfileRiskLevel {
        if sandbox == .dangerFullAccess || approval == .never {
            return .high
        } else if sandbox == .workspaceWrite {
            return .medium
        }
        return .low
    }

    /// Generate CLI command string for display
    var cliCommand: String {
        var parts = ["codex"]

        // Use shorthand flags where applicable
        if fullAuto && sandbox == .workspaceWrite && approval == .onRequest {
            parts.append("--full-auto")
        } else if sandbox == .dangerFullAccess && approval == .never {
            parts.append("--dangerously-bypass-approvals-and-sandbox")
        } else {
            parts.append("--sandbox \(sandbox.rawValue)")
            parts.append("--approval \(approval.rawValue)")
            if fullAuto {
                parts.append("--full-auto")
            }
        }

        if let model = model, !model.isEmpty {
            parts.append("--model \(model)")
        }

        return parts.joined(separator: " ")
    }

    /// Short description of the profile
    var description: String {
        switch id {
        case "safe":
            return "Read-only sandbox with approval prompts"
        case "auto":
            return "Workspace writes with auto-approval"
        case "yolo":
            return "Full access, no approvals - use with caution"
        default:
            return "Custom configuration"
        }
    }

    /// Built-in profiles matching CLI documentation
    static let builtIn: [CodexProfile] = [
        CodexProfile(
            id: "safe",
            sandbox: .readOnly,
            approval: .onRequest,
            fullAuto: false,
            model: nil,
            isBuiltIn: true
        ),
        CodexProfile(
            id: "auto",
            sandbox: .workspaceWrite,
            approval: .onRequest,
            fullAuto: true,
            model: nil,
            isBuiltIn: true
        ),
        CodexProfile(
            id: "yolo",
            sandbox: .dangerFullAccess,
            approval: .never,
            fullAuto: true,
            model: nil,
            isBuiltIn: true
        )
    ]

    /// Convert to CodexExecOptions for SDK use
    func toExecOptions() -> CodexExecOptions {
        var options = CodexExecOptions()
        options.sandbox = sandbox
        options.approval = approval
        options.fullAuto = fullAuto
        if let model = model, !model.isEmpty {
            options.model = model
        }
        return options
    }
}

// MARK: - Codable conformance for SDK enums

extension CodexSandboxPolicy: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let policy = CodexSandboxPolicy(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid sandbox policy: \(rawValue)"
            )
        }
        self = policy
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension CodexApprovalMode: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let mode = CodexApprovalMode(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid approval mode: \(rawValue)"
            )
        }
        self = mode
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Display name extensions

extension CodexSandboxPolicy {
    var displayName: String {
        switch self {
        case .readOnly: return "Read Only"
        case .workspaceWrite: return "Workspace Write"
        case .dangerFullAccess: return "Full Access"
        }
    }
}

extension CodexApprovalMode {
    var displayName: String {
        switch self {
        case .untrusted: return "Untrusted"
        case .onFailure: return "On Failure"
        case .onRequest: return "On Request"
        case .never: return "Never"
        }
    }
}
