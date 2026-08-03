import SwiftUI
import SwiftData

struct CalendarView: View {
    @State private var selectedDate: Date? = Calendar.current.startOfDay(for: .now)
    @State private var selectedProjectID: UUID?
    @State private var selectedFacetID: UUID?

    private var entryFilter: CalendarEntryFilter {
        CalendarEntryFilter(projectID: selectedProjectID, facetID: selectedFacetID)
    }

    var body: some View {
        HSplitView {
            calendarPanel
            if let date = selectedDate {
                DailyTimelineView(date: date, filter: entryFilter)
                    .frame(minWidth: 320)
            }
        }
        .navigationTitle("Calendar")
    }

    private var calendarPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CalendarSidebarSection(
                    selectedDate: selectedDate,
                    onSelectDate: { selectedDate = $0 },
                    filter: entryFilter
                )

                if let date = selectedDate {
                    DayProjectBreakdown(date: date, facetID: selectedFacetID, projectID: $selectedProjectID)
                    DayFacetBreakdown(date: date, projectID: selectedProjectID, facetID: $selectedFacetID)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 360)
    }
}

// MARK: - Project breakdown for a single day

private struct DayProjectBreakdown: View {
    let date: Date
    let facetID: UUID?
    @Binding var projectID: UUID?

    @Query private var entries: [TimeEntry]
    @Query(sort: \Project.sortOrder) private var allProjects: [Project]
    @Environment(TimeRoundingSettings.self) private var roundingSettings

    init(date: Date, facetID: UUID?, projectID: Binding<UUID?>) {
        self.date = date
        self.facetID = facetID
        self._projectID = projectID
        let (start, end) = DateWindows().dayBounds(for: date)
        _entries = Query(filter: #Predicate<TimeEntry> { entry in
            entry.startDate >= start && entry.startDate < end
        })
    }

    // Scoped only by the facet filter (not the project selection itself), so every
    // project remains a visible, tappable row regardless of which one is selected.
    private var items: [(id: UUID?, name: String, duration: TimeInterval, fraction: Double)] {
        let scoped = entries.filtered(by: CalendarEntryFilter(projectID: nil, facetID: facetID))
        var items = DayBreakdown(entries: scoped).items
        // Keep the selected project visible (and clearable) even on a day with no
        // matching entries.
        if let projectID, !items.contains(where: { $0.id == projectID }),
           let project = allProjects.first(where: { $0.id == projectID }) {
            items.append((id: project.id, name: project.name, duration: 0, fraction: 0))
        }
        return items
    }

    var body: some View {
        let items = items
        if !items.isEmpty {
            // Each entry belongs to exactly one project, so the per-project rows
            // reconcile to the day total — round them cumulatively.
            let displayed = roundingSettings.display(items.map(\.duration))
            VStack(alignment: .leading, spacing: 10) {
                Text("By project")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DayBreakdownRow(
                        name: item.name,
                        fraction: item.fraction,
                        formattedDuration: displayed[index].shortFormatted,
                        isSelected: item.id != nil && item.id == projectID,
                        isSelectable: item.id != nil
                    ) {
                        projectID = projectID == item.id ? nil : item.id
                    }
                }
            }
        }
    }
}

// MARK: - Facet breakdown for a single day

private struct DayFacetBreakdown: View {
    let date: Date
    let projectID: UUID?
    @Binding var facetID: UUID?

    @Query private var entries: [TimeEntry]
    @Query(sort: \Facet.name) private var allFacets: [Facet]
    @Environment(TimeRoundingSettings.self) private var roundingSettings

    init(date: Date, projectID: UUID?, facetID: Binding<UUID?>) {
        self.date = date
        self.projectID = projectID
        self._facetID = facetID
        let (start, end) = DateWindows().dayBounds(for: date)
        _entries = Query(filter: #Predicate<TimeEntry> { entry in
            entry.startDate >= start && entry.startDate < end
        })
    }

    // Scoped only by the project filter (not the facet selection itself), so every
    // facet remains a visible, tappable row regardless of which one is selected.
    private var items: [(id: UUID, name: String, duration: TimeInterval)] {
        let scoped = entries.filtered(by: CalendarEntryFilter(projectID: projectID, facetID: nil))
        var items = FacetBreakdown(entries: scoped).items
        // Keep the selected facet visible (and clearable) even on a day with no
        // matching entries.
        if let facetID, !items.contains(where: { $0.id == facetID }),
           let facet = allFacets.first(where: { $0.id == facetID }) {
            items.append((id: facet.id, name: facet.name, duration: 0))
        }
        return items
    }

    var body: some View {
        let items = items
        // Absolute time only, sorted descending; unfaceted time and the whole
        // section are omitted when there is nothing to show.
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("By facet")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                // Facets overlap (a task may carry several), so these rows don't sum
                // to any single total — round each independently to the nearest minute.
                ForEach(items, id: \.id) { item in
                    DayBreakdownRow(
                        name: item.name,
                        fraction: nil,
                        formattedDuration: roundingSettings.display(item.duration).shortFormatted,
                        isSelected: item.id == facetID,
                        isSelectable: true
                    ) {
                        facetID = facetID == item.id ? nil : item.id
                    }
                }
            }
        }
    }
}

// MARK: - Shared tappable breakdown row

private struct DayBreakdownRow: View {
    let name: String
    let fraction: Double?
    let formattedDuration: String
    let isSelected: Bool
    let isSelectable: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            if let fraction {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(width: geo.size.width)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.secondary)
                                .frame(width: geo.size.width * fraction)
                        }
                }
                .frame(width: 44, height: 5)
            }
            Text(formattedDuration)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectable { action() }
        }
    }
}
