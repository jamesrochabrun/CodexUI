//
//  XcodeFileInfoView.swift
//  CodexUI
//

import SwiftUI

/// Displays information about the currently active file in Xcode
struct XcodeFileInfoView: View {
  
  let xcodeObservationViewModel: XcodeObservationViewModel
  
  @State private var isHovering = false
  
  var body: some View {
    Group {
      if xcodeObservationViewModel.hasAccessibilityPermission {
        if let activeFile = xcodeObservationViewModel.workspaceModel.activeFile {
          activeFileView(activeFile)
        } else if let workspaceName = xcodeObservationViewModel.workspaceModel.workspaceName {
          workspaceOnlyView(workspaceName)
        } else {
          noFileView
        }
      } else {
        permissionRequiredView
      }
    }
  }
  
  // MARK: - Subviews
  
  @ViewBuilder
  private func activeFileView(_ file: XcodeFileInfo) -> some View {
    HStack(spacing: 6) {
      Image(systemName: iconForFile(file))
        .foregroundStyle(.secondary)
        .font(.system(size: 12))
      
      VStack(alignment: .leading, spacing: 1) {
        Text(file.name)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)
        
        if isHovering {
          Text(file.path)
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      
      Spacer(minLength: 0)
      
      if let language = file.language {
        Text(language)
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(.quaternary)
          .clipShape(RoundedRectangle(cornerRadius: 3))
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(Color.accentColor.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovering = hovering
      }
    }
  }
  
  @ViewBuilder
  private func workspaceOnlyView(_ workspaceName: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "folder.fill")
        .foregroundStyle(.secondary)
        .font(.system(size: 12))
      
      Text(workspaceName)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      
      Spacer(minLength: 0)
      
      Text("No file selected")
        .font(.system(size: 9))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(.quaternary.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
  
  private var noFileView: some View {
    HStack(spacing: 6) {
      Image(systemName: "xcode")
        .foregroundStyle(.secondary)
        .font(.system(size: 12))
      
      Text("No Xcode file detected")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
      
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
  
  private var permissionRequiredView: some View {
    HStack(spacing: 6) {
      Image(systemName: "lock.fill")
        .foregroundStyle(.orange)
        .font(.system(size: 12))
      
      Text("Accessibility permission required")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      
      Spacer(minLength: 0)
      
      Button("Grant") {
        openAccessibilitySettings()
      }
      .buttonStyle(.borderless)
      .font(.system(size: 10, weight: .medium))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(.orange.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
  
  // MARK: - Helpers
  
  private func iconForFile(_ file: XcodeFileInfo) -> String {
    guard let ext = file.fileExtension?.lowercased() else {
      return "doc.text"
    }
    
    switch ext {
    case "swift":
      return "swift"
    case "m", "mm", "h", "hpp", "c", "cpp":
      return "chevron.left.forwardslash.chevron.right"
    case "js", "jsx", "ts", "tsx":
      return "curlybraces"
    case "json":
      return "curlybraces.square"
    case "xml", "plist":
      return "chevron.left.slash.chevron.right"
    case "md", "txt":
      return "doc.text"
    case "yml", "yaml":
      return "list.bullet.indent"
    case "sh", "bash", "zsh":
      return "terminal"
    case "png", "jpg", "jpeg", "gif", "svg":
      return "photo"
    case "xcassets":
      return "folder.badge.gearshape"
    case "storyboard", "xib":
      return "rectangle.3.group"
    default:
      return "doc"
    }
  }
  
  private func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }
}

// MARK: - Compact Variant

/// A more compact version of XcodeFileInfoView for toolbar use
struct XcodeFileInfoCompactView: View {
  
  let xcodeObservationViewModel: XcodeObservationViewModel
  
  var body: some View {
    Group {
      if xcodeObservationViewModel.hasAccessibilityPermission {
        if let activeFile = xcodeObservationViewModel.workspaceModel.activeFile {
          HStack(spacing: 4) {
            Image(systemName: "swift")
              .foregroundStyle(.orange)
              .font(.system(size: 10))
            
            Text(activeFile.name)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        } else {
          Image(systemName: "xcode")
            .foregroundStyle(.secondary)
            .font(.system(size: 10))
        }
      } else {
        Image(systemName: "lock.fill")
          .foregroundStyle(.orange)
          .font(.system(size: 10))
      }
    }
    .help(xcodeObservationViewModel.stateSummary)
  }
}

// Preview requires live XcodeObserver - disabled for now
// #Preview("With Active File") {
//   XcodeFileInfoView(xcodeObservationViewModel: ...)
// }
