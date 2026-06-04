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

    @Query private var llmConfigs: [LLMConfig]

    @Query(sort: \AppNotification.createdAt, order: .reverse)
    private var appNotifications: [AppNotification]

    @Query(sort: \TaskChangeLog.createdAt, order: .reverse)
    private var taskChangeLogs: [TaskChangeLog]

    private let contextBuilder = ChatContextBuilder()
    private let llmService = LLMService()

    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showDeleteMessagesConfirmation = false
    @State private var toastMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            if !pendingNotifications.isEmpty || !rollbackableLogs.isEmpty {
                notificationReviewSection
                Divider()
            }

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

                Text("오늘 할 일, 알림, 되돌리기, 브리핑에 대해 물어볼 수 있습니다.")
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
                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .keyboardShortcut(.return, modifiers: [.command])
            }

            Text("이 채팅은 조회와 설명 중심입니다. 자동 반영/후보/되돌리기는 위 알림 카드의 버튼으로 처리합니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }


    private var pendingNotifications: [AppNotification] {
        appNotifications.filter { !$0.isResolved }
    }

    private var rollbackableLogs: [TaskChangeLog] {
        taskChangeLogs.filter { !$0.isRolledBack }.prefix(5).map { $0 }
    }

    private var notificationReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("확인할 알림")
                        .font(.headline)
                    Text("AI 판단, 자동 반영, 카카오톡/메모 후보를 여기서 빠르게 확인합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if !pendingNotifications.isEmpty {
                ForEach(pendingNotifications.prefix(5)) { notification in
                    notificationCard(notification)
                }
            }

            if !rollbackableLogs.isEmpty {
                Text("최근 변경 되돌리기")
                    .font(.caption)
                    .bold()

                ForEach(rollbackableLogs) { log in
                    rollbackCard(log)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func notificationCard(_ notification: AppNotification) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(notification.title)
                    .font(.subheadline)
                    .bold()

                Spacer()

                Text(notification.source)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Text(notification.message)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if notification.kind == "taskChange",
                   let title = notification.relatedTaskTitle,
                   let log = latestRollbackableLog(for: title) {
                    Button("되돌리기") {
                        rollback(log)
                        notification.isResolved = true
                        notification.resolvedAt = Date()
                    }
                }

                Button("확인") {
                    notification.isResolved = true
                    notification.resolvedAt = Date()
                    showToast("알림을 확인 처리했습니다.")
                }

                Spacer()
            }
            .font(.caption)
        }
        .padding(10)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func rollbackCard(_ log: TaskChangeLog) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.taskTitle)
                    .font(.caption)
                    .bold()
                Text("\(log.previousStatus ?? "생성 전") → \(log.newStatus ?? "변경됨") · \(log.source)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("되돌리기") {
                rollback(log)
            }
            .font(.caption)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func latestRollbackableLog(for taskTitle: String) -> TaskChangeLog? {
        taskChangeLogs.first { log in
            !log.isRolledBack &&
            (log.taskTitle == taskTitle || log.newTitle == taskTitle || log.previousTitle == taskTitle)
        }
    }

    private func rollback(_ log: TaskChangeLog) {
        guard !log.isRolledBack else {
            return
        }

        if log.changeType == "taskCreated" {
            if let task = tasks.first(where: { $0.title == log.taskTitle || $0.title == log.newTitle }) {
                modelContext.delete(task)
            }
            log.isRolledBack = true
            log.rolledBackAt = Date()
            showToast("생성된 Task를 되돌렸습니다.")
            return
        }

        guard let task = tasks.first(where: { $0.title == log.taskTitle || $0.title == log.newTitle || $0.title == log.previousTitle }) else {
            return
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
        log.rolledBackAt = Date()

        let notification = AppNotification(
            title: "변경을 되돌렸습니다",
            message: "\(task.title)의 상태를 이전 값으로 복구했습니다.",
            kind: "rollback",
            source: "chat",
            relatedTaskTitle: task.title,
            isResolved: true,
            resolvedAt: Date()
        )
        modelContext.insert(notification)
        showToast("변경을 되돌렸습니다.")
    }

    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    @MainActor
    private func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

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

        let userMessage = ChatMessage(
            role: "user",
            content: trimmed
        )
        modelContext.insert(userMessage)

        let baseContext = contextBuilder.buildContext(
            tasks: tasks,
            activities: activities,
            briefings: briefings,
            userResponses: userResponses
        )

        let context = baseContext + "\n\n" + buildNotificationContext()

        do {
            let response = try await llmService.sendChatMessage(
                userMessage: trimmed,
                context: context,
                config: config
            )

            let assistantMessage = ChatMessage(
                role: "assistant",
                content: response
            )

            modelContext.insert(assistantMessage)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    private func buildNotificationContext() -> String {
        let notificationLines = pendingNotifications.prefix(10).map { notification in
            "- [\(notification.kind)] \(notification.title): \(notification.message)"
        }.joined(separator: "\n")

        let rollbackLines = rollbackableLogs.map { log in
            "- \(log.taskTitle): \(log.previousStatus ?? "생성 전") → \(log.newStatus ?? "변경됨"), source=\(log.source)"
        }.joined(separator: "\n")

        return """
        [앱 알림/검토 항목]
        \(notificationLines.isEmpty ? "없음" : notificationLines)

        [최근 되돌리기 가능 변경]
        \(rollbackLines.isEmpty ? "없음" : rollbackLines)
        """
    }

    private func deleteAllMessages() {
        for message in messages {
            modelContext.delete(message)
        }
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
