//
//  TasksView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

private enum ScheduleRowStyle {
    case normal
    case dueSoon
    case confirmation
}

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]
    
    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]
    
    private let evaluationService = TaskEvaluationService()

    @State private var newTaskTitle: String = ""
    @State private var newTaskDueAt: Date = Date()
    @State private var hasDueDate: Bool = false
    @State private var newScheduleType: ScheduleType = .task

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
                headerSection

                addTaskSection

                taskListSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Schedule")
                    .font(.largeTitle)
                    .bold()

                Text("Task와 Event를 나눠서 오늘의 일정을 관리합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("오늘 활동과 비교") {
                evaluateTasks()
            }

            Button("완료된 항목 삭제") {
                deleteCompletedTasks()
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

            TextField(newScheduleType == .task ? "예: 생산시스템관리 과제 제출" : "예: 교수님 미팅", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)

            DatePicker("날짜", selection: $newTaskDueAt, displayedComponents: [.date])

            Toggle("시간 추가", isOn: $hasDueDate)
            
            if hasDueDate {
                DatePicker(
                    "시간",
                    selection: $newTaskDueAt,
                    displayedComponents: [.hourAndMinute]
                )
            }

            Text(newScheduleType == .task ? "Task는 PC 작업 판단 대상으로 저장됩니다." : "Event는 시간 중심 일정으로 저장됩니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)

            HStack {
                Spacer()

                Button("추가") {
                    addTask()
                }
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
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
                VStack(alignment: .leading, spacing: 28) {
                    scheduleGroup(title: "Event · 시간이 정해진 일", items: todayEvents)
                    scheduleGroup(title: "Task 마감 임박", items: dueSoonTasks, rowStyle: .dueSoon)
                    scheduleGroup(title: "Task 확인 필요", items: confirmationTasks, rowStyle: .confirmation)
                    scheduleGroup(title: "Task 진행 중", items: activeTasks)
                    scheduleGroup(title: "Task 연기됨", items: deferredTasks)
                    scheduleGroup(title: "완료됨", items: completedTasks)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func scheduleGroup(
        title: String,
        items: [TaskItem],
        rowStyle: ScheduleRowStyle = .normal
    ) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)

                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(items) { task in
                            taskRow(task, rowStyle: rowStyle)
                        }
                    }
                }
            }
        }
    }

    private func taskRow(
        _ task: TaskItem,
        rowStyle: ScheduleRowStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .strikethrough(task.isCompleted)

                        if rowStyle == .confirmation {
                            Text("확인 필요")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(WokeyDesign.warningFill)
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
                            .foregroundStyle(rowStyle == .dueSoon ? .red : .secondary)
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
                    deleteTask(task)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if rowStyle == .confirmation {
                confirmationActionButtons(task)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tagRow(_ task: TaskItem) -> some View {
        HStack {
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
                .background(WokeyDesign.statusFill)
                .clipShape(Capsule())

            if scheduleType(task) == .task {
                Text((task.requiresPCWork ?? true) ? "PC 작업" : "오프라인")
                    .font(.caption2)
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

    private func confirmationActionButtons(_ task: TaskItem) -> some View {
        HStack {
            Button("완료") {
                setStatus(task, status: .completed)
            }

            Button("진행 중") {
                setStatus(task, status: .inProgress)
            }

            Button("내일로 넘김") {
                deferTaskToTomorrow(task)
            }

            Spacer()
        }
        .font(.caption)
    }

    private var dueSoonTasks: [TaskItem] {
        tasks
            .filter {
                !$0.isCompleted &&
                scheduleType($0) == .task &&
                !$0.needsUserConfirmation &&
                $0.status != TaskStatus.uncertain.rawValue &&
                $0.status != TaskStatus.deferred.rawValue &&
                isDueSoon($0)
            }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private var confirmationTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted &&
            scheduleType($0) == .task &&
            ($0.needsUserConfirmation || $0.status == TaskStatus.uncertain.rawValue)
        }
    }

    private var activeTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted &&
            scheduleType($0) == .task &&
            !$0.needsUserConfirmation &&
            $0.status != TaskStatus.uncertain.rawValue &&
            $0.status != TaskStatus.deferred.rawValue &&
            !isDueSoon($0)
        }
    }

    private var deferredTasks: [TaskItem] {
        tasks.filter {
            !$0.isCompleted &&
            scheduleType($0) == .task &&
            $0.status == TaskStatus.deferred.rawValue
        }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }
    }

    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return
        }

        let task = TaskItem(
            title: trimmedTitle,
            detail: nil,
            source: "manual",
            status: TaskStatus.pending.rawValue,
            scheduleType: newScheduleType.rawValue,
            requiresPCWork: newScheduleType == .task,
            dueAt: normalizedDueDate(),
            relatedKeywords: nil
        )

        modelContext.insert(task)

        newTaskTitle = ""
        hasDueDate = false
        newTaskDueAt = Date()
        newScheduleType = .task
    }

    private func normalizedDueDate() -> Date {
        if hasDueDate {
            return newTaskDueAt
        }

        return Calendar.current.startOfDay(for: newTaskDueAt)
    }

    private func setStatus(_ task: TaskItem, status: TaskStatus) {
        task.status = status.rawValue
        task.isCompleted = status == .completed
        task.completedAt = status == .completed ? Date() : nil
        task.needsUserConfirmation = false
    }

    private func deferTaskToTomorrow(_ task: TaskItem) {
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Date()
        ) ?? Date()

        task.status = TaskStatus.deferred.rawValue
        task.deferredTo = tomorrow
        task.needsUserConfirmation = false
        task.isCompleted = false
        task.completedAt = nil
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
        for task in completedTasks {
            modelContext.delete(task)
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

    private var todayEvents: [TaskItem] {
        tasks
            .filter { scheduleType($0) == .event }
            .filter { !$0.isCompleted }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
    }

    private func scheduleType(_ task: TaskItem) -> ScheduleType {
        ScheduleType(rawValue: task.scheduleType ?? "") ?? .task
    }
}
