import SwiftUI

struct TaskTimeEntryPanel: View {
    let task: Task
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            let entries = task.timeEntries.sorted { $0.startDate > $1.startDate }
            if entries.isEmpty {
                ContentUnavailableView(
                    "No records",
                    systemImage: "clock",
                    description: Text("Start tracking this task to create records.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(entries) { entry in
                            TimeEntryRow(entry: entry)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(minWidth: 260, maxWidth: .infinity)
    }
}
