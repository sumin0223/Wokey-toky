//
//  BriefingView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import SwiftUI
import SwiftData

struct BriefingView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \ScreenContextSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ScreenContextSnapshot]

    @Query(sort: \Briefing.createdAt, order: .reverse)
    private var briefings: [Briefing]
    
    @Query private var llmConfigs: [LLMConfig]

    @Query(sort: \UserTaskResponse.createdAt, order: .reverse)
    private var userResponses: [UserTaskResponse]

    private let briefingService = BriefingService()
    private let evaluationService = TaskEvaluationService()
    private let responseService = TaskResponseService()
    private let contextBuilder = BriefingContextBuilder()
    private let llmService = LLMService()

    @State private var isGeneratingLLMBriefing = false
    @State private var llmErrorMessage: String?
    @State private var naturalResponseText = ""
    @State private var appliedResponseMessages: [String] = []
    @State private var clarificationMessages: [String] = []
    @State private var reviewMessages: [String] = []
    @State private var isInterpretingResponse = false
    @State private var interpretationErrorMessage: String?
    @State private var undoStack: [TaskUndoSnapshot] = []

    private let autoApplyNaturalResponses = true
    private let autoApplyConfidenceThreshold = 0.75
    private let reviewConfidenceThreshold = 0.45

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerSection
                
                actionSection
                
                llmErrorSection
                
                latestBriefingSection
                
                naturalResponseSection
                
                confirmationTasksSection
                
                todayCheckTasksSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Briefing")
                .font(.largeTitle)
                .bold()

            Text("애매한 답변을 누적해 점심 보고, 저녁 회고, 내일로 넘길 일을 정리합니다.")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)
        }
    }

    private var actionSection: some View {
        HStack {
            Button(isGeneratingLLMBriefing ? "생성 중..." : "점심 보고 만들기") {
                Task {
                    await generateBriefingWithFallback(.lunch)
                }
            }
            .disabled(isGeneratingLLMBriefing)

            Button(isGeneratingLLMBriefing ? "생성 중..." : "저녁 회고 및 내일 정리") {
                Task {
                    await generateBriefingWithFallback(.evening)
                }
            }
            .disabled(isGeneratingLLMBriefing)

            Spacer()

            Button("브리핑 전체 삭제") {
                deleteAllBriefings()
            }
            .foregroundStyle(WokeyDesign.active)
        }
    }
    
    private var llmErrorSection: some View {
        Group {
            if let llmErrorMessage {
                Text(llmErrorMessage)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.active)
                    .padding()
                    .background(WokeyDesign.warningFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var latestBriefingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 브리핑")
                .font(.title2)
                .bold()

            if let latest = briefings.first {
                briefingCard(latest, isLatest: true)
            } else {
                ContentUnavailableView(
                    "아직 생성된 브리핑이 없습니다",
                    systemImage: "text.bubble",
                    description: Text("점심 보고나 저녁 회고를 생성해보세요.")
                )
            }
        }
    }
    
    private var confirmationTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("답변이 필요한 할 일")
                .font(.title2)
                .bold()

            let confirmationTasks = tasksNeedingConfirmation

            if confirmationTasks.isEmpty {
                Text("현재 답변이 필요한 할 일이 없습니다.")
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                ForEach(confirmationTasks) { task in
                    confirmationTaskCard(task)
                }
            }
        }
    }
    
    private var naturalResponseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("자연어 답변")
                .font(.title2)
                .bold()

            Text("짧게 답해도 됩니다. 확실한 답변은 자동 반영하고, 애매한 답변은 다시 확인합니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)

            TextEditor(text: $naturalResponseText)
                .frame(minHeight: 90)
                .padding(8)
                .background(WokeyDesign.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Button(isInterpretingResponse ? "처리 중..." : "답변 처리") {
                    Task {
                        await interpretAndRouteNaturalResponse()
                    }
                }
                .disabled(
                    isInterpretingResponse ||
                    naturalResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Button("초기화") {
                    naturalResponseText = ""
                    appliedResponseMessages = []
                    clarificationMessages = []
                    reviewMessages = []
                    interpretationErrorMessage = nil
                }

                Button("뒤로가기") {
                    undoLastTaskChange()
                }
                .disabled(undoStack.isEmpty)

                Spacer()
            }

            if let interpretationErrorMessage {
                Text(interpretationErrorMessage)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.active)
            }

            if !appliedResponseMessages.isEmpty {
                responseResultBox(
                    title: "자동 반영됨",
                    messages: appliedResponseMessages
                )
            }

            if !reviewMessages.isEmpty {
                responseResultBox(
                    title: "검토 필요",
                    messages: reviewMessages
                )
            }

            if !clarificationMessages.isEmpty {
                responseResultBox(
                    title: "역질문",
                    messages: clarificationMessages
                )
            }
        }
        .wokeyPanel()
    }
    
    private func todayCheckTaskCard(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.headline)

                Spacer()

                Text(statusDisplayName(task.status))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WokeyDesign.statusFill)
                    .clipShape(Capsule())
            }
            
            if let plannedStartAt = task.plannedStartAt {
                Text("시작: \(plannedStartAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if let dueAt = task.dueAt {
                Text("마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(isOverdue(task) ? WokeyDesign.active : WokeyDesign.muted)
            }

            if let evidence = task.evidenceSummary,
               !evidence.isEmpty {
                Text("근거: \(evidence)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .lineLimit(3)
            }

            HStack {
                Button("완료") {
                    remember(task)
                    responseService.markCompleted(
                        task: task,
                        modelContext: modelContext
                    )
                }

                Button("진행 중") {
                    remember(task)
                    responseService.markInProgress(
                        task: task,
                        modelContext: modelContext
                    )
                }

                Button("미완료") {
                    remember(task)
                    responseService.markPending(
                        task: task,
                        modelContext: modelContext
                    )
                }

                Button("내일로 넘김") {
                    remember(task)
                    responseService.deferToTomorrow(
                        task: task,
                        modelContext: modelContext
                    )
                }

                Spacer()
            }
            .font(.caption)
        }
        .wokeyPanel()
    }
    
    private var todayCheckTasks: [TaskItem] {
        tasks
            .filter { !$0.isCompleted }
            .filter { scheduleType($0) == .task }
            .filter {
                $0.status != TaskStatus.deferred.rawValue
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

                return (first.dueAt ?? .distantFuture) < (second.dueAt ?? .distantFuture)
            }
    }
    
    private func isOverdue(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        return !task.isCompleted && dueAt < Date()
    }
    
    private var todayCheckTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘 점검할 할 일")
                .font(.title2)
                .bold()

            let checkTasks = todayCheckTasks

            if checkTasks.isEmpty {
                Text("현재 오늘 점검할 할 일이 없습니다.")
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                ForEach(checkTasks) { task in
                    todayCheckTaskCard(task)
                }
            }
        }
    }
    
    private var tasksNeedingConfirmation: [TaskItem] {
        tasks
            .filter { !$0.isCompleted }
            .filter { scheduleType($0) == .task }
            .filter {
                $0.needsUserConfirmation ||
                $0.status == TaskStatus.uncertain.rawValue
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

    private func briefingCard(
        _ briefing: Briefing,
        isLatest: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(briefing.title)
                        .font(isLatest ? .title2 : .headline)
                        .bold()

                    Text(briefingTypeText(briefing.type))
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                Text(briefing.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("브리핑 내용")
                    .font(.headline)

                Text(briefing.content)
                    .font(.system(.body, design: .default))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if !briefing.questions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("확인 질문")
                        .font(.headline)

                    Text(briefing.questions)
                        .font(.body)
                .foregroundStyle(WokeyDesign.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func evaluateAndGenerate(_ type: BriefingType) {
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

    private func generateBriefingWithFallback(_ type: BriefingType) async {
        guard currentLLMConfig != nil else {
            evaluateAndGenerate(type)
            return
        }

        await generateLLMBriefing(type)
    }

    private func deleteAllBriefings() {
        for briefing in briefings {
            modelContext.delete(briefing)
        }
    }
    
    private func confirmationTaskCard(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(task.title)
                    .font(.headline)

                Spacer()

                Text(statusDisplayName(task.status))
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WokeyDesign.statusFill)
                    .clipShape(Capsule())
            }

            if let dueAt = task.dueAt {
                Text("마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if let evidence = task.evidenceSummary,
               !evidence.isEmpty {
                Text(evidence)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .textSelection(.enabled)
            }

            HStack {
                Button("완료") {
                    remember(task)
                    responseService.markCompleted(
                        task: task,
                        modelContext: modelContext
                    )
                }

                Button("진행 중") {
                    remember(task)
                    responseService.markInProgress(
                        task: task,
                        modelContext: modelContext
                    )
                }

                Button("미완료") {
                    remember(task)
                    responseService.markPending(
                        task: task,
                        modelContext: modelContext
                    )
                }

                Button("내일로 넘김") {
                    remember(task)
                    responseService.deferToTomorrow(
                        task: task,
                        modelContext: modelContext
                    )
                }

                Spacer()
            }
            .font(.caption)
        }
        .wokeyPanel()
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

        return 40
    }

    private func isDueToday(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        return Calendar.current.isDateInToday(dueAt)
    }

    private func statusDisplayName(_ rawValue: String) -> String {
        TaskStatus(rawValue: rawValue)?.displayName ?? rawValue
    }

    private func scheduleType(_ task: TaskItem) -> ScheduleType {
        ScheduleType(rawValue: task.scheduleType ?? "") ?? .task
    }
    
    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private func generateLLMBriefing(_ type: BriefingType) async {
        let results = evaluationService.evaluateTasks(
            tasks: tasks,
            activities: activities
        )

        evaluationService.applyEvaluationResults(results)

        guard let config = currentLLMConfig else {
            llmErrorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        isGeneratingLLMBriefing = true
        llmErrorMessage = nil

        let context = contextBuilder.buildContext(
            type: type,
            tasks: tasks,
            activities: activities,
            snapshots: snapshots,
            userResponses: userResponses
        )

        do {
            let content = try await llmService.generateBriefing(
                type: type,
                context: context,
                config: config
            )

            let briefing = Briefing(
                type: type.rawValue,
                title: "\(type.displayName) · LLM",
                content: content,
                questions: extractQuestionSection(from: content)
            )

            modelContext.insert(briefing)
        } catch {
            llmErrorMessage = error.localizedDescription
        }

        isGeneratingLLMBriefing = false
    }
    
    // 질문 섹션 추출 함수
    private func extractQuestionSection(from content: String) -> String {
        guard let range = content.range(of: "## 4. 확인 질문") else {
            return ""
        }

        let questionPart = content[range.lowerBound...]

        if let nextRange = questionPart.range(of: "## 5. 다음 행동 제안") {
            return String(questionPart[..<nextRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(questionPart)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func briefingTypeText(_ rawValue: String) -> String {
        BriefingType(rawValue: rawValue)?.displayName ?? rawValue
    }
    
    //결과박스 핼퍼
    private func responseResultBox(
        title: String,
        messages: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ForEach(messages, id: \.self) { message in
                Text("• \(message)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WokeyDesign.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // 자연어 답변 라우팅
    private func interpretAndRouteNaturalResponse() async {
        guard let config = currentLLMConfig else {
            interpretationErrorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        isInterpretingResponse = true
        interpretationErrorMessage = nil
        appliedResponseMessages = []
        clarificationMessages = []
        reviewMessages = []

        do {
            let trimmedText = naturalResponseText.trimmingCharacters(in: .whitespacesAndNewlines)
            let isShortAmbiguous = isShortAmbiguousResponse(trimmedText)

            let candidateTasks: [TaskItem]

            if isShortAmbiguous {
                if tasksNeedingConfirmation.count == 1 {
                    candidateTasks = tasksNeedingConfirmation
                } else if tasksNeedingConfirmation.isEmpty {
                    clarificationMessages = [
                        "답변이 필요한 할 일이 없는 상태라서 '\(trimmedText)'를 어떤 일에 반영해야 할지 알 수 없어요."
                    ]
                    isInterpretingResponse = false
                    return
                } else {
                    clarificationMessages = [
                        "어떤 할 일에 대한 답변인지 알려주세요. 답변이 필요한 할 일이 여러 개 있어요."
                    ]
                    isInterpretingResponse = false
                    return
                }
            } else {
                candidateTasks = uniqueTasks(
                    tasksNeedingConfirmation + todayCheckTasks
                )
            }

            guard !candidateTasks.isEmpty else {
                interpretationErrorMessage = "답변을 반영할 후보 할 일이 없습니다."
                isInterpretingResponse = false
                return
            }

            let interpretations = try await llmService.interpretTaskResponse(
                userText: naturalResponseText,
                tasks: candidateTasks,
                config: config
            )

            if interpretations.isEmpty {
                interpretationErrorMessage = "반영할 할 일을 찾지 못했어요. 할 일 이름을 조금 더 구체적으로 적어주세요."
                isInterpretingResponse = false
                return
            }

            routeInterpretations(
                interpretations,
                candidateTasks: candidateTasks
            )

            naturalResponseText = ""
        } catch {
            interpretationErrorMessage = error.localizedDescription
        }

        isInterpretingResponse = false
    }
    
    // 브리핑ㅇ 해석 결과 라우팅
    private func routeInterpretations(
        _ interpretations: [TaskResponseInterpretation],
        candidateTasks: [TaskItem]
    ) {
        var applied: [String] = []
        var clarification: [String] = []
        var review: [String] = []

        for interpretation in interpretations {
            guard let matchedTask = findTask(
                for: interpretation,
                in: candidateTasks
            ) else {
                clarification.append(
                    "\(interpretation.taskTitle): 어떤 할 일인지 찾지 못했어요."
                )
                continue
            }

            if interpretation.needsClarification {
                let question = interpretation.clarificationQuestion ?? "\(matchedTask.title)에 대한 답변이 맞나요?"
                clarification.append("\(matchedTask.title): \(question)")
                continue
            }

            if interpretation.confidence >= autoApplyConfidenceThreshold &&
                autoApplyNaturalResponses {
                remember(matchedTask)
                responseService.applyInterpretation(
                    interpretation,
                    to: matchedTask,
                    modelContext: modelContext
                )

                applied.append(
                    "\(matchedTask.title): \(interpretation.status.displayName)로 반영"
                )
                continue
            }

            if interpretation.confidence >= reviewConfidenceThreshold {
                review.append(
                    "\(matchedTask.title): \(interpretation.status.displayName)로 보이지만 확신도가 낮아요. 직접 버튼으로 확정해주세요. confidence \(String(format: "%.2f", interpretation.confidence))"
                )
            } else {
                let question = interpretation.clarificationQuestion ?? "\(matchedTask.title)의 상태를 다시 알려주세요."
                clarification.append(
                    "\(matchedTask.title): \(question)"
                )
            }
        }

        appliedResponseMessages = applied
        clarificationMessages = clarification
        reviewMessages = review

        if applied.isEmpty && clarification.isEmpty && review.isEmpty {
            interpretationErrorMessage = "처리할 수 있는 답변을 찾지 못했어요."
        }
    }
    
    // task 매칭 핼퍼
    private func findTask(
        for interpretation: TaskResponseInterpretation,
        in candidateTasks: [TaskItem]
    ) -> TaskItem? {
        let target = interpretation.taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if let exact = candidateTasks.first(where: { $0.title == target }) {
            return exact
        }

        return candidateTasks.first { task in
            task.title.localizedCaseInsensitiveContains(target) ||
            target.localizedCaseInsensitiveContains(task.title)
        }
    }

    private func uniqueTasks(_ input: [TaskItem]) -> [TaskItem] {
        var seen = Set<String>()
        var result: [TaskItem] = []

        for task in input {
            let key = "\(task.title)|\(task.createdAt.timeIntervalSince1970)"

            if seen.contains(key) {
                continue
            }

            seen.insert(key)
            result.append(task)
        }

        return result
    }
    
    // 짧은 답변 판별 함수.. 일단 어케 처리하는지 ㅁㄹ서 이거 함수로 처리함..
    private func isShortAmbiguousResponse(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let shortResponses = [
            "했어",
            "했어요",
            "완료",
            "완료했어",
            "끝",
            "끝냈어",
            "아직",
            "안했어",
            "안 했어",
            "미완료",
            "진행중",
            "진행 중",
            "내일",
            "내일할게",
            "내일 할게",
            "나중에"
        ]

        if shortResponses.contains(trimmed) {
            return true
        }

        return trimmed.count <= 4
    }

    private func remember(_ task: TaskItem) {
        undoStack.append(TaskUndoSnapshot(task: task))
    }

    private func undoLastTaskChange() {
        guard let snapshot = undoStack.popLast() else {
            return
        }

        snapshot.restore()
    }
}

private struct TaskUndoSnapshot {
    let task: TaskItem
    let status: String
    let isCompleted: Bool
    let completedAt: Date?
    let evidenceSummary: String?
    let needsUserConfirmation: Bool
    let deferredTo: Date?

    init(task: TaskItem) {
        self.task = task
        self.status = task.status
        self.isCompleted = task.isCompleted
        self.completedAt = task.completedAt
        self.evidenceSummary = task.evidenceSummary
        self.needsUserConfirmation = task.needsUserConfirmation
        self.deferredTo = task.deferredTo
    }

    func restore() {
        task.status = status
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.evidenceSummary = evidenceSummary
        task.needsUserConfirmation = needsUserConfirmation
        task.deferredTo = deferredTo
    }
}
