//
//  EnvironmentKeys.swift
//  CodexUI
//

import SwiftUI

// MARK: - PermissionsServiceKey

private struct PermissionsServiceKey: EnvironmentKey {
  static let defaultValue: PermissionsService? = nil
}

// MARK: - XcodeObserverKey

private struct XcodeObserverKey: EnvironmentKey {
  static let defaultValue: XcodeObserver? = nil
}

// MARK: - XcodeObservationViewModelKey

private struct XcodeObservationViewModelKey: EnvironmentKey {
  @MainActor static let defaultValue: XcodeObservationViewModel? = nil
}

// MARK: - KeyboardShortcutManagerKey

private struct KeyboardShortcutManagerKey: EnvironmentKey {
  @MainActor static let defaultValue: KeyboardShortcutManager? = nil
}

// MARK: - EnvironmentValues

extension EnvironmentValues {
  var permissionsService: PermissionsService? {
    get { self[PermissionsServiceKey.self] }
    set { self[PermissionsServiceKey.self] = newValue }
  }

  var xcodeObserver: XcodeObserver? {
    get { self[XcodeObserverKey.self] }
    set { self[XcodeObserverKey.self] = newValue }
  }

  @MainActor
  var xcodeObservationViewModel: XcodeObservationViewModel? {
    get { self[XcodeObservationViewModelKey.self] }
    set { self[XcodeObservationViewModelKey.self] = newValue }
  }

  @MainActor
  var keyboardShortcutManager: KeyboardShortcutManager? {
    get { self[KeyboardShortcutManagerKey.self] }
    set { self[KeyboardShortcutManagerKey.self] = newValue }
  }
}
