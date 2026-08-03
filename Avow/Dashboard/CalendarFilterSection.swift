import SwiftUI
import SwiftData

/// Lets the user narrow the Calendar tab down to a single project and/or
/// facet at a time.
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
        VStack(alignment: .leading, spacing: 12) {
            if !projects.isEmpty {
                filterRow(title: "Project") {
                    Picker("Project", selection: $projectID) {
                        Text("All").tag(nil as UUID?)
                        ForEach(projects) { project in
                            Text(project.name).tag(project.id as UUID?)
                        }
                    }
                }
            }

            if !facets.isEmpty {
                filterRow(title: "Facet") {
                    Picker("Facet", selection: $facetID) {
                        Text("All").tag(nil as UUID?)
                        ForEach(facets) { facet in
                            Text(facet.name).tag(facet.id as UUID?)
                        }
                    }
                }
            }
        }
    }

    private func filterRow(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            content()
                .labelsHidden()
                .pickerStyle(.menu)
        }
    }
}
