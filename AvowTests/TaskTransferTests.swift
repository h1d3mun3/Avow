import Testing
import CoreTransferable
import Foundation
import UniformTypeIdentifiers
@testable import Avow

@Suite("TaskTransfer")
struct TaskTransferTests {

    @Test func registersUnderTheAppsOwnTypeAndCarriesTheTaskIDBack() async throws {
        let id = UUID()
        let provider = NSItemProvider()
        provider.register(TaskTransfer(taskID: id))

        #expect(provider.registeredTypeIdentifiers == [UTType.avowTask.identifier])

        let loaded: TaskTransfer = try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadTransferable(type: TaskTransfer.self) { continuation.resume(with: $0) }
        }

        #expect(loaded.taskID == id)
    }

    @Test func doesNotLoadFromAForeignType() async throws {
        let provider = NSItemProvider(object: "not a task" as NSString)

        await #expect(throws: (any Error).self) {
            try await withCheckedThrowingContinuation { continuation in
                _ = provider.loadTransferable(type: TaskTransfer.self) { continuation.resume(with: $0) }
            }
        }
    }
}
