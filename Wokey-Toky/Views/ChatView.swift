//
//  ChatView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var captureManager: ContextCaptureManager

    @Query(sort: \ChatMessage.createdAt, order: .forward)
    private var messages: [ChatMessage]

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \Briefing.createdAt, order: .reverse)
    private var briefings: [Briefing]

    @Query(sort: \UserTaskResponse.createdAt, order: .reverse)
    private var userResponses: [UserTaskResponse]

    @Query(sort: \TaskChangeLog.createdAt, order: .reverse)
    private var taskChangeLogs: [TaskChangeLog]

    @Query private var llmConfigs: [LLMConfig]


    private let contextBuilder = ChatContextBuilder()
    private let llmService = LLMService()
    private let responseService = TaskResponseService()

    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showDeleteMessagesConfirmation = false
    @State private var toastMessage: String?
    @State private var pendingTaskChanges: [PendingChatTaskChange] = []
    @State private var pendingChangeReply = ""
    @State private var isEditingPendingChanges = false
    @State private var pendingStatusOverrides: [UUID: TaskStatus] = [:]
    @State private var pendingClarification: PendingChatClarification?
    @State private var pendingUserStateChange: PendingUserStateChange?

    @State private var recentChangeBatchID: UUID?
    @State private var recentRevertExpiresAt: Date?
    @State private var referencedTaskIDs: [UUID] = []

    var body: some View {
        VStack(spacing: 0) {
            headerSection


            Divider()

            messageListSection

            Divider()

            inputSection
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                InAppToastView(message: toastMessage)
            }
        }
        .confirmationDialog(
            "대화 기록을 모두 삭제할까요?",
            isPresented: $showDeleteMessagesConfirmation,
            titleVisibility: .visible
        ) {
            Button("대화 삭제", role: .destructive) {
                deleteAllMessages()
            }

            Button("취소", role: .cancel) { }
        } message: {
            Text("Chat 기록만 삭제됩니다. Task, 알림, 변경 이력은 유지됩니다.")
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wokey Chat")
                    .font(.largeTitle)
                    .bold()

                Text("할 일, 일정, 활동 기록, 브리핑을 바탕으로 작업 흐름을 관리합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("대화 삭제") {
                showDeleteMessagesConfirmation = true
            }
            .foregroundStyle(.red)
        }
        .padding()
    }

    private var messageListSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        emptyChatView
                    } else {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }

                    if !pendingTaskChanges.isEmpty {
                        pendingChangePreview
                    }

                    if let pendingClarification {
                        clarificationCard(pendingClarification)
                    }

                    if let pendingUserStateChange {
                        userStateChangeCard(pendingUserStateChange)
                    }

                    if canUndoRecentBatch {
                        recentUndoCard
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyChatView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("무엇을 물어볼까요?")
                .font(.title2)
                .bold()

            Text("예시")
                .font(.headline)

            quickPromptButton("오늘 해야 할 일 뭐 있어?")
            quickPromptButton("아직 안 한 일 알려줘.")
            quickPromptButton("답변 필요한 일 있어?")
            quickPromptButton("확인해야 할 알림 있어?")
            quickPromptButton("최근 자동 반영 내역 보여줘.")
            quickPromptButton("내일로 넘긴 일 보여줘.")
            quickPromptButton("오늘 브리핑 요약해줘.")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func quickPromptButton(_ text: String) -> some View {
        Button {
            inputText = text
            Task {
                await sendMessage()
            }
        } label: {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(message.role == "user" ? "나" : "워키토키")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: 520, alignment: .leading)
            .background(message.role == "user" ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role != "user" {
                Spacer()
            }
        }
    }
    private var pendingChangePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                pendingChangeReply.isEmpty
                    ? "말씀하신 내용을 이렇게 이해했어요."
                    : pendingChangeReply
            )
                .font(.headline)
                .foregroundStyle(WokeyDesign.ink)

            ForEach(pendingTaskChanges) { change in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(change.task.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if change.interpretation.needsClarification {
                            Text(change.interpretation.clarificationQuestion ?? "대상 작업이나 상태를 다시 확인해주세요.")
                                .font(.caption)
                                .foregroundStyle(WokeyDesign.active)
                        }
                    }

                    Spacer()

                    if isEditingPendingChanges {
                        Picker(
                            "상태",
                            selection: Binding(
                                get: {
                                    pendingStatusOverrides[change.id] ?? change.interpretation.status
                                },
                                set: { newStatus in
                                    pendingStatusOverrides[change.id] = newStatus
                                }
                            )
                        ) {
                            Text(TaskStatus.completed.displayName).tag(TaskStatus.completed)
                            Text(TaskStatus.inProgress.displayName).tag(TaskStatus.inProgress)
                            Text(TaskStatus.pending.displayName).tag(TaskStatus.pending)
                            Text("내일로 넘김").tag(TaskStatus.deferred)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    } else {
                        Text(effectiveStatus(for: change).displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(WokeyDesign.statusFill)
                            .clipShape(Capsule())
                    }
                }
            }

            HStack {
                Button("이대로 반영") {
                    applyPendingInterpretations()
                }
                .disabled(
                    pendingTaskChanges.isEmpty ||
                    pendingTaskChanges.contains { $0.interpretation.needsClarification }
                )

                Button(isEditingPendingChanges ? "수정 완료" : "수정하기") {
                    isEditingPendingChanges.toggle()
                }

                Button("취소") {
                    pendingTaskChanges = []
                    pendingChangeReply = ""
                    isEditingPendingChanges = false
                    pendingStatusOverrides = [:]
                    showToast("변경 요청을 취소했습니다.")
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: 560, alignment: .leading)
        .background(WokeyDesign.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
    }

    private func clarificationCard(_ clarification: PendingChatClarification) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(clarification.question)
                .font(.headline)
                .foregroundStyle(WokeyDesign.ink)

            if clarification.type == .selectTask {
                ForEach(clarification.candidateTasks) { task in
                    Button {
                        handleClarificationTaskSelection(
                            task,
                            clarification: clarification
                        )
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                HStack(spacing: 8) {
                                    Text(TaskStatus(rawValue: task.status)?.displayName ?? task.status)

                                    if let dueAt = task.dueAt {
                                        Text(dueAt.formatted(date: .abbreviated, time: .shortened))
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(WokeyDesign.muted)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(WokeyDesign.muted)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WokeyDesign.quietFill)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if clarification.type == .selectStatus,
               let task = clarification.selectedTask ?? clarification.candidateTasks.first {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    clarificationStatusButton(
                        title: TaskStatus.completed.displayName,
                        status: .completed,
                        task: task
                    )

                    clarificationStatusButton(
                        title: TaskStatus.inProgress.displayName,
                        status: .inProgress,
                        task: task
                    )

                    clarificationStatusButton(
                        title: TaskStatus.pending.displayName,
                        status: .pending,
                        task: task
                    )

                    clarificationStatusButton(
                        title: "내일로 넘김",
                        status: .deferred,
                        task: task
                    )
                }
                .font(.caption)
            }

            HStack {
                Button("취소") {
                    pendingClarification = nil
                    showToast("확인 요청을 취소했습니다.")
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: 560, alignment: .leading)
        .background(WokeyDesign.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
    }

    private func clarificationStatusButton(
        title: String,
        status: TaskStatus,
        task: TaskItem
    ) -> some View {
        Button(title) {
            createPendingChange(
                task: task,
                status: status,
                responseText: pendingClarification?.originalText ?? ""
            )
        }
    }

    private func handleClarificationTaskSelection(
        _ task: TaskItem,
        clarification: PendingChatClarification
    ) {
        if let stableID = task.stableID {
            referencedTaskIDs = [stableID]
        }
        if let suggestedStatus = clarification.suggestedStatus {
            createPendingChange(
                task: task,
                status: suggestedStatus,
                responseText: clarification.originalText
            )
        } else {
            pendingClarification = PendingChatClarification(
                type: .selectStatus,
                question: "\(task.title)의 상태를 선택해주세요.",
                candidateTasks: [task],
                suggestedStatus: nil,
                selectedTask: task,
                originalText: clarification.originalText
            )
        }
    }

    private func createPendingChange(
        task: TaskItem,
        status: TaskStatus,
        responseText: String
    ) {
        if let stableID = task.stableID {
            referencedTaskIDs = [stableID]
        }
        let deferredTo = status == .deferred
            ? Calendar.current.date(byAdding: .day, value: 1, to: Date())
            : nil

        let interpretation = TaskResponseInterpretation(
            taskTitle: task.title,
            status: status,
            responseText: responseText,
            deferredTo: deferredTo,
            confidence: 1.0,
            needsClarification: false,
            clarificationQuestion: nil
        )

        pendingTaskChanges = [
            PendingChatTaskChange(
                task: task,
                interpretation: interpretation
            )
        ]
        pendingChangeReply = "선택한 내용을 이렇게 반영할게요."
        pendingClarification = nil
    }

    private func userStateChangeCard(
        _ pendingChange: PendingUserStateChange
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(pendingChange.message)
                .font(.headline)
                .foregroundStyle(WokeyDesign.ink)

            HStack(spacing: 8) {
                Text("현재")
                    .foregroundStyle(WokeyDesign.muted)

                Text(captureManager.userWorkState.displayName)
                    .fontWeight(.semibold)

                Image(systemName: "arrow.right")
                    .foregroundStyle(WokeyDesign.muted)

                Text(pendingChange.targetState.displayName)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            HStack {
                Button("전환하기") {
                    applyPendingUserStateChange(pendingChange)
                }

                Button("취소") {
                    pendingUserStateChange = nil
                    showToast("사용자 상태 변경을 취소했습니다.")
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: 560, alignment: .leading)
        .background(WokeyDesign.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
    }

    private func applyPendingUserStateChange(
        _ pendingChange: PendingUserStateChange
    ) {
        captureManager.setUserWorkState(
            pendingChange.targetState,
            modelContext: modelContext
        )

        pendingUserStateChange = nil

        insertAssistantMessage(
            "사용자 상태를 \(pendingChange.targetState.displayName)으로 변경했어요."
        )

        do {
            try modelContext.save()
            showToast("\(pendingChange.targetState.displayName)으로 전환했습니다.")
        } catch {
            errorMessage = "사용자 상태를 저장하지 못했어요: \(error.localizedDescription)"
        }
    }

    private var recentUndoCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("작업 상태를 반영했어요.")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("최근 변경 \(recentBatchLogs.count)개")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            Spacer()

            Button("되돌리기") {
                undoRecentChatChanges()
            }
        }
        .padding(14)
        .frame(maxWidth: 560, alignment: .leading)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recentBatchLogs: [TaskChangeLog] {
        guard let recentChangeBatchID else {
            return []
        }

        return taskChangeLogs
            .filter {
                $0.batchID == recentChangeBatchID &&
                !$0.isRolledBack
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var canUndoRecentBatch: Bool {
        guard recentChangeBatchID != nil,
              !recentBatchLogs.isEmpty,
              let recentRevertExpiresAt else {
            return false
        }

        return Date() < recentRevertExpiresAt
    }

    private var chatCandidateTasks: [TaskItem] {
        tasks
            .filter {
                (ScheduleType(rawValue: $0.scheduleType ?? "") ?? .task) == .task
            }
            .filter { task in
                if let dueAt = task.dueAt, dueAt < Date() {
                    return true
                }

                return !task.isCompleted || task.status != TaskStatus.completed.rawValue
            }
            .sorted { first, second in
                let firstOverdue = first.dueAt.map { $0 < Date() } ?? false
                let secondOverdue = second.dueAt.map { $0 < Date() } ?? false

                if firstOverdue != secondOverdue {
                    return firstOverdue && !secondOverdue
                }

                return (first.dueAt ?? .distantFuture) < (second.dueAt ?? .distantFuture)
            }
    }


    private var recentConversationContext: String {
        let conversationText = messages
            .suffix(8)
            .map { message in
                let speaker = message.role == "user" ? "사용자" : "워키토키"
                return "\(speaker): \(message.content)"
            }
            .joined(separator: "\n")

        let referencedTaskText = referencedTaskIDs.compactMap { identifier in
            guard let task = tasks.first(where: { $0.stableID == identifier }) else {
                return nil
            }

            return "- taskIdentifier: \(identifier.uuidString)\n  taskTitle: \(task.title)"
        }
        .joined(separator: "\n")

        return """
        [최근 대화]
        \(conversationText.isEmpty ? "없음" : conversationText)

        [최근 참조 작업]
        \(referencedTaskText.isEmpty ? "없음" : referencedTaskText)
        """
    }

    private func normalizedTaskText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }



    private func effectiveStatus(for change: PendingChatTaskChange) -> TaskStatus {
        pendingStatusOverrides[change.id] ?? change.interpretation.status
    }

    private func pendingChanges(
        from analysis: LLMChatAnalysisResult,
        originalText: String
    ) -> [PendingChatTaskChange] {
        analysis.taskChanges.compactMap { item in
            guard let taskIdentifierText = item.taskIdentifier?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                  let taskIdentifier = UUID(uuidString: taskIdentifierText),
                  let targetStatusRawValue = item.targetStatus,
                  let targetStatus = TaskStatus(rawValue: targetStatusRawValue),
                  let matchedTask = tasks.first(where: {
                      $0.stableID == taskIdentifier
                  }) else {
                return nil
            }

            let deferredTo = targetStatus == .deferred
                ? Calendar.current.date(byAdding: .day, value: 1, to: Date())
                : nil

            let interpretation = TaskResponseInterpretation(
                taskTitle: matchedTask.title,
                status: targetStatus,
                responseText: originalText,
                deferredTo: deferredTo,
                confidence: item.confidence ?? 0.5,
                needsClarification: false,
                clarificationQuestion: nil
            )

            return PendingChatTaskChange(
                task: matchedTask,
                interpretation: interpretation
            )
        }
    }

    private func makeClarification(
        from analysis: LLMChatAnalysisResult,
        originalText: String
    ) -> PendingChatClarification? {
        let question = analysis.clarificationQuestion?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        switch analysis.clarificationType {
        case "selectTask":
            var candidateTasks: [TaskItem] = []

            for identifierText in analysis.candidateTaskIdentifiers {
                let trimmedIdentifier = identifierText.trimmingCharacters(
                    in: CharacterSet.whitespacesAndNewlines
                )

                guard let identifier = UUID(uuidString: trimmedIdentifier),
                      let task = tasks.first(where: {
                          $0.stableID == identifier
                      }) else {
                    continue
                }

                candidateTasks.append(task)
            }

            guard !candidateTasks.isEmpty else {
                return nil
            }

            return PendingChatClarification(
                type: .selectTask,
                question: question?.isEmpty == false
                    ? question!
                    : "어떤 작업을 말씀하시는지 선택해주세요.",
                candidateTasks: candidateTasks,
                suggestedStatus: analysis.suggestedStatus.flatMap(
                    TaskStatus.init(rawValue:)
                ),
                selectedTask: nil,
                originalText: originalText
            )

        case "selectStatus":
            let identifierText = analysis.candidateTaskIdentifiers.first
                ?? analysis.taskChanges.first?.taskIdentifier

            guard let identifierText,
                  let identifier = UUID(
                    uuidString: identifierText.trimmingCharacters(
                        in: CharacterSet.whitespacesAndNewlines
                    )
                  ),
                  let task = tasks.first(where: {
                    $0.stableID == identifier
                  }) else {
                return nil
            }

            return PendingChatClarification(
                type: .selectStatus,
                question: question?.isEmpty == false
                    ? question!
                    : "이 작업의 상태를 선택해주세요.",
                candidateTasks: [task],
                suggestedStatus: nil,
                selectedTask: task,
                originalText: originalText
            )

        default:
            return nil
        }
    }

    private func makeUserStateChange(
        from analysis: LLMChatAnalysisResult
    ) -> PendingUserStateChange? {
        guard let rawValue = analysis.targetUserState,
              let targetState = UserWorkState(rawValue: rawValue) else {
            return nil
        }

        let trimmedReply = analysis.reply.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
        )

        return PendingUserStateChange(
            targetState: targetState,
            message: trimmedReply.isEmpty
                ? "\(targetState.displayName) 상태로 전환할까요?"
                : trimmedReply
        )
    }

    private func updateReferencedTasks(
        from analysis: LLMChatAnalysisResult
    ) {
        var identifiers: [UUID] = []

        for identifierText in analysis.referencedTaskIdentifiers {
            let trimmedIdentifier = identifierText.trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
            )

            guard let identifier = UUID(uuidString: trimmedIdentifier),
                  tasks.contains(where: { $0.stableID == identifier }) else {
                continue
            }

            if !identifiers.contains(identifier) {
                identifiers.append(identifier)
            }
        }

        if !identifiers.isEmpty {
            referencedTaskIDs = Array(identifiers.prefix(5))
        }
    }

    private func insertAssistantMessage(_ content: String) {
        let trimmedContent = content.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
        )

        guard !trimmedContent.isEmpty else {
            return
        }

        modelContext.insert(
            ChatMessage(
                role: "assistant",
                content: trimmedContent
            )
        )
    }



    private func applyPendingInterpretations() {
        guard !pendingTaskChanges.isEmpty else {
            errorMessage = "변경할 작업을 찾지 못했어요. 작업 이름을 조금 더 구체적으로 알려주세요."
            return
        }

        // removed recentUndoSnapshots

        let batchID = UUID()
        let revertExpiresAt = Calendar.current.date(
            byAdding: .minute,
            value: 10,
            to: Date()
        )

        recentChangeBatchID = batchID
        recentRevertExpiresAt = revertExpiresAt
        scheduleRecentUndoExpiration(
            batchID: batchID,
            expiresAt: revertExpiresAt
        )

        for change in pendingTaskChanges {
            let finalStatus = effectiveStatus(for: change)
            let deferredTo = finalStatus == .deferred
                ? Calendar.current.date(byAdding: .day, value: 1, to: Date())
                : nil

            let finalInterpretation = TaskResponseInterpretation(
                taskTitle: change.task.title,
                status: finalStatus,
                responseText: change.interpretation.responseText,
                deferredTo: deferredTo,
                confidence: change.interpretation.confidence,
                needsClarification: false,
                clarificationQuestion: nil
            )

            responseService.applyInterpretation(
                finalInterpretation,
                to: change.task,
                batchID: batchID,
                source: "chat",
                notifyUser: false,
                revertExpiresAt: revertExpiresAt,
                modelContext: modelContext
            )
        }

        let appliedCount = pendingTaskChanges.count
        pendingTaskChanges = []
        pendingChangeReply = ""
        isEditingPendingChanges = false
        pendingStatusOverrides = [:]

        do {
            try modelContext.save()

            let assistantMessage = ChatMessage(
                role: "assistant",
                content: "\(appliedCount)개 작업의 상태를 반영했어요."
            )
            modelContext.insert(assistantMessage)
            try modelContext.save()
        } catch {
            errorMessage = "작업 상태를 저장하지 못했어요: \(error.localizedDescription)"
        }
    }

    private func undoRecentChatChanges() {
        guard canUndoRecentBatch,
              let batchID = recentChangeBatchID else {
            recentChangeBatchID = nil
            recentRevertExpiresAt = nil
            showToast("되돌리기 가능한 시간이 지났습니다.")
            return
        }

        let logs = taskChangeLogs
            .filter {
                $0.batchID == batchID &&
                !$0.isRolledBack
            }
            .sorted { $0.createdAt > $1.createdAt }

        guard !logs.isEmpty else {
            recentChangeBatchID = nil
            recentRevertExpiresAt = nil
            showToast("되돌릴 변경 기록을 찾지 못했습니다.")
            return
        }

        let now = Date()
        var restoredCount = 0

        for log in logs {
            guard let taskIdentifier = log.taskIdentifier,
                  let task = tasks.first(where: { $0.stableID == taskIdentifier }) else {
                continue
            }

            if let previousTitle = log.previousTitle {
                task.title = previousTitle
            }

            if let previousStatus = log.previousStatus {
                task.status = previousStatus
            }

            task.isCompleted = log.previousIsCompleted
            task.completedAt = log.previousCompletedAt
            task.deferredTo = log.previousDeferredTo
            task.dueAt = log.previousDueAt
            task.needsUserConfirmation = log.previousStatus == TaskStatus.uncertain.rawValue

            log.isRolledBack = true
            log.rolledBackAt = now
            restoredCount += 1
        }

        do {
            try modelContext.save()

            recentChangeBatchID = nil
            recentRevertExpiresAt = nil

            insertAssistantMessage(
                restoredCount > 0
                    ? "최근 작업 상태 변경 \(restoredCount)개를 이전 상태로 되돌렸어요."
                    : "되돌릴 수 있는 작업을 찾지 못했어요."
            )
            try modelContext.save()

            showToast(
                restoredCount > 0
                    ? "최근 변경을 되돌렸습니다."
                    : "되돌릴 작업을 찾지 못했습니다."
            )
        } catch {
            errorMessage = "변경을 되돌리지 못했어요: \(error.localizedDescription)"
        }
    }

    private func scheduleRecentUndoExpiration(
        batchID: UUID,
        expiresAt: Date?
    ) {
        guard let expiresAt else {
            return
        }

        let delay = max(0, expiresAt.timeIntervalSinceNow)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard recentChangeBatchID == batchID else {
                return
            }

            recentChangeBatchID = nil
            recentRevertExpiresAt = nil
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSending {
                Text("답변 생성 중...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $inputText)
                    .frame(minHeight: 44, maxHeight: 90)
                    .padding(6)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("보내기") {
                    Task {
                        await sendMessage()
                    }
                }
                .disabled(
                    isSending ||
                    inputText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                )
                .keyboardShortcut(.return, modifiers: [.command])
            }

            Text("작업 상태 변경 요청은 내용을 확인한 뒤 반영할 수 있도록 안내합니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }



    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    @MainActor
    private func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return
        }

        guard let config = currentLLMConfig else {
            errorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        inputText = ""
        isSending = true
        errorMessage = nil
        pendingTaskChanges = []
        pendingChangeReply = ""
        isEditingPendingChanges = false
        pendingStatusOverrides = [:]
        pendingClarification = nil
        pendingUserStateChange = nil

        modelContext.insert(
            ChatMessage(
                role: "user",
                content: trimmed
            )
        )

        let context = contextBuilder.buildContext(
            tasks: tasks,
            activities: activities,
            briefings: briefings,
            userResponses: userResponses
        )

        do {
            let analysis = try await llmService.analyzeChatRequest(
                userMessage: trimmed,
                context: context,
                conversationContext: recentConversationContext,
                tasks: tasks,
                config: config
            )

            updateReferencedTasks(from: analysis)

            switch analysis.intent {
            case "taskStatusChange":
                if analysis.needsClarification || analysis.taskChanges.isEmpty {
                    if let clarification = makeClarification(
                        from: analysis,
                        originalText: trimmed
                    ) {
                        pendingClarification = clarification
                    } else {
                        let clarificationText = analysis.clarificationQuestion?
                            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                        insertAssistantMessage(
                            clarificationText?.isEmpty == false
                                ? clarificationText!
                                : analysis.reply
                        )
                    }
                } else {
                    let changes = pendingChanges(
                        from: analysis,
                        originalText: trimmed
                    )

                    guard changes.count == analysis.taskChanges.count,
                          !changes.isEmpty else {
                        insertAssistantMessage(
                            analysis.clarificationQuestion ??
                            "변경할 작업을 정확히 특정하지 못했어요. 어떤 작업인지 다시 알려주세요."
                        )
                        try modelContext.save()
                        isSending = false
                        return
                    }

                    pendingTaskChanges = changes
                    pendingChangeReply = analysis.reply
                }

            case "userStateChange":
                if analysis.needsClarification {
                    insertAssistantMessage(
                        analysis.clarificationQuestion ?? analysis.reply
                    )
                } else if let pendingChange = makeUserStateChange(from: analysis) {
                    pendingUserStateChange = pendingChange
                } else {
                    insertAssistantMessage(
                        analysis.reply.isEmpty
                            ? "작업 중, 쉬는 중, 자리 비움 중 어떤 상태로 바꿀지 알려주세요."
                            : analysis.reply
                    )
                }

            case "taskQuery",
                 "briefingRequest",
                 "projectManagement",
                 "settingsOrPrivacy",
                 "outOfScope":
                insertAssistantMessage(analysis.reply)

            default:
                insertAssistantMessage(
                    analysis.reply.isEmpty
                        ? "요청을 이해하지 못했어요. 작업 관리와 관련해 다시 말해주세요."
                        : analysis.reply
                )
            }

            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }


    private func deleteAllMessages() {
        for message in messages {
            modelContext.delete(message)
        }
        referencedTaskIDs = []
        pendingTaskChanges = []
        pendingChangeReply = ""
        pendingClarification = nil
        pendingUserStateChange = nil
        pendingStatusOverrides = [:]
        isEditingPendingChanges = false
        showToast("대화 기록을 삭제했습니다.")
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

private struct PendingUserStateChange {
    let targetState: UserWorkState
    let message: String
}

private enum PendingChatClarificationType {
    case selectTask
    case selectStatus
}

private struct PendingChatClarification {
    let type: PendingChatClarificationType
    let question: String
    let candidateTasks: [TaskItem]
    let suggestedStatus: TaskStatus?
    let selectedTask: TaskItem?
    let originalText: String
}

private struct PendingChatTaskChange: Identifiable {
    let id = UUID()
    let task: TaskItem
    let interpretation: TaskResponseInterpretation
}

