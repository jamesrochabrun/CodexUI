//
//  SkillDiscovery.swift
//  CodexUI
//

import Foundation

enum SkillDiscovery {

  /// Discover skills by scanning known Codex skill locations in priority order.
  static func discoverSkills(projectPath: String?) -> [SkillResult] {
    let roots = skillRoots(projectPath: projectPath)
    var seenNames = Set<String>()
    var results: [SkillResult] = []

    for root in roots {
      guard FileManager.default.fileExists(atPath: root.path) else { continue }
      let skillFiles = findSkillFiles(in: root)
      for skillFile in skillFiles {
        guard let skill = parseSkill(at: skillFile) else { continue }
        let nameKey = skill.name.lowercased()
        if !seenNames.contains(nameKey) {
          results.append(skill)
          seenNames.insert(nameKey)
        }
      }
    }

    return results
  }

  // MARK: - Roots

  private static func skillRoots(projectPath: String?) -> [URL] {
    let fileManager = FileManager.default
    var roots: [URL] = []
    var seen = Set<String>()

    // Order matches Codex skill precedence:
    // 1) CWD/.codex/skills
    // 2) CWD/../.codex/skills
    // 3) repo root/.codex/skills
    // 4) $CODEX_HOME/skills (defaults to ~/.codex/skills)
    // 5) /etc/codex/skills

    let workingPath: String = {
      if let projectPath, !projectPath.isEmpty {
        return projectPath
      }
      return fileManager.currentDirectoryPath
    }()

    let workingURL = URL(fileURLWithPath: workingPath)

    addRoot(workingURL.appendingPathComponent(".codex/skills"), to: &roots, seen: &seen)

    let parentURL = workingURL.deletingLastPathComponent()
    if parentURL.path != workingURL.path {
      addRoot(parentURL.appendingPathComponent(".codex/skills"), to: &roots, seen: &seen)
    }

    if let repoRoot = findGitRoot(startingAt: workingURL) {
      addRoot(repoRoot.appendingPathComponent(".codex/skills"), to: &roots, seen: &seen)
    }

    let codexHome = codexHomePath(fileManager: fileManager)
    addRoot(URL(fileURLWithPath: codexHome).appendingPathComponent("skills"), to: &roots, seen: &seen)

    addRoot(URL(fileURLWithPath: "/etc/codex/skills"), to: &roots, seen: &seen)

    return roots
  }

  private static func addRoot(_ url: URL, to roots: inout [URL], seen: inout Set<String>) {
    let standardized = url.standardizedFileURL.path
    guard !seen.contains(standardized) else { return }
    roots.append(url)
    seen.insert(standardized)
  }

  private static func codexHomePath(fileManager: FileManager) -> String {
    if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"],
       !codexHome.isEmpty {
      return codexHome
    }
    return fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex")
      .path
  }

  private static func findGitRoot(startingAt url: URL) -> URL? {
    var current = url
    let fileManager = FileManager.default

    while current.path != "/" {
      let gitPath = current.appendingPathComponent(".git").path
      if fileManager.fileExists(atPath: gitPath) {
        return current
      }
      let parent = current.deletingLastPathComponent()
      if parent.path == current.path {
        break
      }
      current = parent
    }
    return nil
  }

  // MARK: - Parsing

  private static func findSkillFiles(in root: URL) -> [URL] {
    var results: [URL] = []
    guard let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
      options: [.skipsPackageDescendants]
    ) else {
      return results
    }

    for case let fileURL as URL in enumerator {
      let lastComponent = fileURL.lastPathComponent
      if lastComponent == ".git" {
        enumerator.skipDescendants()
        continue
      }
      if lastComponent == "SKILL.md" {
        results.append(fileURL)
      }
    }

    return results
  }

  private static func parseSkill(at url: URL) -> SkillResult? {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    let lines = content.components(separatedBy: .newlines)
    guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
          firstLine == "---" else {
      return nil
    }

    var frontmatterLines: [String] = []
    for line in lines.dropFirst() {
      if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
        break
      }
      frontmatterLines.append(line)
    }

    let skillFolder = url.deletingLastPathComponent()
    let fallbackName = skillFolder.lastPathComponent
    let name = parseFrontmatterValue("name", lines: frontmatterLines) ?? fallbackName
    let description = parseFrontmatterValue("description", lines: frontmatterLines) ?? ""

    return SkillResult(name: name, description: description, path: skillFolder.path)
  }

  private static func parseFrontmatterValue(_ key: String, lines: [String]) -> String? {
    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard trimmed.hasPrefix("\(key):") else { continue }
      let valueStart = trimmed.index(trimmed.startIndex, offsetBy: key.count + 1)
      var value = String(trimmed[valueStart...]).trimmingCharacters(in: .whitespaces)
      if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
        value.removeFirst()
        value.removeLast()
      } else if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
        value.removeFirst()
        value.removeLast()
      }
      return value
    }
    return nil
  }
}
