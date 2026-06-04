//
//  TodayView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData
import Combine

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var captureManager: ContextCaptureManager

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \ScreenContextSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ScreenContextSnapshot]

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @Query(sort: \Briefing.createdAt, order: .reverse)
    private var briefings: [Briefing]

    @State private var selectedProgress: TodayProgressKind?
    @State private var showCollectionPrompt = true

    private let briefingService = BriefingService()
    private let evaluationService = TaskEvaluationService()
    private let responseService = TaskResponseService()

    private let briefingSlots: [TodayBriefingSlot] = [
        TodayBriefingSlot(type: .morning, title: "아침", hour: 8, minute: 0),
        TodayBriefingSlot(type: .lunch, title: "점심", hour: 13, minute: 0),
        TodayBriefingSlot(type: .evening, title: "저녁", hour: 19, minute: 0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                headerSection
                progressSection

                if let selectedProgress {
                    progressDetailSection(selectedProgress)
                }

                briefingListSection
                confirmationQuestionsSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Today")
        .onAppear {
            ensureDueBriefings()
        }
        .onChange(of: activities.count) { _, _ in
            evaluateTasksIfCollecting()
            ensureDueBriefings()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            evaluateTasksIfCollecting()
            ensureDueBriefings()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(WokeyDesign.ink)

                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WokeyDesign.muted)
            }

            Spacer()

            VStack(alignment: .center, spacing: 8) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { captureManager.isCapturing },
                        set: { isEnabled in
                            setCollectionEnabled(isEnabled)
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)

                if showCollectionPrompt && !captureManager.isCapturing {
                    VStack(spacing: -1) {
                        Triangle()
                            .fill(Color.white.opacity(0.94))
                            .frame(width: 22, height: 11)

                        Text("수집을 시작할까요?")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(WokeyDesign.ink)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.94))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
                    }
                    .onTapGesture {
                        setCollectionEnabled(true)
                    }
                }
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("진행 상황")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(WokeyDesign.ink)

            HStack(spacing: 28) {
                progressCard(
                    kind: .completed,
                    title: "완료",
                    value: todayCompletedTasks.count
                )

                progressCard(
                    kind: .inProgress,
                    title: "진행 중",
                    value: todayInProgressTasks.count
                )

                progressCard(
                    kind: .needsConfirmation,
                    title: "확인 필요",
                    value: tasksNeedingConfirmation.count
                )
            }
        }
    }

    private func progressCard(
        kind: TodayProgressKind,
        title: String,
        value: Int
    ) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedProgress = selectedProgress == kind ? nil : kind
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WokeyDesign.muted)

                Text("\(value)")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 118, alignment: .leading)
            .background(selectedProgress == kind ? WokeyDesign.statusFill : WokeyDesign.quietFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selectedProgress == kind ? WokeyDesign.muted.opacity(0.45) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func progressDetailSection(_ kind: TodayProgressKind) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(kind.title)
                .font(.headline)
                .foregroundStyle(WokeyDesign.ink)

            let rows = progressTasks(for: kind)

            if rows.isEmpty {
                Text(kind.emptyText)
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.persistentModelID) { index, task in
                        progressTaskRow(task, kind: kind)
                            .background(index.isMultiple(of: 2) ? Color.clear : WokeyDesign.quietFill)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    @ViewBuilder
    private func progressTaskRow(
        _ task: TaskItem,
        kind: TodayProgressKind
    ) -> some View {
        HStack(alignment: .center, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)
                    .lineLimit(1)
            }

            Spacer()

            switch kind {
            case .completed:
                Text(task.completedAt?.formatted(date: .omitted, time: .shortened) ?? "-")
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)
                    .frame(width: 140, alignment: .trailing)

            case .inProgress:
                EmptyView()

            case .needsConfirmation:
                HStack(spacing: 8) {
                    Button("진행 중") {
                        responseService.markInProgress(task: task, modelContext: modelContext)
                        saveContext()
                    }

                    Button("완료") {
                        responseService.markCompleted(task: task, modelContext: modelContext)
                        saveContext()
                    }

                    Button("내일로 넘김") {
                        responseService.deferToTomorrow(task: task, modelContext: modelContext)
                        saveContext()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var briefingListSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("브리핑 목록")
                .font(.headline)
                .foregroundStyle(WokeyDesign.ink)

            ForEach(briefingSlots) { slot in
                briefingCard(slot)
            }
        }
    }

    private func briefingCard(_ slot: TodayBriefingSlot) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(slot.title)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Text(slot.timeText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.muted)

                Spacer()
            }

            if slot.isDueNow {
                Text(normalizedBriefingContent(for: slot))
                    .font(.system(.body, design: .default))
                    .foregroundStyle(WokeyDesign.ink)
                    .lineSpacing(7)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("\(slot.scheduledText) 호출 예정")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .padding(30)
        .background(WokeyDesign.statusFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var confirmationQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text("확인 질문")
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Text("완료 / 진행 중 / 내일로 넘김")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if tasksNeedingConfirmation.isEmpty {
                Text("현재 확인할 질문이 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(tasksNeedingConfirmation.enumerated()), id: \.element.persistentModelID) { index, task in
                        confirmationQuestionCard(task, index: index + 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func confirmationQuestionCard(
        _ task: TaskItem,
        index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Q\(index). \(questionText(for: task))")
                .font(.body)
                .foregroundStyle(WokeyDesign.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("완료") {
                    responseService.markCompleted(task: task, modelContext: modelContext)
                    saveContext()
                }

                Button("진행 중") {
                    responseService.markInProgress(task: task, modelContext: modelContext)
                    saveContext()
                }

                Button("내일로 넘김") {
                    responseService.deferToTomorrow(task: task, modelContext: modelContext)
                    saveContext()
                }

                Spacer()
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func normalizedBriefingContent(for slot: TodayBriefingSlot) -> String {
        var lines: [String] = []
        let title = "\(slot.title) 브리핑"

        lines.append("[\(title)]")
        lines.append(slot.scheduledDate.formattedBriefingHeader)
        lines.append("")

        let visibleTasks = briefingTasks(for: slot.type)

        if visibleTasks.isEmpty {
            lines.append("오늘 표시할 Task가 없습니다.")
        } else {
            for (index, task) in visibleTasks.enumerated() {
                lines.append("\(index + 1). \(task.title)")

                if let dueAt = task.dueAt {
                    lines.append("- 마감: \(dueAt.formattedDueText)")
                }

                if let plannedStartAt = task.plannedStartAt {
                    lines.append("- 시작: \(plannedStartAt.formattedDueText)")
                }

                if let evidence = trimmedEvidence(task) {
                    lines.append("- \(evidence)")
                }

                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func questionText(for task: TaskItem) -> String {
        if let evidence = trimmedEvidence(task) {
            return "\(task.title)를 \(evidence)\n이 일은 현재 완료된 상태인가요?"
        }

        if let dueAt = task.dueAt,
           Calendar.current.isDateInToday(dueAt) {
            return "\(task.title) 마감이 오늘 \(dueAt.formatted(date: .omitted, time: .shortened))인데, 아직 완료 근거가 부족해요.\n현재 상태를 알려주세요."
        }

        return "\(task.title)의 진행 상태를 아직 판단하지 못했어요.\n현재 상태를 알려주세요."
    }

    private func progressTasks(for kind: TodayProgressKind) -> [TaskItem] {
        switch kind {
        case .completed:
            return todayCompletedTasks
        case .inProgress:
            return todayInProgressTasks
        case .needsConfirmation:
            return tasksNeedingConfirmation
        }
    }

    private func briefingTasks(for type: BriefingType) -> [TaskItem] {
        let taskItems = tasks.filter { scheduleType($0) == .task }

        switch type {
        case .morning:
            return taskItems
                .filter { !$0.isCompleted }
                .filter {
                    isDueToday($0) ||
                    isDeferredToToday($0) ||
                    $0.dueAt == nil ||
                    $0.status == TaskStatus.pending.rawValue ||
                    $0.status == TaskStatus.inProgress.rawValue ||
                    $0.status == TaskStatus.uncertain.rawValue
                }
                .sorted(by: taskSort)

        case .lunch:
            return taskItems
                .filter { !$0.isCompleted }
                .filter {
                    isDueToday($0) ||
                    $0.status == TaskStatus.pending.rawValue ||
                    $0.status == TaskStatus.inProgress.rawValue ||
                    $0.status == TaskStatus.uncertain.rawValue ||
                    $0.needsUserConfirmation
                }
                .sorted(by: taskSort)

        case .evening:
            let completed = taskItems
                .filter { $0.isCompleted && isCompletedToday($0) }
            let unfinished = taskItems
                .filter { !$0.isCompleted }

            return (completed + unfinished).sorted(by: taskSort)
        }
    }

    private var todayCompletedTasks: [TaskItem] {
        tasks
            .filter {
                guard let completedAt = $0.completedAt else {
                    return false
                }

                return Calendar.current.isDateInToday(completedAt)
            }
            .sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
    }

    private var todayInProgressTasks: [TaskItem] {
        tasks
            .filter {
                !$0.isCompleted &&
                scheduleType($0) == .task &&
                $0.status == TaskStatus.inProgress.rawValue
            }
            .sorted(by: taskSort)
    }

    private var tasksNeedingConfirmation: [TaskItem] {
        tasks
            .filter {
                !$0.isCompleted &&
                scheduleType($0) == .task &&
                ($0.needsUserConfirmation || $0.status == TaskStatus.uncertain.rawValue)
            }
            .sorted(by: taskSort)
    }

    private func taskSort(_ first: TaskItem, _ second: TaskItem) -> Bool {
        let firstScore = taskPriorityScore(first)
        let secondScore = taskPriorityScore(second)

        if firstScore != secondScore {
            return firstScore > secondScore
        }

        return (first.dueAt ?? .distantFuture) < (second.dueAt ?? .distantFuture)
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

        if task.status == TaskStatus.deferred.rawValue {
            return 30
        }

        return 40
    }

    private func scheduleType(_ task: TaskItem) -> ScheduleType {
        ScheduleType(rawValue: task.scheduleType ?? "") ?? .task
    }

    private func isDueToday(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        return Calendar.current.isDateInToday(dueAt)
    }

    private func isDeferredToToday(_ task: TaskItem) -> Bool {
        guard let deferredTo = task.deferredTo else {
            return false
        }

        return Calendar.current.isDateInToday(deferredTo)
    }

    private func isCompletedToday(_ task: TaskItem) -> Bool {
        guard let completedAt = task.completedAt else {
            return false
        }

        return Calendar.current.isDateInToday(completedAt)
    }

    private func trimmedEvidence(_ task: TaskItem) -> String? {
        guard let evidence = task.evidenceSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !evidence.isEmpty else {
            return nil
        }

        return evidence
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func todayBriefing(
        for type: BriefingType
    ) -> Briefing? {
        briefings.first {
            $0.type == type.rawValue &&
            Calendar.current.isDateInToday($0.date)
        }
    }

    private func ensureDueBriefings() {
        for slot in briefingSlots where slot.isDueNow {
            guard todayBriefing(for: slot.type) == nil else {
                continue
            }

            let briefing = briefingService.generateBriefing(
                type: slot.type,
                tasks: tasks,
                activities: activities,
                snapshots: snapshots
            )
            briefing.date = Date()
            briefing.createdAt = Date()
            modelContext.insert(briefing)
        }

        saveContext()
    }

    private func setCollectionEnabled(_ isEnabled: Bool) {
        if isEnabled {
            showCollectionPrompt = false
            captureManager.start(modelContext: modelContext)
            evaluateTasksFromCurrentLogs()
        } else {
            captureManager.stop(modelContext: modelContext)
            showCollectionPrompt = true
        }
    }

    private func evaluateTasksIfCollecting() {
        guard captureManager.isCapturing else {
            return
        }

        evaluateTasksFromCurrentLogs()
    }

    private func evaluateTasksFromCurrentLogs() {
        let results = evaluationService.evaluateTasks(
            tasks: tasks,
            activities: activities
        )

        evaluationService.applyEvaluationResults(results)
        saveContext()
    }

    private func saveContext() {
        try? modelContext.save()
    }
}

private enum TodayProgressKind: String {
    case completed
    case inProgress
    case needsConfirmation

    var title: String {
        switch self {
        case .completed:
            return "완료한 일"
        case .inProgress:
            return "진행 중인 일"
        case .needsConfirmation:
            return "확인이 필요한 일"
        }
    }

    var emptyText: String {
        switch self {
        case .completed:
            return "오늘 완료된 일이 없습니다."
        case .inProgress:
            return "현재 진행 중인 일이 없습니다."
        case .needsConfirmation:
            return "확인이 필요한 일이 없습니다."
        }
    }
}

private struct TodayBriefingSlot: Identifiable {
    let type: BriefingType
    let title: String
    let hour: Int
    let minute: Int

    var id: String {
        type.rawValue
    }

    var scheduledDate: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    var isDueNow: Bool {
        Date() >= scheduledDate
    }

    var timeText: String {
        scheduledDate.formatted(date: .omitted, time: .shortened)
    }

    var scheduledText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "H시"
        return formatter.string(from: scheduledDate)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private extension Date {
    var formattedBriefingHeader: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 (E) a h:mm"
        return formatter.string(from: self)
    }

    var formattedDueText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yy/MM/dd HH:mm"
        return formatter.string(from: self)
    }
}
