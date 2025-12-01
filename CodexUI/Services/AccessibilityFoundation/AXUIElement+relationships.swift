import AppKit

extension AXUIElement {
  public nonisolated var focusedElement: AXUIElement? {
    try? copyValue(key: kAXFocusedUIElementAttribute)
  }

  public nonisolated var sharedFocusElements: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  public nonisolated var window: AXUIElement? {
    try? copyValue(key: kAXWindowAttribute)
  }

  public nonisolated var windows: [AXUIElement] {
    (try? copyValue(key: kAXWindowsAttribute)) ?? []
  }

  public nonisolated var isFullScreen: Bool {
    (try? copyValue(key: "AXFullScreen")) ?? false
  }

  public nonisolated var focusedWindow: AXUIElement? {
    try? copyValue(key: kAXFocusedWindowAttribute)
  }

  public nonisolated var topLevelElement: AXUIElement? {
    try? copyValue(key: kAXTopLevelUIElementAttribute)
  }

  public nonisolated var rows: [AXUIElement] {
    (try? copyValue(key: kAXRowsAttribute)) ?? []
  }

  public nonisolated var parent: AXUIElement? {
    try? copyValue(key: kAXParentAttribute)
  }

  public nonisolated var children: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  public nonisolated var menuBar: AXUIElement? {
    try? copyValue(key: kAXMenuBarAttribute)
  }

  public nonisolated var verticalScrollBar: AXUIElement? {
    try? copyValue(key: kAXVerticalScrollBarAttribute)
  }

}
