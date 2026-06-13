import SwiftUI

struct ProjectBreakdownSection: View {
    let viewModel: OverviewViewModel

    var body: some View {
        Text("Time by project")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)

        ForEach(viewModel.projectBreakdown, id: \.project.id) { item in
            HStack(spacing: 10) {
                Text(item.project.name)
                    .font(.subheadline)
                Spacer()
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(width: geo.size.width)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.secondary)
                                .frame(width: geo.size.width * item.fraction)
                        }
                }
                .frame(width: 100, height: 6)
                Text(item.duration.shortFormatted)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
                Text(String(format: "%.0f%%", item.fraction * 100))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}
