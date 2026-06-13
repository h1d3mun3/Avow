import SwiftUI
import SwiftData

struct TimeEntryRow: View {
    let entry: TimeEntry

    @Environment(Repositories.self) private var repositories
    @State private var isEditing = false
    @State private var editStart: Date = .now
    @State private var editEnd: Date = .now
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    entry.startDate.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "play.circle"
                )
                .font(.caption)

                if let end = entry.endDate {
                    Label(
                        end.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "stop.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Label("Running", systemImage: "record.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Text(entry.duration.shortFormatted)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button {
                editStart = entry.startDate
                editEnd = entry.endDate ?? .now
                isEditing = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit times")

            Button(role: .destructive) {
                do { try repositories.timeEntry.delete(entry) } catch { errorMessage = error.localizedDescription }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Delete record")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .popover(isPresented: $isEditing) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Record")
                    .font(.headline)
                DatePicker("Start", selection: $editStart, displayedComponents: [.date, .hourAndMinute])
                if entry.endDate != nil {
                    DatePicker("End", selection: $editEnd, in: editStart..., displayedComponents: [.date, .hourAndMinute])
                }
                HStack {
                    Button("Cancel") { isEditing = false }
                    Spacer()
                    Button("Save") {
                        do { try repositories.timeEntry.update(entry, start: editStart, end: editEnd) } catch { errorMessage = error.localizedDescription }
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .frame(width: 300)
        }
    }
}
