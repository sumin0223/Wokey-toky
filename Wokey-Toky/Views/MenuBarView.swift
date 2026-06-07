//
//  MenuBarView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var captureManager: ContextCaptureManager

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]
    
    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \ScreenContextSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ScreenContextSnapshot]

    @Query(sort: \Briefing.createdAt, order: .reverse)
    private var briefings: [Briefing]

    private let responseService = TaskResponseService()
    private let evaluationService = TaskEvaluationService()
    private let briefingService = BriefingService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            workStateSection

            Divider()

            briefingActionSection

            Divider()

            confirmationSection

            Divider()

            todayTasksSection

            Divider()

            latestBriefingSection

            Divider()

            footerSection
        }
        .padding()
        .frame(width: 380)
    }

    private var headerSection: some View {
        HStack {
            Text("🐰 Wokey-Toky")
                .font(.headline)

            Spacer()

            Text("\(activeTasks.count)개 남음")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var workStateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("현재 상태")
                    .font(.subheadline)
                    .bold()

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(workStateIndicatorColor)
                        .frame(width: 8, height: 8)

                    Text(captureManager.userWorkState.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }

            HStack(spacing: 6) {
                ForEach(UserWorkState.allCases) { state in
                    Button(state.displayName) {
                        captureManager.setUserWorkState(
                            state,
                            modelContext: modelContext
                        )
                    }
                    .disabled(captureManager.userWorkState == state)
                }
            }
            .font(.caption)

            Text(workStateDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var workStateIndicatorColor: Color {
        switch captureManager.userWorkState {
        case .working:
            return .blue
        case .resting:
            return .orange
        case .away:
            return .secondary
        }
    }

    private var workStateDescription: String {
        switch captureManager.userWorkState {
        case .working:
            return captureManager.isCapturing
                ? "활동 기록을 수집하고 있습니다."
                : "현재 활동 기록은 꺼져 있습니다."
        case .resting:
            return "휴식 중에는 활동 기록을 일시정지합니다."
        case .away:
            return "자리 비움 중에는 활동 기록을 일시정지합니다."
        }
    }

    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("답변 필요")
                .font(.subheadline)
                .bold()

            if confirmationTasks.isEmpty {
                Text("답변이 필요한 할 일이 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(confirmationTasks.prefix(3)) { task in
                    compactTaskCard(task, showActions: true)
                }
            }
        }
    }

    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘 점검할 일")
                .font(.subheadline)
                .bold()

            if todayCheckTasks.isEmpty {
                Text("오늘 점검할 할 일이 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todayCheckTasks.prefix(5)) { task in
                    compactTaskCard(task, showActions: true)
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("알림 권한 요청") {
                Task {
                    _ = await NotificationService.shared.requestAuthorization()
                }
            }
            Button("답변 필요 알림 테스트") {
                        NotificationService.shared.scheduleTaskConfirmationNotification(
                            taskCount: confirmationTasks.count
                        )
                    }
                    .disabled(confirmationTasks.isEmpty)
            if confirmationTasks.isEmpty {
                Text("답변 필요한 할 일이 있을 때 알림 테스트가 가능합니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Button("Wokey-Toky 열기") {
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Wokey-Toky 종료") {
                NSApp.terminate(nil)
            }
            .foregroundStyle(.red)
        }
    }

    private func compactTaskCard(
        _ task: TaskItem,
        showActions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title)
                    .font(.caption)
                    .bold()
                    .lineLimit(1)

                Spacer()

                Text(statusDisplayName(task.status))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let dueAt = task.dueAt {
                Text("마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(isOverdue(task) ? .red : .secondary)
            }

            if showActions {
                HStack(spacing: 6) {
                    Button("완료") {
                        responseService.markCompleted(
                            task: task,
                            modelContext: modelContext
                        )
                    }

                    Button("진행") {
                        responseService.markInProgress(
                            task: task,
                            modelContext: modelContext
                        )
                    }

                    Button("미완료") {
                        responseService.markPending(
                            task: task,
                            modelContext: modelContext
                        )
                    }

                    Button("내일") {
                        responseService.deferToTomorrow(
                            task: task,
                            modelContext: modelContext
                        )
                    }
                }
                .font(.caption2)
            }
        }
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var confirmationTasks: [TaskItem] {
        tasks
            .filter { !$0.isCompleted }
            .filter {
                $0.needsUserConfirmation ||
                $0.status == TaskStatus.uncertain.rawValue
            }
            .sorted { first, second in
                taskPriorityScore(first) > taskPriorityScore(second)
            }
    }

    private var todayCheckTasks: [TaskItem] {
        tasks
            .filter { !$0.isCompleted }
            .filter {
                $0.status != TaskStatus.deferred.rawValue
            }
            .filter {
                !$0.needsUserConfirmation &&
                $0.status != TaskStatus.uncertain.rawValue
            }
            .filter {
                isDueToday($0) ||
                $0.status == TaskStatus.pending.rawValue ||
                $0.status == TaskStatus.inProgress.rawValue
            }
            .sorted { first, second in
                let firstScore = taskPriorityScore(first)
                let secondScore = taskPriorityScore(second)

                if firstScore != secondScore {
                    return firstScore > secondScore
                }

                return (first.dueAt ?? Date.distantFuture) < (second.dueAt ?? Date.distantFuture)
            }
    }

    private func taskPriorityScore(_ task: TaskItem) -> Int {
        if task.needsUserConfirmation {
            return 100
        }

        if task.status == TaskStatus.uncertain.rawValue {
            return 90
        }

        if let dueAt = task.dueAt {
            if dueAt < Date() {
                return 80
            }

            if Calendar.current.isDateInToday(dueAt) {
                return 70
            }
        }

        if task.status == TaskStatus.inProgress.rawValue {
            return 60
        }

        return 40
    }

    private func isDueToday(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        return Calendar.current.isDateInToday(dueAt)
    }

    private func isOverdue(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        return !task.isCompleted && dueAt < Date()
    }

    private func statusDisplayName(_ rawValue: String) -> String {
        TaskStatus(rawValue: rawValue)?.displayName ?? rawValue
    }
    
    private var briefingActionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("브리핑")
                .font(.subheadline)
                .bold()

            HStack(spacing: 6) {
                Button("아침") {
                    generateBriefing(.morning)
                }

                Button("점심") {
                    generateBriefing(.lunch)
                }

                Button("저녁") {
                    generateBriefing(.evening)
                }
            }
            .font(.caption)

            Text("활동 기록과 할 일을 비교한 뒤 브리핑을 생성합니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // 메뉴바에서 최근 브리핑 짧게
    private var latestBriefingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 브리핑")
                .font(.subheadline)
                .bold()

            if let latest = briefings.first {
                Text(latest.title)
                    .font(.caption)
                    .bold()

                Text(latest.content)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(5) // 메뉴바 공간 보고 조정하기

                Text(latest.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("아직 생성된 브리핑이 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // 일단 llm 안붙이고 규칙기반 브리핑만 넣었음(느려서)
    private func generateBriefing(_ type: BriefingType) {
        let results = evaluationService.evaluateTasks(
            tasks: tasks,
            activities: activities
        )

        evaluationService.applyEvaluationResults(results)

        let briefing = briefingService.generateBriefing(
            type: type,
            tasks: tasks,
            activities: activities,
            snapshots: snapshots
        )

        modelContext.insert(briefing)
    }
}
