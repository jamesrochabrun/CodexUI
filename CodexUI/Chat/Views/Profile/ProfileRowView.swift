//
//  ProfileRowView.swift
//  CodexUI
//
//  A single row displaying a profile with name and risk indicator.
//  Supports compact mode (collapsed) and full mode (expanded).
//

import SwiftUI

struct ProfileRowView: View {
    let profile: CodexProfile
    let isSelected: Bool
    var isExpanded: Bool = false
    var isCompact: Bool = false
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                if isCompact {
                    compactContent
                } else {
                    fullContent
                }
            }
            .buttonStyle(.plain)

            // Delete button for custom profiles (only in full/expanded mode)
            if !isCompact, !profile.isBuiltIn, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Compact Mode (collapsed state)

    private var compactContent: some View {
        HStack(spacing: 4) {
            // Profile name (monospace, caption size)
            Text(profile.id)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            // Risk level text
            Text("(\(profile.riskLevel.rawValue) risk)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Full Mode (expanded state - shows CLI command and full details)

    private var fullContent: some View {
        HStack(spacing: 10) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.brandPrimary : .secondary.opacity(0.5))

            // Profile name + CLI command
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.id)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text(profile.cliCommand)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Risk level text
            Text("(\(profile.riskLevel.rawValue) risk)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            // Chevron only on selected row
            if isSelected {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(isSelected ? Color.brandPrimary.opacity(0.08) : Color.clear)
    }
}

#Preview("Compact") {
    ProfileRowView(
        profile: CodexProfile.builtIn[0],
        isSelected: true,
        isExpanded: false,
        isCompact: true,
        onTap: {}
    )
    .background(Color.secondary.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .padding()
}

#Preview("Full - Expanded") {
    VStack(spacing: 0) {
        ProfileRowView(
            profile: CodexProfile.builtIn[0],
            isSelected: true,
            isExpanded: true,
            isCompact: false,
            onTap: {}
        )
        Divider()
        ProfileRowView(
            profile: CodexProfile.builtIn[1],
            isSelected: false,
            isCompact: false,
            onTap: {}
        )
        Divider()
        ProfileRowView(
            profile: CodexProfile.builtIn[2],
            isSelected: false,
            isCompact: false,
            onTap: {}
        )
    }
    .frame(width: 380)
    .background(Color.secondary.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding()
}
