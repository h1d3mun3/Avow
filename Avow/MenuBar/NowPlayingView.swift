import SwiftUI
import SwiftData

struct NowPlayingView: View {
    let entry: TimeEntry

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tracking")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.accentColor)

                Text(entry.task?.name ?? "Unknown task")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let project = entry.task?.project {
                    Text(project.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            let _ = appState.tick
            Text(entry.duration.timerFormatted)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Elapsed time: \(entry.duration.timerFormatted)")

            Button {
                appState.stopTracking()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
                    .background(.red.opacity(0.1), in: Circle())
                    .overlay(Circle().strokeBorder(.red.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop tracking")
            .accessibilityHint("Stops the current time entry")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.06))
    }
}
