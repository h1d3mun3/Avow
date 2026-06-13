import Testing
import Foundation
import SwiftData
@testable import Avow

@Suite("MenuBarViewModel")
struct MenuBarViewModelTests {

    // MARK: - filteredTasks

    @Test func filteredTasks_filterIsCaseInsensitive() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let match = Task(name: "Write Report", project: project)
        let other = Task(name: "Plan sprint", project: project)
        [match, other].forEach { context.insert($0) }

        let vm = MenuBarViewModel()
        vm.update(tasks: [match, other])
        vm.filterText = "report"

        #expect(vm.filteredTasks.map(\.name) == ["Write Report"])
    }

    @Test func filteredTasks_onlyActiveTasksIncluded() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let active = Task(name: "Active", project: project)
        let completed = Task(name: "Completed", project: project)
        completed.status = .completed
        [active, completed].forEach { context.insert($0) }

        let vm = MenuBarViewModel()
        vm.update(tasks: [active, completed])

        #expect(vm.filteredTasks.map(\.name) == ["Active"])
    }

    // MARK: - tasksByProject

    @Test func tasksByProject_dropsNilProjectTasks() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let kept = Task(name: "Kept", project: project)
        let orphan = Task(name: "Orphan", project: project)
        [kept, orphan].forEach { context.insert($0) }
        // Detach so it has no project.
        orphan.project = nil

        let vm = MenuBarViewModel()
        vm.update(tasks: [kept, orphan])

        #expect(vm.tasksByProject.count == 1)
        #expect(vm.tasksByProject[0].project.name == "P")
        #expect(vm.tasksByProject[0].tasks.map(\.name) == ["Kept"])
    }

    @Test func tasksByProject_sortsTasksWithinProjectByName() throws {
        let context = try makeInMemoryContext()
        let project = Project(name: "P")
        context.insert(project)
        let zebra = Task(name: "Zebra", project: project)
        let alpha = Task(name: "Alpha", project: project)
        [zebra, alpha].forEach { context.insert($0) }

        let vm = MenuBarViewModel()
        vm.update(tasks: [zebra, alpha])

        #expect(vm.tasksByProject.count == 1)
        #expect(vm.tasksByProject[0].tasks.map(\.name) == ["Alpha", "Zebra"])
    }

    @Test func tasksByProject_sortsProjectsByName() throws {
        let context = try makeInMemoryContext()
        let zebra = Project(name: "Zebra")
        let alpha = Project(name: "Alpha")
        [zebra, alpha].forEach { context.insert($0) }
        let zebraTask = Task(name: "ZT", project: zebra)
        let alphaTask = Task(name: "AT", project: alpha)
        [zebraTask, alphaTask].forEach { context.insert($0) }

        let vm = MenuBarViewModel()
        vm.update(tasks: [zebraTask, alphaTask])

        #expect(vm.tasksByProject.map(\.project.name) == ["Alpha", "Zebra"])
    }
}
