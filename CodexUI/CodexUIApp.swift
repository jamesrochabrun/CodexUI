//
//  CodexUIApp.swift
//  CodexUI
//
//  Created by James Rochabrun on 11/23/25.
//

import SwiftUI

@main
struct CodexUIApp: App {
  @State private var configService = CodexConfigService()

  // Xcode observability services
  private let terminalService: TerminalService
  private let accessibilityService: AccessibilityService
  private let permissionsService: PermissionsService
  private let xcodeObserver: XcodeObserver

  // ViewModel and managers (MainActor-isolated)
  @State private var xcodeObservationViewModel: XcodeObservationViewModel?
  @State private var keyboardShortcutManager: KeyboardShortcutManager?

  init() {
    // Initialize services
    let terminal = DefaultTerminalService()
    let accessibility = DefaultAccessibilityService()

    let permissions = DefaultPermissionsService(
      terminalService: terminal,
      userDefaults: .standard,
      bundle: .main,
      isAccessibilityPermissionGrantedClosure: { AXIsProcessTrusted() }
    )

    let observer = DefaultXcodeObserver(
      accessibilityService: accessibility,
      permissionsService: permissions
    )

    self.terminalService = terminal
    self.accessibilityService = accessibility
    self.permissionsService = permissions
    self.xcodeObserver = observer
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(configService)
        .environment(\.permissionsService, permissionsService)
        .environment(\.xcodeObserver, xcodeObserver)
        .environment(\.xcodeObservationViewModel, xcodeObservationViewModel)
        .environment(\.keyboardShortcutManager, keyboardShortcutManager)
        .task {
          // Initialize MainActor-isolated objects
          if xcodeObservationViewModel == nil {
            let observationVM = XcodeObservationViewModel(xcodeObserver: xcodeObserver)
            xcodeObservationViewModel = observationVM

            // Initialize KeyboardShortcutManager after XcodeObservationViewModel
            keyboardShortcutManager = KeyboardShortcutManager(
              xcodeObserver: xcodeObserver,
              xcodeObservationViewModel: observationVM
            )
          }
        }
    }
  }
}
