import SwiftUI
import SwiftData

/// Lets the user narrow the Calendar tab down to specific projects, the same
/// way Calendar.app lets you toggle individual calendars on and off.
struct CalendarProjectFilterSection: View {
    @Binding var selectedProjectIDs: Set<UUID>?

    @Query(sort: \Project.sortOrder)
    private var allProjects: [Project]

    private var projects: [Project] {
        allProjects.filter { !$0.isArchived }
    }

    var body: some View {
        if !projects.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Projects")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if selectedProjectIDs != nil {
                        Button("Show all") { selectedProjectIDs = nil }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }

                ForEach(projects) { project in
                    Toggle(project.name, isOn: binding(for: project))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }

    private func binding(for project: Project) -> Binding<Bool> {
        Binding(
            get: { selectedProjectIDs?.contains(project.id) ?? true },
            set: { isOn in
                var ids = selectedProjectIDs ?? Set(projects.map(\.id))
                if isOn {
                    ids.insert(project.id)
                } else {
                    ids.remove(project.id)
                }
                // A full explicit selection is equivalent to no filter — collapse
                // back to nil so projects added later stay visible by default.
                selectedProjectIDs = ids.count == projects.count ? nil : ids
            }
        )
    }
}
