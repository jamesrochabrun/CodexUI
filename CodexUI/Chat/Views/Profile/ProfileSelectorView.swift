//
//  ProfileSelectorView.swift
//  CodexUI
//
//  An expandable inline selector for choosing configuration profiles.
//  Shows current profile collapsed, expands on tap to show all options.
//

import SwiftUI
import CodexSDK

struct ProfileSelectorView: View {

  var isDisabled: Bool = false

  @State private var profileManager = ProfileManager.shared
  @State private var isExpanded = false
  @State private var showingEditor = false
  @State private var editingProfile: CodexProfile?
  
  /// Default profile to show when none is selected
  private var defaultProfile: CodexProfile {
    CodexProfile.builtIn.first ?? CodexProfile(
      id: "default",
      sandbox: .readOnly,
      approval: .onRequest,
      fullAuto: false,
      model: nil,
      reasoningEffort: .medium,
      isBuiltIn: true
    )
  }
  
  private var currentProfile: CodexProfile {
    profileManager.activeProfile ?? defaultProfile
  }

  /// System profiles that cannot be deleted (but can be edited)
  private func isSystemProfile(_ id: String) -> Bool {
    ["safe", "auto", "yolo"].contains(id)
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Current profile button (always visible) - compact when collapsed
      ProfileRowView(
        profile: currentProfile,
        isSelected: true,
        isExpanded: isExpanded,
        isCompact: !isExpanded,
        onTap: {
          guard !isDisabled else { return }
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        }
      )

      // Expanded list of profiles
      if isExpanded && !isDisabled {
        expandedContent
      }
    }
    // Only apply styling when expanded - full width when expanded
    .frame(maxWidth: isExpanded ? .infinity : nil)
    .background(isExpanded ? Color.secondary.opacity(0.05) : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(isExpanded ? Color.secondary.opacity(0.15) : Color.clear, lineWidth: 0.5)
    )
    .opacity(isDisabled ? 0.5 : 1.0)
    .sheet(isPresented: $showingEditor) {
      ProfileEditorView(mode: .create)
    }
    .sheet(item: $editingProfile) { profile in
      ProfileEditorView(mode: .edit(profile))
    }
  }
  
  @ViewBuilder
  private var expandedContent: some View {
    Divider()
    
    // Other profiles (not the current one)
    ForEach(profileManager.profiles) { profile in
      if profile.id != currentProfile.id {
        ProfileRowView(
          profile: profile,
          isSelected: false,
          onTap: {
            profileManager.setActiveProfile(profile.id)
            withAnimation(.easeInOut(duration: 0.2)) {
              isExpanded = false
            }
          },
          onEdit: {
            editingProfile = profile
          },
          onDelete: isSystemProfile(profile.id) ? nil : {
            try? profileManager.deleteProfile(profile.id)
          }
        )

        Divider()
      }
    }
    
    // Create profile button
    Button {
      showingEditor = true
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "plus.circle")
          .font(.system(size: 14))
          .foregroundStyle(Color.brandPrimary)
        
        Text("Create Profile...")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color.brandPrimary)
        
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    
    // Use default option (when a profile is selected)
    if profileManager.activeProfileId != nil {
      Divider()
      
      Button {
        profileManager.setActiveProfile(nil)
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded = false
        }
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "arrow.uturn.backward")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
          
          Text("Use Default")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
          
          Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }
}

#Preview("Compact") {
  ProfileSelectorView()
    .padding()
}

#Preview("In Context") {
  VStack {
    Spacer()
    Text("Chat input would be here")
      .padding()
      .background(Color.secondary.opacity(0.1))
    
    HStack {
      ProfileSelectorView()
      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }
  .frame(width: 400, height: 200)
}
