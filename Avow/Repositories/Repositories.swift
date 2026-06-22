import SwiftData

@Observable
final class Repositories {
    let project: any ProjectRepository
    let task: any TaskRepository
    let timeEntry: any TimeEntryRepository
    let facet: any FacetRepository

    init(context: ModelContext) {
        project = SwiftDataProjectRepository(context: context)
        task = SwiftDataTaskRepository(context: context)
        timeEntry = SwiftDataTimeEntryRepository(context: context)
        facet = SwiftDataFacetRepository(context: context)
    }

    // For testing — inject mock implementations
    init(
        project: any ProjectRepository,
        task: any TaskRepository,
        timeEntry: any TimeEntryRepository,
        facet: any FacetRepository
    ) {
        self.project = project
        self.task = task
        self.timeEntry = timeEntry
        self.facet = facet
    }
}
