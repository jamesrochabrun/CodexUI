//
//  SkillResult.swift
//  CodexUI
//

import Foundation

/// Represents a discovered Codex skill.
struct SkillResult: Hashable, Identifiable {

  // MARK: Lifecycle

  init(
    name: String,
    description: String,
    path: String
  ) {
    self.name = name
    self.description = description
    self.path = path
    self.id = name.lowercased()
  }

  // MARK: Internal

  let id: String
  let name: String
  let description: String
  let path: String
}
