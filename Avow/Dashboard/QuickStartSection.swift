import SwiftUI
import SwiftData

struct QuickStartSection: View {
    @Bindable var viewModel: OverviewViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if !viewModel.allActiveTasks.isEmpty {
            Text("Quick start")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            QuickStartSearchField(text: $viewModel.quickStartFilter)

            if viewModel.quickStartTasks.isEmpty {
                Text("No tasks found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            } else {
                ForEach(viewModel.quickStartTasks) { task in
                    let isActive = appState.activeEntry?.task?.id == task.id
                    QuickStartRow(task: task, isActive: isActive) {
                        if isActive {
                            appState.stopTracking(context: modelContext)
                        } else {
                            appState.switchTask(to: task, context: modelContext)
                        }
                    }
                }
            }
        }
    }
}

private struct QuickStartSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.tertiary)
            TextField("Search tasks…", text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct QuickStartRow: View {
    let task: Task
    let isActive: Bool
    let action: () -> Void

    @Environment(AppState.self) private var appState

    private var todayDuration: TimeInterval {
        let start = Calendar.current.startOfDay(for: .now)
        return task.timeEntries
            .filter { $0.startDate >= start }
            .reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isActive ? "stop.circle.fill" : "play.circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let projectName = task.project?.name {
                        Text(projectName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isActive {
                    let _ = appState.tick
                    Text(appState.activeEntry?.duration.timerFormatted ?? "")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else if todayDuration > 0 {
                    Text(todayDuration.shortFormatted)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isActive
                    ? AnyShapeStyle(Color.accentColor.opacity(0.1))
                    : AnyShapeStyle(.quaternary.opacity(0.4)),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Stop tracking \(task.name)" : "Start tracking \(task.name)")
    }
}
