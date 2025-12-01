//
//  KeyboardShortcutManager.swift
//  CodexUI
//

import SwiftUI
import KeyboardShortcuts
import AppKit
import Combine
import Carbon.HIToolbox

/// Manages global keyboard shortcuts for capturing text from Xcode
@Observable
@MainActor
final class KeyboardShortcutManager {
  
  // MARK: - Observable Properties
  
  /// The captured text from CMD+I shortcut
  var capturedText: String = ""
  
  /// Whether to show the capture animation
  var showCaptureAnimation = false
  
  /// Triggers focus on the text editor
  var shouldFocusTextEditor = false
  
  /// Triggers refresh of Xcode observation
  var shouldRefreshObservation = false
  
  // MARK: - Private Properties
  
  private let xcodeObserver: XcodeObserver
  private let xcodeObservationViewModel: XcodeObservationViewModel
  private let settingsManager: SettingsManager
  private var stateSubscription: AnyCancellable?
  
  // MARK: - Initialization
  
  init(
    xcodeObserver: XcodeObserver,
    xcodeObservationViewModel: XcodeObservationViewModel,
    settingsManager: SettingsManager = .shared
  ) {
    self.xcodeObserver = xcodeObserver
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.settingsManager = settingsManager
    setupShortcuts()
    setupXcodeObservation()
  }
  
  // Note: cleanup() should be called before deallocation
  // deinit cannot access MainActor-isolated properties
  
  // MARK: - Public Methods
  
  /// Cleans up resources
  func cleanup() {
    stateSubscription?.cancel()
    stateSubscription = nil
    KeyboardShortcuts.disable([.captureWithI])
  }
  
  /// Resets the captured text state
  func resetCapturedText() {
    capturedText = ""
  }
  
  /// Resets the focus trigger
  func resetFocusTrigger() {
    shouldFocusTextEditor = false
  }
  
  /// Resets the refresh observation trigger
  func resetRefreshTrigger() {
    shouldRefreshObservation = false
  }
  
  // MARK: - Private Methods
  
  private func setupShortcuts() {
    // CMD+I shortcut for capturing selected text
    KeyboardShortcuts.onKeyUp(for: .captureWithI) { [weak self] in
      Task { @MainActor in
        self?.captureSelectedText()
      }
    }
  }
  
  private func setupXcodeObservation() {
    // Subscribe to Xcode state changes to enable/disable CMD+I hotkey
    stateSubscription = xcodeObserver.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        Task { @MainActor in
          self?.updateHotkeyState(for: state)
        }
      }
    
    // Set initial state
    Task { @MainActor in
      updateHotkeyState(for: xcodeObserver.state)
    }
  }
  
  private func updateHotkeyState(for state: XcodeObserver.State) {
    // Enable CMD+I only when ALL conditions are met:
    // 1. User has enabled the shortcut in preferences
    // 2. Accessibility permissions are granted
    // 3. At least one Xcode instance is active
    
    let hasActiveXcode = state.knownState?.contains(where: { $0.isActive }) ?? false
    let hasPermission = xcodeObservationViewModel.hasAccessibilityPermission
    let isEnabledInPreferences = settingsManager.enableXcodeShortcut
    
    let shouldEnable = isEnabledInPreferences && hasPermission && hasActiveXcode
    
    if shouldEnable {
      KeyboardShortcuts.enable([.captureWithI])
    } else {
      KeyboardShortcuts.disable([.captureWithI])
    }
  }
  
  private func captureSelectedText() {
    // Small delay to allow Xcode observation to update before clipboard capture
    // This ensures .focusedUIElementChanged notifications have time to process
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
      guard let self = self else { return }
      
      // Guard: Ensure all conditions are met before proceeding
      // This prevents issues if handler fires during state transitions
      Task { @MainActor in
        guard self.xcodeObservationViewModel.hasAccessibilityPermission,
              self.settingsManager.enableXcodeShortcut else {
          return
        }
        
        self.performClipboardCapture()
      }
    }
  }
  
  private func performClipboardCapture() {
    // Get current selection from system clipboard
    let pasteboard = NSPasteboard.general
    let oldContents = pasteboard.string(forType: .string)
    
    // Simulate CMD+C to copy current selection
    // Key code 0x08 = 'C' key
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
    
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
    
    // Wait for clipboard to update
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      if let selectedText = pasteboard.string(forType: .string),
         selectedText != oldContents {
        self?.capturedText = selectedText
        self?.showCaptureAnimation = true
        
        // Activate the app
        NSRunningApplication.current.activate()
        
        // Ensure window comes to front
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          // Find and activate the key window
          if let keyWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
            keyWindow.makeKeyAndOrderFront(nil)
          }
        }
        
        // Trigger focus on text editor
        self?.shouldFocusTextEditor = true
        
        // Hide animation after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          self?.showCaptureAnimation = false
        }
        
        // Restore old clipboard contents
        if let oldContents = oldContents {
          pasteboard.clearContents()
          pasteboard.setString(oldContents, forType: .string)
        }
      } else {
        // No selection - trigger observation refresh
        self?.shouldRefreshObservation = true
      }
    }
  }
}

// MARK: - KeyboardShortcuts Extension

extension KeyboardShortcuts.Name {
  /// CMD+I shortcut for capturing selected text from Xcode
  static let captureWithI = Self(
    "captureWithI",
    default: .init(
      carbonKeyCode: Int(kVK_ANSI_I),  // Physical key position for 'I'
      carbonModifiers: cmdKey           // Carbon modifier for Command key
    )
  )
}
