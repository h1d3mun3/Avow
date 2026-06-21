import SwiftUI
import SwiftData

struct TaskTimeEntryPanel: View {
    let task: Task
    let onClose: () -> Void

    @Environment(Repositories.self) private var repositories
    // Driven by @Query so manual add/delete/edit reflect immediately;
    // reading task.timeEntries directly does not re-render on insert.
    @Query private var entries: [TimeEntry]
    @State private var isAddingEntry = false
    @State private var newStart: Date = .now.addingTimeInterval(-3600)
    @State private var newEnd: Date = .now
    @State private var errorMessage: String?

    init(task: Task, onClose: @escaping () -> Void) {
        self.task = task
        self.onClose = onClose
        let taskID = task.id
        _entries = Query(
            filter: #Predicate<TimeEntry> { $0.task?.id == taskID },
            sort: \.startDate,
            order: .reverse
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button {
                    newStart = .now.addingTimeInterval(-3600)
                    newEnd = .now
                    isAddingEntry = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add a record manually")
                .accessibilityLabel("Add time entry")
                .popover(isPresented: $isAddingEntry) {
                    addEntryForm
                }
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if entries.isEmpty {
                ContentUnavailableView(
                    "No records",
                    systemImage: "clock",
                    description: Text("Start tracking this task, or add a record manually.")
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
        .errorAlert($errorMessage)
    }

    private var addEntryForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Record")
                .font(.headline)
            DatePicker("Start", selection: $newStart, displayedComponents: [.date, .hourAndMinute])
            DatePicker("End", selection: $newEnd, in: newStart..., displayedComponents: [.date, .hourAndMinute])
            HStack {
                Button("Cancel") { isAddingEntry = false }
                Spacer()
                Button("Add") {
                    do {
                        _ = try repositories.timeEntry.add(task: task, start: newStart, end: newEnd)
                        isAddingEntry = false
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
