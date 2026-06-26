import SwiftUI

/// Detail for a single facet: the tasks carrying it and the total time spent,
/// across all projects. Read-only — facet management lives elsewhere.
struct FacetDetailView: View {
    let facet: Facet

    @Environment(TimeRoundingSettings.self) private var roundingSettings

    private var tasks: [Task] {
        facet.tasks.sorted { $0.totalDuration > $1.totalDuration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if tasks.isEmpty {
                ContentUnavailableView(
                    "No tasks",
                    systemImage: "circle.grid.2x2",
                    description: Text("No tasks carry this facet yet.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(tasks) { task in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.name)
                                if let projectName = task.project?.name {
                                    Text(projectName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(roundingSettings.display(task.totalDuration).shortFormatted)
                                .font(.callout)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(facet.name)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(roundingSettings.display(facet.totalDuration).shortFormatted)
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}
