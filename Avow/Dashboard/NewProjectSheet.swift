import SwiftUI
import SwiftData

struct NewProjectSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedColor = "#534AB7"

    private let colorOptions = [
        "#534AB7", "#1D9E75", "#D85A30", "#378ADD",
        "#D4537E", "#639922", "#BA7517", "#888780",
    ]

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
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Project name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Side project, Client work…", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Color
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if hex == selectedColor {
                                        Circle()
                                            .strokeBorder(.primary, lineWidth: 2)
                                            .frame(width: 34, height: 34)
                                    }
                                }
                                .onTapGesture {
                                    selectedColor = hex
                                }
                        }
                    }
                }

                // Preview
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: selectedColor))
                        .frame(width: 10, height: 10)
                    Text(name.isEmpty ? "Project name" : name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(name.isEmpty ? .tertiary : .primary)
                    Spacer()
                    Text("preview")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
        .frame(width: 380, height: 340)
    }

    private func createProject() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let project = Project(name: trimmed, colorHex: selectedColor)
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}
