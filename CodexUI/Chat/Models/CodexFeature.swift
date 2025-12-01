//
//  CodexFeature.swift
//  CodexUI
//
//  Defines global feature toggles that are stored in ~/.codex/config.toml [features] section
//

import Foundation

/// Represents a global feature toggle in Codex
struct CodexFeature: Identifiable, Equatable {
    let id: String           // TOML key (e.g., "web_search_request")
    let name: String         // Display name
    let description: String  // User-friendly description
    let defaultValue: Bool
    let isExperimental: Bool

    /// All available features
    static let all: [CodexFeature] = standard + experimental

    /// Standard features (always visible in Settings)
    static let standard: [CodexFeature] = [
        CodexFeature(
            id: "view_image_tool",
            name: "View Image Tool",
            description: "Allow viewing images in responses",
            defaultValue: true,
            isExperimental: false
        ),
        CodexFeature(
            id: "web_search_request",
            name: "Web Search",
            description: "Search the web for up-to-date information",
            defaultValue: false,
            isExperimental: false
        )
    ]

    /// Experimental features (hidden behind "Show Advanced Settings")
    static let experimental: [CodexFeature] = [
        CodexFeature(
            id: "unified_exec",
            name: "Unified Exec",
            description: "Enable unified exec tool",
            defaultValue: false,
            isExperimental: true
        ),
        CodexFeature(
            id: "rmcp_client",
            name: "Rust MCP Client",
            description: "Enable OAuth for HTTP MCP servers",
            defaultValue: false,
            isExperimental: true
        ),
        CodexFeature(
            id: "apply_patch_freeform",
            name: "Apply Patch Freeform",
            description: "Include apply_patch via freeform editing path",
            defaultValue: false,
            isExperimental: true
        ),
        CodexFeature(
            id: "experimental_sandbox_command_assessment",
            name: "Sandbox Command Assessment",
            description: "Experimental sandbox command assessment",
            defaultValue: false,
            isExperimental: true
        ),
        CodexFeature(
            id: "ghost_commit",
            name: "Ghost Commit",
            description: "Enable ghost commit feature",
            defaultValue: false,
            isExperimental: true
        )
    ]

    /// Get a feature by its ID
    static func feature(for id: String) -> CodexFeature? {
        all.first { $0.id == id }
    }
}
