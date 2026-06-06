//
//  TasksView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]
    
    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \TaskChangeLog.createdAt, order: .reverse)
    private var taskChangeLogs: [TaskChangeLog]

    @Query(sort: \AppNotification.createdAt, order: .reverse)
    private var appNotifications: [AppNotification]
    
    private let evaluationService = TaskEvaluationService()
    private let responseService = TaskResponseService()

    @State private var newTaskTitle: String = ""
    @State private var newTaskDetail: String = ""
    @State private var newTaskDueAt: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var newTaskKeywords: String = ""
    @State private var newScheduleType: ScheduleType = .task
    @State private var newRequiresPCWork: Bool = true
    
    @State private var editingTask: TaskItem?
    @State private var isShowingTaskEditSheet = false
    
    @State private var editingTaskTitle = ""
    @State private var editingTaskDetail = ""
    @State private var editingTaskKeywords = ""
    @State private var editingTaskDueAt = Date()
    @State private var editingTaskHasDueAt = false

    @State private var taskPendingDelete: TaskItem?
    @State private var showTaskDeleteConfirmation = false
    @State private var showCompletedDeleteConfirmation = false
    @State private var toastMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            addTaskSection

            taskListSection
        }
        .padding()
        .overlay(alignment: .top) {
            if let toastMessage {
                InAppToastView(message: toastMessage)
            }
        }
        .sheet(item: $editingTask) { task in
            taskEditSheet(task)
        }
        .confirmationDialog(
            "이 Task를 삭제할까요?",
            isPresented: $showTaskDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let task = taskPendingDelete {
                    modelContext.delete(task)
                    showToast("Task를 삭제했습니다.")
                }
                taskPendingDelete = nil
            }

            Button("취소", role: .cancel) {
                taskPendingDelete = nil
            }
        } message: {
            Text("삭제하면 이 Task와 연결된 상태 변경 흐름을 더 이상 확인하기 어렵습니다. 확실할 때만 삭제하세요.")
        }
        .confirmationDialog(
            "완료된 Task를 모두 삭제할까요?",
            isPresented: $showCompletedDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("완료된 항목 삭제", role: .destructive) {
                deleteCompletedTasks()
            }

            Button("취소", role: .cancel) { }
        } message: {
            Text("완료된 Task 전체가 삭제됩니다. 시연 전 데이터 정리 목적이 아니라면 유지하는 것을 권장합니다.")
        }
    }
    
    private func startEditingTask(_ task: TaskItem) {
        editingTask = task
        editingTaskTitle = task.title
        editingTaskDetail = task.detail ?? ""
        editingTaskKeywords = task.relatedKeywords ?? ""
        editingTaskDueAt = task.dueAt ?? Date()
        editingTaskHasDueAt = task.dueAt != nil
        if task.scheduleType == nil {
            task.scheduleType = ScheduleType.task.rawValue
        }
        if task.requiresPCWork == nil {
            task.requiresPCWork = true
        }
    }
    
    private func taskEditSheet(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task 수정")
                .font(.title2)
                .bold()

            TextField("제목", text: $editingTaskTitle)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("상세")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $editingTaskDetail)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            TextField("키워드", text: $editingTaskKeywords)
                .textFieldStyle(.roundedBorder)

            Toggle("마감일 있음", isOn: $editingTaskHasDueAt)

            if editingTaskHasDueAt {
                DatePicker(
                    "마감일",
                    selection: $editingTaskDueAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            HStack {
                Button("저장") {
                    task.title = editingTaskTitle
                    task.detail = editingTaskDetail.isEmpty ? nil : editingTaskDetail
                    task.relatedKeywords = editingTaskKeywords.isEmpty ? nil : editingTaskKeywords
                    task.dueAt = editingTaskHasDueAt ? editingTaskDueAt : nil

                    editingTask = nil
                    showToast("Task를 수정했습니다.")
                }

                Button("취소") {
                    editingTask = nil
                }

                Spacer()
            }
        }
        .padding()
        .frame(width: 560, height: 440)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Schedule")
                    .font(.largeTitle)
                    .bold()

                Text("Task와 Event를 구분해 일정과 할 일을 관리합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("오늘 활동과 비교") {
                evaluateTasks()
            }

            Button("완료된 항목 삭제") {
                showCompletedDeleteConfirmation = true
            }
        }
    }

    private var addTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("새 일정")
                .font(.headline)

            Picker("구분", selection: $newScheduleType) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    Text("\(type.displayName) · \(type.description)")
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)

            if newScheduleType == .task {
                Toggle("PC 작업 판단 대상으로 포함", isOn: $newRequiresPCWork)
            }

            TextField(newScheduleType == .task ? "예: 생산시스템관리 과제 제출" : "예: 교수님 미팅", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)

            TextField("상세 설명 선택 입력", text: $newTaskDetail)
                .textFieldStyle(.roundedBorder)

            TextField("관련 키워드 예: 생산시스템관리,LMS,과제", text: $newTaskKeywords)
                .textFieldStyle(.roundedBorder)

            Toggle("마감일 있음", isOn: $hasDueDate)

            if hasDueDate {
                DatePicker(
                    "마감일",
                    selection: $newTaskDueAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            HStack {
                Spacer()

                Button("추가") {
                    addTask()
                }
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var taskListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일정 목록")
                .font(.title2)
                .bold()

            if tasks.isEmpty {
                ContentUnavailableView(
                    "등록된 할 일이 없습니다",
                    systemImage: "checklist",
                    description: Text("새 할 일을 추가해보세요.")
                )
            } else {
                List {
                    if !urgentTasks.isEmpty {
                        Section("마감 임박 / 확인 필요") {
                            ForEach(urgentTasks) { task in
                                taskRow(task)
                            }
                        }
                    }

                    if !activeTasks.isEmpty {
                        Section("진행 중 / 대기") {
                            ForEach(activeTasks) { task in
                                taskRow(task)
                            }
                        }
                    }

                    if !deferredTasks.isEmpty {
                        Section("연기됨") {
                            ForEach(deferredTasks) { task in
                                taskRow(task)
                            }
                        }
                    }

                    if !completedTasks.isEmpty {
                        Section("완료됨") {
                            ForEach(completedTasks) { task in
                                taskRow(task)
                            }
                        }
                    }
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    toggleTask(task)
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .strikethrough(task.isCompleted)

                        if task.needsUserConfirmation {
                            Text("확인 필요")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.orange.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    if let detail = task.detail,
                       !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let plannedStartAt = task.plannedStartAt {
                        Text("시작: \(plannedStartAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let dueAt = task.dueAt {
                        Text("마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(isOverdue(task) ? .red : .secondary)
                    }

                    if let evidence = task.evidenceSummary,
                       !evidence.isEmpty {
                        Text("근거: \(evidence)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let deferredTo = task.deferredTo {
                        Text("연기일: \(deferredTo.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    tagRow(task)
                }

                Spacer()

                Button {
                    taskPendingDelete = task
                    showTaskDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            actionButtons(task)
        }
        .padding(.vertical, 8)
    }

    private func tagRow(_ task: TaskItem) -> some View {
        HStack {
            Text(statusDisplayName(task.status))
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary)
                .clipShape(Capsule())

            Text(task.source)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary)
                .clipShape(Capsule())

            Text(scheduleType(task).displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary)
                .clipShape(Capsule())

            if scheduleType(task) == .task {
                Text((task.requiresPCWork ?? true) ? "PC 작업" : "오프라인")
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            if let keywords = task.relatedKeywords,
               !keywords.isEmpty {
                Text(keywords)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func actionButtons(_ task: TaskItem) -> some View {
        HStack {
            Button("대기") {
                setStatus(task, status: .pending)
            }

            Button("진행 중") {
                setStatus(task, status: .inProgress)
            }

            Button("확인 필요") {
                setStatus(task, status: .uncertain)
            }

            Button("내일로 넘김") {
                deferTaskToTomorrow(task)
            }
            
            Button("수정") {
                startEditingTask(task)
            }

            Spacer()
        }
        .font(.caption)
    }

    private var urgentTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted &&
            ($0.needsUserConfirmation || $0.status == TaskStatus.uncertain.rawValue || isDueSoon($0))
        }
    }

    private var activeTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted &&
            $0.status != TaskStatus.deferred.rawValue &&
            !urgentTasks.contains($0)
        }
    }

    private var deferredTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted &&
            $0.status == TaskStatus.deferred.rawValue
        }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }
    }

    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = newTaskDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKeywords = newTaskKeywords.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return
        }

        let task = TaskItem(
            title: trimmedTitle,
            detail: trimmedDetail.isEmpty ? nil : trimmedDetail,
            source: "manual",
            status: TaskStatus.pending.rawValue,
            scheduleType: newScheduleType.rawValue,
            requiresPCWork: newScheduleType == .task ? newRequiresPCWork : false,
            dueAt: hasDueDate ? newTaskDueAt : nil,
            relatedKeywords: trimmedKeywords.isEmpty ? nil : trimmedKeywords
        )

        modelContext.insert(task)
        showToast("Task를 추가했습니다: \(task.title)")

        newTaskTitle = ""
        newTaskDetail = ""
        newTaskKeywords = ""
        hasDueDate = false
        newTaskDueAt = Date()
        newScheduleType = .task
        newRequiresPCWork = true
    }

    private func toggleTask(_ task: TaskItem) {
        if task.isCompleted {
            responseService.markPending(task: task, modelContext: modelContext)
            showToast("대기 상태로 되돌렸습니다.")
        } else {
            responseService.markCompleted(task: task, modelContext: modelContext)
            showToast("완료 처리했습니다.")
        }
    }

    private func setStatus(_ task: TaskItem, status: TaskStatus) {
        switch status {
        case .pending:
            responseService.markPending(task: task, modelContext: modelContext)
        case .inProgress:
            responseService.markInProgress(task: task, modelContext: modelContext)
            showToast("진행 중으로 변경했습니다.")
        case .completed:
            responseService.markCompleted(task: task, modelContext: modelContext)
            showToast("완료 처리했습니다.")
        case .deferred:
            responseService.deferToTomorrow(task: task, modelContext: modelContext)
            showToast("내일로 넘겼습니다.")
        case .uncertain:
            let previousStatus = task.status
            let previousIsCompleted = task.isCompleted
            let previousCompletedAt = task.completedAt
            let previousDeferredTo = task.deferredTo
            let previousDueAt = task.dueAt

            task.status = TaskStatus.uncertain.rawValue
            task.isCompleted = false
            task.completedAt = nil
            task.needsUserConfirmation = true

            let log = TaskChangeLog(
                taskTitle: task.title,
                changeType: "statusChanged",
                previousStatus: previousStatus,
                newStatus: task.status,
                previousIsCompleted: previousIsCompleted,
                newIsCompleted: task.isCompleted,
                previousCompletedAt: previousCompletedAt,
                newCompletedAt: task.completedAt,
                previousDeferredTo: previousDeferredTo,
                newDeferredTo: task.deferredTo,
                previousDueAt: previousDueAt,
                newDueAt: task.dueAt,
                previousTitle: task.title,
                newTitle: task.title,
                reason: "사용자가 확인 필요 상태로 변경했습니다.",
                source: "manual"
            )
            modelContext.insert(log)

            let notification = AppNotification(
                title: "확인 필요한 Task",
                message: "\(task.title)을 확인 필요 상태로 변경했습니다.",
                kind: "taskChange",
                source: "manual",
                relatedTaskTitle: task.title,
                suggestedStatus: task.status
            )
            modelContext.insert(notification)
            showToast("확인 필요 상태로 변경했습니다.")
        }
    }

    private func deferTaskToTomorrow(_ task: TaskItem) {
        responseService.deferToTomorrow(task: task, modelContext: modelContext)
        showToast("내일로 넘겼습니다.")
    }

    private func deleteTask(_ task: TaskItem) {
        modelContext.delete(task)
    }
    
    private func evaluateTasks() {
        let results = evaluationService.evaluateTasks(
            tasks: tasks,
            activities: activities
        )

        evaluationService.applyEvaluationResults(results)
    }

    private func deleteCompletedTasks() {
        let count = completedTasks.count
        for task in completedTasks {
            modelContext.delete(task)
        }
        showToast("완료된 Task \(count)개를 삭제했습니다.")
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func statusDisplayName(_ rawValue: String) -> String {
        TaskStatus(rawValue: rawValue)?.displayName ?? rawValue
    }

    private func isOverdue(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        return !task.isCompleted && dueAt < Date()
    }

    private func isDueSoon(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

        return dueAt >= now && dueAt <= tomorrow
    }

    private func scheduleType(_ task: TaskItem) -> ScheduleType {
        ScheduleType(rawValue: task.scheduleType ?? "") ?? .task
    }
}
