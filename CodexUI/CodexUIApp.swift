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

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(configService)
    }
  }
}
