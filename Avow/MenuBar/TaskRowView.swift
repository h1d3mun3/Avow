import SwiftUI

struct TaskRowView: View {
    let task: Task
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: isActive ? "play.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 14)

                Text(task.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.leading, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "Stop tracking \(task.name)" : "Start tracking \(task.name)")
        .background(isActive ? Color.accentColor.opacity(0.1) : .clear)
    }
}
