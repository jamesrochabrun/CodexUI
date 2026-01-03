//
//  SkillSearchViewModel.swift
//  CodexUI
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SkillSearchViewModel {
  // MARK: - Properties

  private var projectPath: String?
  private var allSkills: [SkillResult] = []
  private var lastLoadedPath: String = ""

  var searchQuery: String = "" {
    didSet {
      if searchQuery != oldValue {
        performSearch()
      }
    }
  }

  var searchResults: [SkillResult] = [] {
    didSet {
      if searchResults.isEmpty {
        selectedIndex = 0
      } else if selectedIndex >= searchResults.count {
        selectedIndex = 0
      }
    }
  }

  var selectedIndex: Int = 0
  var isSearching: Bool = false

  private var searchTask: Task<Void, Never>?
  private var loadTask: Task<[SkillResult], Never>?

  private let maxResults = 100

  // MARK: - Init

  init(projectPath: String? = nil) {
    self.projectPath = projectPath
    Task { await loadSkillsIfNeeded(force: true) }
  }

  // MARK: - Public

  func updateProjectPath(_ path: String?) {
    projectPath = path
    Task { @MainActor in
      await loadSkillsIfNeeded(force: true)
      performSearch()
    }
  }

  func startSearch(query: String) {
    let shouldForce = query == searchQuery
    searchQuery = query
    if shouldForce {
      performSearch()
    }
  }

  func clearSearch() {
    searchQuery = ""
    searchResults = []
    selectedIndex = 0
    isSearching = false
    searchTask?.cancel()
    searchTask = nil
  }

  func selectNext() {
    guard !searchResults.isEmpty else { return }
    selectedIndex = min(selectedIndex + 1, searchResults.count - 1)
  }

  func selectPrevious() {
    guard !searchResults.isEmpty else { return }
    selectedIndex = max(selectedIndex - 1, 0)
  }

  func getSelectedResult() -> SkillResult? {
    guard selectedIndex >= 0 && selectedIndex < searchResults.count else { return nil }
    return searchResults[selectedIndex]
  }

  // MARK: - Private

  private func performSearch() {
    searchTask?.cancel()

    searchTask = Task { @MainActor in
      isSearching = true

      do {
        try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        try Task.checkCancellation()

        await loadSkillsIfNeeded()

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let results = filterSkills(query: trimmedQuery)

        if !Task.isCancelled {
          self.searchResults = results
          self.selectedIndex = results.isEmpty ? 0 : 0
        }
      } catch is CancellationError {
        // Expected when searches are cancelled
      } catch {
        print("[SkillSearchViewModel] Search error: \(error)")
        self.searchResults = []
      }

      self.isSearching = false
    }
  }

  private func loadSkillsIfNeeded(force: Bool = false) async {
    let pathKey = projectPath ?? ""
    if !force, !allSkills.isEmpty, lastLoadedPath == pathKey {
      return
    }

    loadTask?.cancel()
    loadTask = Task.detached { [projectPath] in
      SkillDiscovery.discoverSkills(projectPath: projectPath)
    }

    if let loadTask {
      let skills = await loadTask.value
      if !Task.isCancelled {
        allSkills = skills.sorted {
          $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        lastLoadedPath = pathKey
      }
    }
  }

  private func filterSkills(query: String) -> [SkillResult] {
    if query.isEmpty {
      return Array(allSkills.prefix(maxResults))
    }

    let normalized = query.lowercased()
    let ranked: [(rank: Int, skill: SkillResult)] = allSkills.compactMap { skill in
      let name = skill.name.lowercased()
      let description = skill.description.lowercased()

      if name.hasPrefix(normalized) {
        return (0, skill)
      } else if name.contains(normalized) {
        return (1, skill)
      } else if description.contains(normalized) {
        return (2, skill)
      }
      return nil
    }

    return ranked
      .sorted {
        if $0.rank != $1.rank { return $0.rank < $1.rank }
        return $0.skill.name.localizedCaseInsensitiveCompare($1.skill.name) == .orderedAscending
      }
      .prefix(maxResults)
      .map { $0.skill }
  }
}

// MARK: - InlineSearchViewModel Conformance

extension SkillSearchViewModel: InlineSearchViewModelProtocol {
  typealias Result = SkillResult
}
