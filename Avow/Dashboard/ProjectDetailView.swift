import SwiftUI

struct ProjectDetailView: View {
    @State private var viewModel: ProjectDetailViewModel
    @State private var newTaskName = ""
    @State private var selectedTaskID: Task.ID?

    init(project: Project, taskRepository: any TaskRepository) {
        _viewModel = State(initialValue: ProjectDetailViewModel(
            project: project,
            taskRepository: taskRepository
        ))
    }

    var body: some View {
        HStack(spacing: 0) {
            TaskListPanel(viewModel: viewModel, selectedTaskID: $selectedTaskID, newTaskName: $newTaskName)
            if let task = viewModel.task(withID: selectedTaskID) {
                Divider()
                // .id ties the panel's @Query filter to the selected task,
                // rebuilding it when the selection changes.
                TaskTimeEntryPanel(task: task, onClose: { selectedTaskID = nil })
                    .id(task.id)
            }
        }
        .navigationTitle(viewModel.projectName)
    }
}
