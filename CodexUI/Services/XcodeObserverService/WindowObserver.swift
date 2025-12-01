import AppKit
import Combine
import Foundation

// MARK: - WindowObserver

/// This class observes a single window.
@XcodeInspectorActor
class WindowObserver: ObservableObject {

  // MARK: Lifecycle

  init(window: AXUIElement, state: WindowState) {
    self.window = window
    self.state = state
    window.setMessagingTimeout(2)
  }

  // MARK: Internal

  let window: AXUIElement
  @Published var state: WindowState

}
