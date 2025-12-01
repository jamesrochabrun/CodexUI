//
//  ProfileEditorView.swift
//  CodexUI
//
//  Sheet view for creating and editing configuration profiles.
//

import SwiftUI
import CodexSDK

struct ProfileEditorView: View {

    enum Mode: Identifiable {
        case create
        case edit(CodexProfile)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let profile): return "edit-\(profile.id)"
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var profileManager = ProfileManager.shared

    // Form state
    @State private var name = ""
    @State private var sandbox: CodexSandboxPolicy = .readOnly
    @State private var approval: CodexApprovalMode = .onRequest
    @State private var fullAuto = false
    @State private var model = ""
    @State private var reasoningEffort: ReasoningEffort = .medium

    // Error state
    @State private var error: String?
    @State private var isSaving = false
    @State private var showingDeleteConfirmation = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingProfile: CodexProfile? {
        if case .edit(let profile) = mode { return profile }
        return nil
    }

    /// Preview profile for displaying CLI command and risk level
    private var previewProfile: CodexProfile {
        CodexProfile(
            id: name.isEmpty ? "preview" : name,
            sandbox: sandbox,
            approval: approval,
            fullAuto: fullAuto,
            model: model.isEmpty ? nil : model,
            reasoningEffort: reasoningEffort,
            isBuiltIn: false
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name section
                    if !isEditing {
                        nameSection
                    } else {
                        // Show name as title when editing
                        HStack {
                            Text("Editing: ")
                                .foregroundStyle(.secondary)
                            Text(name)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    // Sandbox section
                    sandboxSection

                    // Approval section
                    approvalSection

                    // Full auto toggle
                    fullAutoSection

                    // Model section
                    modelSection

                    // Reasoning effort section
                    reasoningEffortSection

                    Divider()

                    // CLI command preview
                    cliPreviewSection

                    // Risk level indicator
                    riskLevelSection

                    // Error display
                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            actionButtons
        }
        .frame(width: 480, height: 580)
        .onAppear {
            if case .edit(let profile) = mode {
                loadProfile(profile)
            }
        }
        .confirmationDialog(
            "Delete Profile",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteProfile()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this profile? This cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Profile" : "Create Profile")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Profile Name")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("my-profile", text: $name)
                .textFieldStyle(.roundedBorder)

            Text("Use letters, numbers, and hyphens only")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sandboxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Access (Sandbox)")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("Sandbox", selection: $sandbox) {
                Text("Read Only").tag(CodexSandboxPolicy.readOnly)
                Text("Workspace Write").tag(CodexSandboxPolicy.workspaceWrite)
                Text("Full Access").tag(CodexSandboxPolicy.dangerFullAccess)
            }
            .pickerStyle(.segmented)

            Text(sandboxDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sandboxDescription: String {
        switch sandbox {
        case .readOnly:
            return "Can only read files, no modifications allowed"
        case .workspaceWrite:
            return "Can modify files within the workspace directory"
        case .dangerFullAccess:
            return "WARNING: Can modify any file on your system"
        }
    }

    private var approvalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirmations (Approval)")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("Approval", selection: $approval) {
                Text("Untrusted").tag(CodexApprovalMode.untrusted)
                Text("On Failure").tag(CodexApprovalMode.onFailure)
                Text("On Request").tag(CodexApprovalMode.onRequest)
                Text("Never").tag(CodexApprovalMode.never)
            }
            .pickerStyle(.segmented)

            Text(approvalDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var approvalDescription: String {
        switch approval {
        case .untrusted:
            return "Asks permission before any action"
        case .onFailure:
            return "Asks only when something goes wrong"
        case .onRequest:
            return "Asks when you specifically request"
        case .never:
            return "Never asks for permission (faster but less safe)"
        }
    }

    private var fullAutoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $fullAuto) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Auto Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Runs continuously until task is complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model Override (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("Leave empty to use default", text: $model)
                .textFieldStyle(.roundedBorder)

            Text("Override the default model from config.toml")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var reasoningEffortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reasoning Effort")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("Reasoning", selection: $reasoningEffort) {
                Text("Low").tag(ReasoningEffort.low)
                Text("Medium").tag(ReasoningEffort.medium)
                Text("High").tag(ReasoningEffort.high)
            }
            .pickerStyle(.segmented)

            Text(reasoningEffortDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var reasoningEffortDescription: String {
        switch reasoningEffort {
        case .low:
            return "Faster responses, less detailed reasoning"
        case .medium:
            return "Balanced speed and reasoning depth"
        case .high:
            return "More thorough reasoning, may be slower"
        }
    }

    private var cliPreviewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CLI Command")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Text(previewProfile.cliCommand)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(previewProfile.cliCommand, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
    }

    private var riskLevelSection: some View {
        HStack {
            Text("Risk Level")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(previewProfile.riskLevel.color)
                    .frame(width: 10, height: 10)

                Text(previewProfile.riskLevel.displayName)
                    .font(.subheadline)
                    .foregroundStyle(previewProfile.riskLevel.color)
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack {
            // Delete button (only for custom profiles)
            if isEditing, let existing = existingProfile, !existing.isBuiltIn {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Text("Delete")
                }
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Save") {
                saveProfile()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.isEmpty || isSaving)
        }
        .padding(16)
    }

    // MARK: - Actions

    private func loadProfile(_ profile: CodexProfile) {
        name = profile.id
        sandbox = profile.sandbox
        approval = profile.approval
        fullAuto = profile.fullAuto
        model = profile.model ?? ""
        reasoningEffort = profile.reasoningEffort
    }

    private func saveProfile() {
        isSaving = true
        error = nil

        do {
            if isEditing {
                var updated = existingProfile!
                updated.sandbox = sandbox
                updated.approval = approval
                updated.fullAuto = fullAuto
                updated.model = model.isEmpty ? nil : model
                updated.reasoningEffort = reasoningEffort
                try profileManager.updateProfile(updated)
            } else {
                let newProfile = CodexProfile(
                    id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
                    sandbox: sandbox,
                    approval: approval,
                    fullAuto: fullAuto,
                    model: model.isEmpty ? nil : model,
                    reasoningEffort: reasoningEffort,
                    isBuiltIn: false
                )
                try profileManager.createProfile(newProfile)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }

    private func deleteProfile() {
        guard let existing = existingProfile else { return }

        do {
            try profileManager.deleteProfile(existing.id)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview("Create") {
    ProfileEditorView(mode: .create)
}

#Preview("Edit") {
    ProfileEditorView(mode: .edit(CodexProfile.builtIn[0]))
}
