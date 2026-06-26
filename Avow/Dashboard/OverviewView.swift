import SwiftUI
import SwiftData

struct OverviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(TimeRoundingSettings.self) private var roundingSettings

    @Query(sort: \Project.name)
    private var projects: [Project]

    @State private var viewModel = OverviewViewModel()

    var body: some View {
        content
            .onChange(of: projects, initial: true) { _, newProjects in
                viewModel.update(projects: newProjects)
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.activeProjects.isEmpty {
            ContentUnavailableView(
                "No projects yet",
                systemImage: "folder",
                description: Text("Create a project to start tracking your time.")
            )
            .navigationTitle("Overview")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        OverviewSummaryCard(
                            label: "Total tracked",
                            value: roundingSettings.display(viewModel.totalDuration).shortFormatted,
                            sub: "\(viewModel.activeProjects.count) projects"
                        )
                        OverviewSummaryCard(
                            label: "This week",
                            value: roundingSettings.display(viewModel.thisWeekDuration).shortFormatted,
                            sub: ""
                        )
                        OverviewSummaryCard(
                            label: "Today",
                            value: roundingSettings.display(viewModel.todayDuration).shortFormatted,
                            sub: ""
                        )
                    }

                    QuickStartSection(viewModel: viewModel)

                    ProjectBreakdownSection(viewModel: viewModel)
                }
                .padding(20)
            }
            .navigationTitle("Overview")
        }
    }
}

private struct OverviewSummaryCard: View {
    let label: String
    let value: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
                .monospacedDigit()
            if !sub.isEmpty {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
