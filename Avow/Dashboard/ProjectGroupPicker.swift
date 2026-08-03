import SwiftUI
import SwiftData

/// Attach/detach project groups on a project, and create new groups inline.
/// Toggles apply immediately (no Save button) — group membership is a lightweight assignment.
struct ProjectGroupPicker: View {
    let project: Project

    @Environment(Repositories.self) private var repositories
    @Query(sort: \ProjectGroup.name) private var allGroups: [ProjectGroup]
    @State private var newGroupName = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Groups")
                .font(.headline)

            if allGroups.isEmpty {
                Text("No groups yet. Create one below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(allGroups) { group in
                        Button {
                            toggle(group)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isAttached(group) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isAttached(group) ? Color.accentColor : .secondary)
                                Text(group.name)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            HStack(spacing: 6) {
                TextField("New group", text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(createAndAttach)
                Button("Add", action: createAndAttach)
                    .disabled(trimmedNewName.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
        .errorAlert($errorMessage)
    }

    private var trimmedNewName: String {
        newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isAttached(_ group: ProjectGroup) -> Bool {
        project.projectGroups.contains { $0.id == group.id }
    }

    private func toggle(_ group: ProjectGroup) {
        do {
            if isAttached(group) {
                try repositories.projectGroup.detach(group, from: project)
            } else {
                try repositories.projectGroup.attach(group, to: project)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createAndAttach() {
        guard !trimmedNewName.isEmpty else { return }
        do {
            let group = try repositories.projectGroup.findOrCreate(named: trimmedNewName)
            try repositories.projectGroup.attach(group, to: project)
            newGroupName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
