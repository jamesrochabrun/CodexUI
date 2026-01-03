//
//  SkillResult+InlineSearchResult.swift
//  CodexUI
//

import SwiftUI

extension SkillResult: InlineSearchResult {
  var title: String { name }
  var subtitle: String {
    let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? path : trimmed
  }

  var iconName: String { "sparkles" }

  var iconColor: Color { .brandPrimary }
}
