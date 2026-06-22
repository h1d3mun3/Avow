import SwiftUI
import SwiftData

/// Attach/detach facets on a task, and create new facets inline.
/// Toggles apply immediately (no Save button) — facets are a lightweight assignment.
struct FacetPicker: View {
    let task: Task

    @Environment(Repositories.self) private var repositories
    @Query(sort: \Facet.name) private var allFacets: [Facet]
    @State private var newFacetName = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Facets")
                .font(.headline)

            if allFacets.isEmpty {
                Text("No facets yet. Create one below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(allFacets) { facet in
                        Button {
                            toggle(facet)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isAttached(facet) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isAttached(facet) ? Color.accentColor : .secondary)
                                Text(facet.name)
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
                TextField("New facet", text: $newFacetName)
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
        newFacetName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isAttached(_ facet: Facet) -> Bool {
        task.facets.contains { $0.id == facet.id }
    }

    private func toggle(_ facet: Facet) {
        do {
            if isAttached(facet) {
                try repositories.facet.detach(facet, from: task)
            } else {
                try repositories.facet.attach(facet, to: task)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createAndAttach() {
        guard !trimmedNewName.isEmpty else { return }
        do {
            let facet = try repositories.facet.findOrCreate(named: trimmedNewName)
            try repositories.facet.attach(facet, to: task)
            newFacetName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
