import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// Dragged tasks carry only their id, so the payload is meaningless outside a
    /// running Avow; the type stays app-private rather than being declared for export.
    nonisolated static let avowTask = UTType(exportedAs: "com.h1d3mun3.Avow.task", conformingTo: .data)
}

/// Drag payload for a task row. A SwiftData model cannot cross a drag session,
/// so the id travels and the drop side resolves it back to the task.
struct TaskTransfer: Codable, Transferable {
    let taskID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .avowTask)
    }
}
