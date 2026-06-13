import SwiftUI

struct NewProjectSheet: View {
    @Environment(Repositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New project")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Project name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Side project, Client work…", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()

            Spacer()

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create project") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 320, height: 180)
        .errorAlert($errorMessage)
    }

    private func createProject() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try repositories.project.create(named: trimmed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
