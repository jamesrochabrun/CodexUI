//
//  InlineSearchView.swift
//  CodexUI
//

import Observation
import SwiftUI

protocol InlineSearchResult: Identifiable {
  var title: String { get }
  var subtitle: String { get }
  var iconName: String { get }
  var iconColor: Color { get }
}

protocol InlineSearchViewModelProtocol: Observable, AnyObject {
  associatedtype Result: InlineSearchResult
  var searchQuery: String { get set }
  var isSearching: Bool { get }
  var searchResults: [Result] { get }
  var selectedIndex: Int { get set }
}

struct InlineSearchConfiguration {
  let triggerSymbol: String
  let noun: String
  let showsResultsWhenQueryEmpty: Bool
  let emptyStateHint: String
  let resultsHint: String

  static let fileSearch = InlineSearchConfiguration(
    triggerSymbol: "@",
    noun: "files",
    showsResultsWhenQueryEmpty: false,
    emptyStateHint: "Try a different search term",
    resultsHint: "Use ↑↓ to navigate, Enter to select, Esc to cancel"
  )

  static let skillSearch = InlineSearchConfiguration(
    triggerSymbol: "$",
    noun: "skills",
    showsResultsWhenQueryEmpty: true,
    emptyStateHint: "Try a different search term",
    resultsHint: "Use ↑↓ to navigate, Enter to select, Esc to cancel"
  )
}

/// Displays inline search results for @ and $ mentions.
struct InlineSearchView<ViewModel: InlineSearchViewModelProtocol>: View {
  @Bindable var viewModel: ViewModel
  let configuration: InlineSearchConfiguration
  let onSelect: (ViewModel.Result) -> Void
  let onDismiss: () -> Void

  @State private var hoveredIndex: Int? = nil

  // MARK: - Computed Properties

  private var shouldShowEmptyState: Bool {
    let allowEmptyQuery = configuration.showsResultsWhenQueryEmpty && viewModel.searchQuery.isEmpty
    return viewModel.searchResults.isEmpty &&
    !viewModel.isSearching &&
    (!viewModel.searchQuery.isEmpty || allowEmptyQuery)
  }

  private var shouldShowResults: Bool {
    configuration.showsResultsWhenQueryEmpty || !viewModel.searchQuery.isEmpty
  }

  // MARK: - Body

  var body: some View {
    VStack(spacing: 0) {
      headerBar
      if shouldShowResults {
        Divider()
        resultsArea
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
  }

  // MARK: - Subviews

  private var headerBar: some View {
    HeaderBar(
      configuration: configuration,
      searchQuery: viewModel.searchQuery,
      isSearching: viewModel.isSearching,
      resultsCount: viewModel.searchResults.count,
      onDismiss: onDismiss
    )
  }

  private var resultsArea: some View {
    Group {
      if shouldShowEmptyState {
        emptyStateView
      } else {
        VStack(spacing: 0) {
          searchResultsList
          if !viewModel.searchResults.isEmpty {
            Label(configuration.resultsHint, systemImage: "keyboard")
              .font(.caption2)
              .foregroundColor(.secondary)
              .padding(.bottom, 8)
          }
        }
      }
    }
  }

  private var searchResultsList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 0) {
          ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
            resultRow(for: result, at: index)

            if index < viewModel.searchResults.count - 1 {
              Divider().padding(.leading, 40)
            }
          }
        }
        .padding(.bottom, 4)
      }
      .frame(maxHeight: 220)
      .fixedSize(horizontal: false, vertical: true)
      .onChange(of: viewModel.selectedIndex, handleSelectionChange(proxy))
    }
  }

  private func resultRow(for result: ViewModel.Result, at index: Int) -> some View {
    InlineSearchResultRow(
      result: result,
      isSelected: index == viewModel.selectedIndex,
      isHovered: index == hoveredIndex
    )
    .id(result.id)
    .onTapGesture {
      viewModel.selectedIndex = index
      onSelect(result)
    }
    .onHover { handleHover($0, at: index) }
  }

  // MARK: - Helper Methods

  private func handleHover(_ isHovering: Bool, at index: Int) {
    hoveredIndex = isHovering ? index : nil
    // Don't update selection on hover - let keyboard navigation work independently
  }

  private func handleSelectionChange(_ proxy: ScrollViewProxy) -> (Int, Int) -> Void {
    return { _, newIndex in
      if newIndex >= 0 && newIndex < viewModel.searchResults.count {
        withAnimation(.easeInOut(duration: 0.1)) {
          proxy.scrollTo(viewModel.searchResults[newIndex].id, anchor: .center)
        }
      }
    }
  }

  private var emptyStateView: some View {
    VStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.title2)
        .foregroundColor(.secondary)

      let querySuffix = viewModel.searchQuery.isEmpty ? "" : " for '\(viewModel.searchQuery)'"
      Text("No \(configuration.noun) found\(querySuffix)")
        .font(.body)
        .foregroundColor(.secondary)

      Text(configuration.emptyStateHint)
        .font(.caption)
        .foregroundColor(Color.secondary.opacity(0.6))
    }
    .padding(.vertical, 30)
    .frame(maxWidth: .infinity, minHeight: 100)
  }
}

// MARK: - Search Result Row

private struct InlineSearchResultRow<Result: InlineSearchResult>: View {
  let result: Result
  let isSelected: Bool
  let isHovered: Bool

  var body: some View {
    HStack(spacing: 12) {
      fileIconView
      fileInfoView
      Spacer()
      selectionIndicator
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(backgroundColor)
    .contentShape(Rectangle())
  }

  // MARK: - Subviews

  private var fileIconView: some View {
    Image(systemName: result.iconName)
      .font(.body)
      .foregroundColor(result.iconColor)
      .frame(width: 20)
  }

  private var fileInfoView: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(result.title)
        .font(.body)
        .fontWeight(.medium)
        .foregroundColor(.primary)

      Text(result.subtitle)
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
  }

  @ViewBuilder
  private var selectionIndicator: some View {
    if isSelected {
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private var backgroundColor: Color {
    if isSelected {
      return Color.brandPrimary.opacity(0.15)
    } else if isHovered {
      return Color.gray.opacity(0.1)
    }
    return Color.clear
  }
}

// MARK: - Header Bar Component

private struct HeaderBar: View {
  let configuration: InlineSearchConfiguration
  let searchQuery: String
  let isSearching: Bool
  let resultsCount: Int
  let onDismiss: () -> Void

  var body: some View {
    HStack {
      searchLabel
      Spacer()
      statusSection
      dismissButton
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(NSColor.separatorColor).opacity(0.1))
  }

  private var searchLabel: some View {
    let query = searchQuery.isEmpty ? configuration.triggerSymbol : "\(configuration.triggerSymbol)\(searchQuery)"
    return Label("Searching for: \(query)", systemImage: "magnifyingglass")
      .font(.caption)
      .foregroundColor(.secondary)
  }

  private var statusSection: some View {
    HStack(spacing: 8) {
      if isSearching {
        ProgressView()
          .scaleEffect(0.8)
          .frame(width: 16, height: 16)
      }

      Text("\(resultsCount) results")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  private var dismissButton: some View {
    Button(action: onDismiss) {
      Image(systemName: "xmark.circle.fill")
        .foregroundColor(.secondary)
        .font(.system(size: 14))
    }
    .buttonStyle(.plain)
  }
}
