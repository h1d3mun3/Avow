import SwiftData

@Observable
final class Repositories {
    let project: any ProjectRepository
    let task: any TaskRepository
    let timeEntry: any TimeEntryRepository
    let facet: any FacetRepository
    let projectGroup: any ProjectGroupRepository

    init(context: ModelContext) {
        project = SwiftDataProjectRepository(context: context)
        task = SwiftDataTaskRepository(context: context)
        timeEntry = SwiftDataTimeEntryRepository(context: context)
        facet = SwiftDataFacetRepository(context: context)
        projectGroup = SwiftDataProjectGroupRepository(context: context)
    }

    // For testing — inject mock implementations
    init(
        project: any ProjectRepository,
        task: any TaskRepository,
        timeEntry: any TimeEntryRepository,
        facet: any FacetRepository,
        projectGroup: any ProjectGroupRepository
    ) {
        self.project = project
        self.task = task
        self.timeEntry = timeEntry
        self.facet = facet
        self.projectGroup = projectGroup
    }
}
