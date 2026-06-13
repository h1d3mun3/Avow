import SwiftUI

struct ProjectDetailView: View {
    @State private var viewModel: ProjectDetailViewModel
    @State private var newTaskName = ""
    @State private var selectedTask: Task?

    init(project: Project, taskRepository: any TaskRepository) {
        _viewModel = State(initialValue: ProjectDetailViewModel(
            project: project,
            taskRepository: taskRepository
        ))
    }

    var body: some View {
        HStack(spacing: 0) {
            TaskListPanel(viewModel: viewModel, selectedTask: $selectedTask, newTaskName: $newTaskName)
            if let task = selectedTask {
                Divider()
                TaskTimeEntryPanel(task: task, onClose: { selectedTask = nil })
            }
        }
        .navigationTitle(viewModel.projectName)
    }
}
