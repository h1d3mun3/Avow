import SwiftUI

/// Detail for a single project group: the projects carrying it and the combined time spent
/// across all of them. Read-only — group management lives elsewhere.
struct ProjectGroupDetailView: View {
    let group: ProjectGroup

    @Environment(TimeRoundingSettings.self) private var roundingSettings

    private var projects: [Project] {
        group.activeProjects.sorted { $0.totalDuration > $1.totalDuration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if projects.isEmpty {
                ContentUnavailableView(
                    "No projects",
                    systemImage: "folder",
                    description: Text("No projects carry this group yet.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(projects) { project in
                        HStack(spacing: 12) {
                            Text(project.name)
                            Spacer()
                            Text(roundingSettings.display(project.totalDuration).shortFormatted)
                                .font(.callout)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(roundingSettings.display(group.totalDuration).shortFormatted)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text("\(projects.count) project\(projects.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}
