//
//  TodayView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

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
    @State private var isActionPillExpanded = false
    @State private var toastMessage: String?
    @State private var showCollectionPrompt = true
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    private let briefingService = BriefingService()
    private let evaluationService = TaskEvaluationService()
    private let responseService = TaskResponseService()
    private let floatingWidgetHeight: CGFloat = 142

    private let briefingSlots: [TodayBriefingSlot] = [
        TodayBriefingSlot(type: .morning, title: "아침", hour: 8, minute: 0),
        TodayBriefingSlot(type: .lunch, title: "점심", hour: 13, minute: 0),
        TodayBriefingSlot(type: .evening, title: "저녁", hour: 19, minute: 0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                headerSection

                if isSelectedDateToday {
                    progressSection

                    if let selectedProgress {
                        progressDetailSection(selectedProgress)
                    }
                }

                briefingSection
                    .padding(.bottom, 92)
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Today")
        .overlay(alignment: .top) {
            if let toastMessage {
                InAppToastView(message: toastMessage)
            }
        }
        .overlay(alignment: .bottom) {
            if isSelectedDateToday {
                floatingActionPill
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Today")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Button {
                        showDatePicker.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(WokeyDesign.ink)
                            .frame(width: 32, height: 32)
                            .background(WokeyDesign.quietFill)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(WokeyDesign.hairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .help("날짜별 브리핑 보기")
                    .popover(isPresented: $showDatePicker) {
                        VStack(alignment: .leading, spacing: 12) {
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                            HStack {
                                Button("오늘") {
                                    selectedDate = Date()
                                    selectedProgress = nil
                                    showDatePicker = false
                                }

                                Spacer()

                                Button("닫기") {
                                    showDatePicker = false
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(16)
                        .frame(width: 280)
                    }
                    .onChange(of: selectedDate) { _, _ in
                        selectedProgress = nil
                    }
                }

                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
            }

            Spacer()

            VStack(alignment: .center, spacing: 7) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { captureManager.isCapturing },
                        set: { isEnabled in
                            setCaptureEnabled(isEnabled)
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(width: 52, alignment: .center)

                if showCollectionPrompt && !captureManager.isCapturing {
                    VStack(spacing: -1) {
                        Triangle()
                            .fill(Color.white.opacity(0.94))
                            .frame(width: 16, height: 8)

                        Text("수집을 시작할까요?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WokeyDesign.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.94))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            }
                            .shadow(
                                color: Color.black.opacity(0.05),
                                radius: 10,
                                x: 0,
                                y: 5
                            )
                    }
                    .onTapGesture {
                        setCaptureEnabled(true)
                    }
                }
            }
            .frame(width: 142, alignment: .top)
            .frame(minHeight: 70, alignment: .top)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("진행 상황")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            HStack(spacing: 18) {
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
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .background(selectedProgress == kind ? WokeyDesign.statusFill : WokeyDesign.quietFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selectedProgress == kind ? WokeyDesign.muted.opacity(0.35) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func progressDetailSection(_ kind: TodayProgressKind) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(kind.title)
                .font(.headline)
                .foregroundStyle(WokeyDesign.ink)

            let rows = progressTasks(for: kind)

            if rows.isEmpty {
                Text(kind.emptyText)
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(rows) { task in
                        progressTaskRow(task, kind: kind)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func progressTaskRow(
        _ task: TaskItem,
        kind: TodayProgressKind
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WokeyDesign.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)
                    .lineLimit(1)

                Text(taskCaption(task))
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .lineLimit(1)
            }

            Spacer()

            if kind == .needsConfirmation {
                HStack(spacing: 8) {
                    Button("완료") {
                        markCompleted(task)
                    }

                    Button("진행 중") {
                        markInProgress(task)
                    }

                    Button("내일로 넘김") {
                        deferToTomorrow(task)
                    }
                }
                .buttonStyle(.bordered)
            } else if kind == .completed {
                Text(task.completedAt?.formatted(date: .omitted, time: .shortened) ?? "완료")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }


    private var floatingActionPill: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isActionPillExpanded {
                floatingActionExpandedContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    isActionPillExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isActionPillExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(WokeyDesign.blue)

                    Text("확인 필요 \(tasksNeedingConfirmation.count)")
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)

                    Text("·")
                        .foregroundStyle(WokeyDesign.muted)

                    Text("오늘 점검 \(todayCheckTasks.count)")
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)

                    if let firstQuestionTask = tasksNeedingConfirmation.first {
                        Text("·")
                            .foregroundStyle(WokeyDesign.muted)

                        Text(firstQuestionTask.title)
                            .font(.subheadline)
                            .foregroundStyle(WokeyDesign.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: 760, minHeight: 52)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(WokeyDesign.hairline, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var floatingActionExpandedContent: some View {
        HStack(alignment: .top, spacing: 18) {
            floatingTodayCheckWidget
                .frame(maxWidth: .infinity, minHeight: floatingWidgetHeight, maxHeight: floatingWidgetHeight, alignment: .topLeading)

            floatingConfirmationWidget
                .frame(maxWidth: .infinity, minHeight: floatingWidgetHeight, maxHeight: floatingWidgetHeight, alignment: .topLeading)
        }
        .padding(18)
        .frame(maxWidth: 760, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)
        .padding(.bottom, 10)
    }

    private var floatingTodayCheckWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("오늘 점검")
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text("\(todayCheckTasks.count)개")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if todayCheckTasks.isEmpty {
                Text("점검할 할 일이 없습니다.")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(todayCheckTasks.prefix(3)) { task in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(WokeyDesign.mint)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(WokeyDesign.ink)
                                    .lineLimit(1)

                                Text(taskCaption(task))
                                    .font(.caption2)
                                    .foregroundStyle(WokeyDesign.muted)
                                    .lineLimit(1)
                            }
                        }
                    }

                    if todayCheckTasks.count > 3 {
                        Text("+\(todayCheckTasks.count - 3)개 더 있음")
                            .font(.caption)
                            .foregroundStyle(WokeyDesign.muted)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: floatingWidgetHeight, maxHeight: floatingWidgetHeight, alignment: .topLeading)
        .background(WokeyDesign.panel.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var floatingConfirmationWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("확인 필요")
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text("\(tasksNeedingConfirmation.count)개")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if let task = tasksNeedingConfirmation.first {
                VStack(alignment: .leading, spacing: 10) {
                    Text(questionText(for: task))
                        .font(.subheadline)
                        .foregroundStyle(WokeyDesign.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button("완료") {
                            markCompleted(task)
                        }

                        Button("진행 중") {
                            markInProgress(task)
                        }

                        Button("내일로") {
                            deferToTomorrow(task)
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)

                    if tasksNeedingConfirmation.count > 1 {
                        Text("+\(tasksNeedingConfirmation.count - 1)개 더 있음")
                            .font(.caption)
                            .foregroundStyle(WokeyDesign.muted)
                    }
                }
            } else {
                Text("확인할 질문이 없습니다.")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: floatingWidgetHeight, maxHeight: floatingWidgetHeight, alignment: .topLeading)
        .background(WokeyDesign.panel.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("브리핑")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                if !isSelectedDateToday {
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(briefingSlots) { slot in
                    briefingCard(slot)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func briefingCard(_ slot: TodayBriefingSlot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(slot.title) 브리핑")
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Text(slot.timeText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.muted)

                Spacer()
            }

            if let briefing = selectedDateBriefing(for: slot.type) {
                Text(briefing.content)
                    .font(.body)
                    .foregroundStyle(WokeyDesign.ink)
                    .lineLimit(8)
                    .textSelection(.enabled)

                if !briefing.questions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()

                    Text(briefing.questions)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
            } else if isSelectedDateToday && slot.isDueNow {
                HStack(alignment: .center, spacing: 12) {
                    Text("아직 생성된 브리핑이 없습니다.")
                        .font(.subheadline)
                        .foregroundStyle(WokeyDesign.muted)

                    Spacer()

                    Button("\(slot.title) 브리핑 생성") {
                        generateBriefing(slot.type)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 82, alignment: .center)
            } else if isSelectedDateToday {
                Text("\(slot.scheduledText) 이후 생성 가능")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .center)
            } else {
                Text("이 날짜에 생성된 브리핑이 없습니다.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(WokeyDesign.statusFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var todayCompletedTasks: [TaskItem] {
        tasks
            .filter { scheduleType($0) == .task }
            .filter {
                guard let completedAt = $0.completedAt else {
                    return false
                }

                return $0.isCompleted && Calendar.current.isDateInToday(completedAt)
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
        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()

        return tasks
            .filter { task in
                guard !task.isCompleted,
                      scheduleType(task) == .task else {
                    return false
                }

                if task.needsUserConfirmation ||
                    task.status == TaskStatus.uncertain.rawValue {
                    return true
                }

                guard task.status == TaskStatus.pending.rawValue else {
                    return false
                }

                let isDueOrOverdue = task.dueAt.map { $0 < startOfTomorrow } == true
                let startsToday = task.plannedStartAt.map {
                    calendar.isDateInToday($0)
                } == true

                return isDueOrOverdue || startsToday
            }
            .sorted(by: taskSort)
    }

    private var todayCheckTasks: [TaskItem] {
        tasks
            .filter {
                !$0.isCompleted &&
                scheduleType($0) == .task &&
                $0.status != TaskStatus.deferred.rawValue
            }
            .filter {
                isDueToday($0) ||
                $0.status == TaskStatus.pending.rawValue ||
                $0.status == TaskStatus.inProgress.rawValue ||
                $0.status == TaskStatus.uncertain.rawValue ||
                $0.needsUserConfirmation
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

    private func taskCaption(_ task: TaskItem) -> String {
        var parts: [String] = []

        if let dueAt = task.dueAt {
            parts.append("마감 \(dueAt.formatted(date: .abbreviated, time: .shortened))")
        }

        parts.append(statusDisplayName(task.status))

        return parts.joined(separator: " · ")
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

    private func isDueToday(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        return Calendar.current.isDateInToday(dueAt)
    }

    private func scheduleType(_ task: TaskItem) -> ScheduleType {
        ScheduleType(rawValue: task.scheduleType ?? "") ?? .task
    }

    private func statusDisplayName(_ rawValue: String) -> String {
        TaskStatus(rawValue: rawValue)?.displayName ?? rawValue
    }

    private var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private func selectedDateBriefing(for type: BriefingType) -> Briefing? {
        briefings.first {
            $0.type == type.rawValue &&
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

    private func generateBriefing(_ type: BriefingType) {
        let briefing = briefingService.generateBriefing(
            type: type,
            tasks: tasks,
            activities: activities,
            snapshots: snapshots
        )

        briefing.date = Date()
        briefing.createdAt = Date()
        modelContext.insert(briefing)
        saveContext()
        showToast("\(type.displayName)를 생성했습니다.")
    }

    private func setCaptureEnabled(_ isEnabled: Bool) {
        if isEnabled {
            showCollectionPrompt = false
            captureManager.start(modelContext: modelContext)
            showToast("자동 수집을 시작했습니다.")
        } else {
            captureManager.stop(modelContext: modelContext)
            showCollectionPrompt = true
            showToast("자동 수집을 중지했습니다.")
        }

        saveContext()
    }


    private func markCompleted(_ task: TaskItem) {
        responseService.markCompleted(task: task, modelContext: modelContext)
        saveContext()
        showToast("완료로 반영했습니다.")
    }

    private func markInProgress(_ task: TaskItem) {
        responseService.markInProgress(task: task, modelContext: modelContext)
        saveContext()
        showToast("진행 중으로 반영했습니다.")
    }

    private func deferToTomorrow(_ task: TaskItem) {
        responseService.deferToTomorrow(task: task, modelContext: modelContext)
        saveContext()
        showToast("내일로 넘겼습니다.")
    }

    private func saveContext() {
        try? modelContext.save()
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
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

    var systemImage: String {
        switch self {
        case .completed:
            return "checkmark.circle.fill"
        case .inProgress:
            return "play.circle.fill"
        case .needsConfirmation:
            return "questionmark.circle.fill"
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
