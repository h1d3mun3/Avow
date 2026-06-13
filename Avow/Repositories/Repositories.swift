import SwiftData

@Observable
final class Repositories {
    let project: any ProjectRepository
    let task: any TaskRepository
    let timeEntry: any TimeEntryRepository

    init(context: ModelContext) {
        project = SwiftDataProjectRepository(context: context)
        task = SwiftDataTaskRepository(context: context)
        timeEntry = SwiftDataTimeEntryRepository(context: context)
    }

    // For testing — inject mock implementations
    init(
        project: any ProjectRepository,
        task: any TaskRepository,
        timeEntry: any TimeEntryRepository
    ) {
        self.project = project
        self.task = task
        self.timeEntry = timeEntry
    }
}
