import Foundation

/// A facet or group named in the text, either already existing or to be created.
struct TagPick: Hashable {
    let name: String
    let isNew: Bool
}

/// What the quick panel / New Task sheet is about to do: which project (and groups) and which
/// facets a task typed as `name @project #facet +group` ends up with, and whether anything has to
/// be created along the way.
struct NewTaskPlan: Identifiable {
    let taskName: String
    let project: NewTaskTarget
    let facets: [TagPick]
    let groups: [TagPick]
    /// The name that Tab writes over the segment being typed (nil without any sigil).
    let completion: String?

    var id: String {
        ([project.id] + facets.map { "#" + $0.name } + groups.map { "+" + $0.name }).joined(separator: "|")
    }

    /// True when only the project (and its groups) is touched — `@Foo` with no task name.
    var isProjectOnly: Bool { taskName.isEmpty }

    var title: String {
        guard isProjectOnly else { return "Create \"\(taskName)\"" }
        return project.isNewProject ? "Create project \"\(project.name)\"" : "Update project \"\(project.name)\""
    }

    /// The second line of a row: where the task goes, its facets and groups.
    var summary: String {
        var parts: [String] = []
        if !isProjectOnly { parts.append(project.locationLabel) }
        parts += facets.map { "#\($0.name)" + ($0.isNew ? " (new)" : "") }
        parts += groups.map { "+\($0.name)" + ($0.isNew ? " (new)" : "") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Building

    struct Context {
        let projects: [Project]       // unarchived
        let facets: [Facet]
        let groups: [ProjectGroup]
        let defaultProject: Project?
    }

    /// One plan per suggestion for the segment being typed, best first. Segments that are already
    /// finished resolve to the existing item with that name (ignoring case), or a new one.
    /// - No sigil: a single plan into the default project.
    /// - `@…`: a plan per matching project, then a new project of that name unless one matches exactly.
    /// - `#…` / `+…`: a plan per matching facet / group, then a new one, with the project resolved
    ///   from an earlier `@` (or the default).
    /// Plans that would do nothing useful are left out: a task needs a project, and with no task
    /// name only `@NewProject` or `@Project +Group` make sense.
    static func plans(for query: QuickPanelQuery, context: Context) -> [NewTaskPlan] {
        let taskName = query.taskText
        let segments = query.segments
        let activeSigil = segments.last?.sigil
        let activeText = segments.last?.text ?? ""

        // Finished segments (everything but the one being typed).
        let finished = activeSigil == nil ? segments : Array(segments.dropLast())

        let fixedProjectText = finished.last { $0.sigil == .project }?.text ?? ""
        let fixedProject: (target: NewTaskTarget?, explicit: Bool) = {
            if !fixedProjectText.isEmpty {
                if let existing = context.projects.first(where: { QuickPanelQuery.isSame($0.name, fixedProjectText) }) {
                    return (.project(existing), true)
                }
                return (.newProject(fixedProjectText), true)
            }
            return (context.defaultProject.map(NewTaskTarget.project), false)
        }()
        let fixedFacets = resolvedTags(finished.filter { $0.sigil == .facet }.map(\.text), existing: context.facets.map(\.name))
        let fixedGroups = resolvedTags(finished.filter { $0.sigil == .group }.map(\.text), existing: context.groups.map(\.name))

        var plans: [NewTaskPlan] = []
        func add(_ project: NewTaskTarget?, explicit: Bool, facets: [TagPick], groups: [TagPick], completion: String?) {
            guard let project else { return }
            if taskName.isEmpty {
                // No task: only creating a project, or adding groups to one, is meaningful.
                guard explicit, facets.isEmpty, project.isNewProject || !groups.isEmpty else { return }
            }
            plans.append(NewTaskPlan(taskName: taskName, project: project, facets: facets, groups: groups, completion: completion))
        }

        switch activeSigil {
        case nil:
            add(fixedProject.target, explicit: false, facets: [], groups: [], completion: nil)

        case .project?:
            let ranked = ranked(context.projects, filter: activeText) { $0.name }
            for project in ranked {
                add(.project(project), explicit: true, facets: fixedFacets, groups: fixedGroups, completion: project.name)
            }
            if !activeText.isEmpty, !context.projects.contains(where: { QuickPanelQuery.isSame($0.name, activeText) }) {
                add(.newProject(activeText), explicit: true, facets: fixedFacets, groups: fixedGroups, completion: activeText)
            }

        case .facet?:
            for pick in tagCandidates(filter: activeText, existing: context.facets.map(\.name), excluding: fixedFacets) {
                add(fixedProject.target, explicit: fixedProject.explicit, facets: fixedFacets + [pick], groups: fixedGroups, completion: pick.name)
            }

        case .group?:
            for pick in tagCandidates(filter: activeText, existing: context.groups.map(\.name), excluding: fixedGroups) {
                add(fixedProject.target, explicit: fixedProject.explicit, facets: fixedFacets, groups: fixedGroups + [pick], completion: pick.name)
            }
        }
        return plans
    }

    /// Existing names matching `filter`, best match first, then a new one unless one matches exactly.
    private static func tagCandidates(filter: String, existing: [String], excluding taken: [TagPick]) -> [TagPick] {
        let takenNames = taken.map(\.name)
        func isTaken(_ name: String) -> Bool { takenNames.contains { QuickPanelQuery.isSame($0, name) } }
        var result = ranked(existing, filter: filter) { $0 }
            .filter { !isTaken($0) }
            .map { TagPick(name: $0, isNew: false) }
        if !filter.isEmpty,
           !existing.contains(where: { QuickPanelQuery.isSame($0, filter) }),
           !isTaken(filter) {
            result.append(TagPick(name: filter, isNew: true))
        }
        return result
    }

    /// Resolves finished segment texts to existing names (ignoring case) or new ones, dropping blanks and duplicates.
    private static func resolvedTags(_ texts: [String], existing: [String]) -> [TagPick] {
        var result: [TagPick] = []
        for text in texts where !text.isEmpty {
            let pick: TagPick
            if let match = existing.first(where: { QuickPanelQuery.isSame($0, text) }) {
                pick = TagPick(name: match, isNew: false)
            } else {
                pick = TagPick(name: text, isNew: true)
            }
            if !result.contains(where: { QuickPanelQuery.isSame($0.name, pick.name) }) { result.append(pick) }
        }
        return result
    }

    /// Items whose name matches `filter`, exact matches first, then prefix matches, then the rest
    /// (keeping the original order within each group).
    private static func ranked<T>(_ items: [T], filter: String, name: (T) -> String) -> [T] {
        items.enumerated()
            .filter { QuickPanelQuery.matches(name($0.element), filter: filter) }
            .sorted {
                let (a, b) = (QuickPanelQuery.rank(name($0.element), filter: filter), QuickPanelQuery.rank(name($1.element), filter: filter))
                return a != b ? a < b : $0.offset < $1.offset
            }
            .map(\.element)
    }

    // MARK: - Executing

    /// Creates what the plan describes: the project if new, its groups, then the task and its
    /// facets. Returns the project and the task (nil for a project-only plan).
    @discardableResult
    func perform(using repositories: Repositories) throws -> (project: Project, task: Task?) {
        let project: Project
        switch self.project {
        case .project(let existing): project = existing
        case .newProject(let name): project = try repositories.project.create(named: name)
        }
        for group in groups {
            try repositories.projectGroup.attach(try repositories.projectGroup.findOrCreate(named: group.name), to: project)
        }
        guard !isProjectOnly else { return (project, nil) }
        let task = try repositories.task.add(named: taskName, to: project)
        for facet in facets {
            try repositories.facet.attach(try repositories.facet.findOrCreate(named: facet.name), to: task)
        }
        return (project, task)
    }
}
