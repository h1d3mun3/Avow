import SwiftUI
import SwiftData

/// Lets the user narrow the Calendar tab down to a single project and/or
/// facet at a time, tab-style: click an item to highlight it and filter down
/// to it, click it again (or "All") to clear the filter.
struct CalendarFilterSection: View {
    @Binding var projectID: UUID?
    @Binding var facetID: UUID?

    @Query(sort: \Project.sortOrder)
    private var allProjects: [Project]

    @Query(sort: \Facet.name)
    private var facets: [Facet]

    private var projects: [Project] {
        allProjects.filter { !$0.isArchived }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !projects.isEmpty {
                filterList(
                    title: "Projects",
                    allLabel: "All Projects",
                    items: projects.map { ($0.id, $0.name) },
                    selection: $projectID
                )
            }

            if !facets.isEmpty {
                filterList(
                    title: "Facets",
                    allLabel: "All Facets",
                    items: facets.map { ($0.id, $0.name) },
                    selection: $facetID
                )
            }
        }
    }

    private func filterList(
        title: String,
        allLabel: String,
        items: [(id: UUID, name: String)],
        selection: Binding<UUID?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            CalendarFilterRow(label: allLabel, isSelected: selection.wrappedValue == nil) {
                selection.wrappedValue = nil
            }

            ForEach(items, id: \.id) { item in
                CalendarFilterRow(label: item.name, isSelected: selection.wrappedValue == item.id) {
                    selection.wrappedValue = selection.wrappedValue == item.id ? nil : item.id
                }
            }
        }
    }
}

private struct CalendarFilterRow: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
