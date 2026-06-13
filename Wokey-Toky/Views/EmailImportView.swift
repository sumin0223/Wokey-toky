//
//  EmailImportView.swift
//  Wokey-Toky
//

import SwiftUI
import SwiftData
import AppKit
import Network

struct EmailImportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskCandidate.createdAt, order: .reverse)
    private var candidates: [TaskCandidate]

    @Query private var llmConfigs: [LLMConfig]

    @State private var selectedProvider: EmailProvider = .naverMail
    @State private var senderInput = ""
    @State private var senderFilters: [String] = []
    @State private var daysBack = 14.0
    @State private var maxMessages = 25.0
    @State private var accountEmail = ""
    @State private var accountPassword = ""
    @State private var importedMessages: [EmailMessagePreview] = []
    @State private var selectedMessageIDs: Set<String> = []
    @State private var isFetchingMail = false
    @State private var isExtracting = false
    @State private var hasImportedMail = false
    @State private var lastSyncedAt: Date?
    @State private var errorMessage: String?
    @State private var toastMessage: String?
    @State private var editingCandidate: TaskCandidate?
    @State private var editingCandidateTitle = ""
    @State private var editingCandidateDetail = ""
    @State private var editingCandidateDueText = ""

    private let llmService = LLMService()
    private let imapService = IMAPEmailService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
                providerSection
                scopeSection
                providerImportSection
                candidateSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                InAppToastView(message: toastMessage)
            }
        }
        .overlay {
            if let candidate = editingCandidate {
                ZStack {
                    Button {
                        editingCandidate = nil
                    } label: {
                        Rectangle()
                            .fill(Color.black.opacity(0.18))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    candidateEditSheet(candidate)
                        .frame(width: 520)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                .zIndex(20)
            }
        }
        .onChange(of: selectedProvider) { _, _ in
            selectedMessageIDs.removeAll()
            importedMessages.removeAll()
            hasImportedMail = false
            lastSyncedAt = nil
            errorMessage = nil
        }
    }W

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Import Email")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Text("메일함을 한 번 가져온 뒤, 확인할 발신자만 필터링해 Task 후보를 추출합니다.")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            HStack(spacing: 14) {
                ForEach(EmailProvider.allCases) { provider in
                    providerButton(provider)
                }
            }
        }
        .wokeyPanel()
    }

    private func providerButton(_ provider: EmailProvider) -> some View {
        Button {
            selectedProvider = provider
        } label: {
            HStack(spacing: 14) {
                providerBadge(provider)

                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.title)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)

                    Text(provider.subtitle)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: selectedProvider == provider ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedProvider == provider ? WokeyDesign.blue : WokeyDesign.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(selectedProvider == provider ? WokeyDesign.selection : WokeyDesign.quietFill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selectedProvider == provider ? WokeyDesign.blue.opacity(0.22) : WokeyDesign.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func providerBadge(_ provider: EmailProvider) -> some View {
        switch provider {
        case .naverMail:
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.02, green: 0.78, blue: 0.34))
                Text("N")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)
        case .gmail:
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                Text("G")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .red, .yellow, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 50, height: 50)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WokeyDesign.hairline, lineWidth: 1)
            }
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("가져올 메일 범위")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text("\(importedMessages.count)개 메일 보관 중")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(WokeyDesign.statusFill)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 10) {
                if !senderFilters.isEmpty {
                    FlowLayout(spacing: 8, rowSpacing: 8) {
                        ForEach(senderFilters, id: \.self) { filter in
                            HStack(spacing: 6) {
                                Text(filter)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(WokeyDesign.ink)

                                Button {
                                    removeSenderFilter(filter)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(WokeyDesign.muted)
                                }
                                .buttonStyle(.plain)
                                .help("삭제")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(WokeyDesign.statusFill)
                            .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("메일 또는 도메인 입력 후 Enter", text: $senderInput)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            addSenderFilter()
                        }

                    Button {
                        addSenderFilter()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .background(WokeyDesign.selection)
                    .clipShape(Circle())
                    .disabled(senderInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("발신자 추가")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(WokeyDesign.hairline, lineWidth: 1)
                }
            }
            .padding(12)
            .background(WokeyDesign.quietFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("최근 \(Int(daysBack))일")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                    Slider(value: $daysBack, in: 1...60, step: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("최대 \(Int(maxMessages))개")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                    Slider(value: $maxMessages, in: 5...80, step: 5)
                }
            }

            HStack {
                Text(selectedProvider.scopeHelp)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                Spacer()

                if let lastSyncedAt {
                    Text("마지막 동기화 \(lastSyncedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }
        }
        .wokeyPanel()
    }

    @ViewBuilder
    private var providerImportSection: some View {
        switch selectedProvider {
        case .naverMail:
            naverSection
        case .gmail:
            gmailSection
        }
    }

    private var naverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Naver Mail",
                subtitle: "네이버 메일을 가져온 뒤 확인할 발신자만 골라 할 일을 추출합니다."
            )

            accountSection

            HStack {
                Button("Naver Mail 로그인 열기") {
                    if let url = URL(string: "https://mail.naver.com/") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button(isFetchingMail ? "동기화 중..." : syncButtonTitle) {
                    Task {
                        await fetchMail()
                    }
                }
                .disabled(isFetchingMail)

                Button(isExtracting ? "추출 중..." : "할 일 추출하기") {
                    Task {
                        await extractCandidates(from: extractionMessages)
                    }
                }
                .disabled(isExtracting || extractionMessages.isEmpty)

                Spacer()
            }
            .font(.caption)

            messageList(messages: visibleMessages)
        }
        .wokeyPanel()
    }

    private var gmailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Gmail",
                subtitle: "Gmail 메일을 가져온 뒤 확인할 발신자만 골라 할 일을 추출합니다."
            )

            accountSection

            HStack {
                Button("Gmail 로그인 열기") {
                    if let url = URL(string: "https://mail.google.com/") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button(isFetchingMail ? "동기화 중..." : syncButtonTitle) {
                    Task {
                        await fetchMail()
                    }
                }
                .disabled(isFetchingMail)

                Button(isExtracting ? "추출 중..." : "할 일 추출하기") {
                    Task {
                        await extractCandidates(from: extractionMessages)
                    }
                }
                .disabled(isExtracting || extractionMessages.isEmpty)

                Spacer()
            }
            .font(.caption)

            messageList(messages: visibleMessages)
        }
        .wokeyPanel()
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                TextField("\(selectedProvider.title) 이메일 주소", text: $accountEmail)
                    .textFieldStyle(.roundedBorder)

                SecureField("IMAP 비밀번호 또는 앱 비밀번호", text: $accountPassword)
                    .textFieldStyle(.roundedBorder)
            }

            Text(selectedProvider.accountHelp)
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
        }
    }

    private func messageList(messages: [EmailMessagePreview]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if messages.isEmpty {
                ContentUnavailableView(
                    selectedProvider.emptyTitle,
                    systemImage: "envelope.open",
                    description: Text(selectedProvider.emptyDescription)
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                HStack {
                    Text("\(messages.count)개 메일")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)

                    Spacer()

                    Button(selectedMessageIDs.count == messages.count ? "선택 해제" : "전체 선택") {
                        if selectedMessageIDs.count == messages.count {
                            selectedMessageIDs.removeAll()
                        } else {
                            selectedMessageIDs = Set(messages.map(\.id))
                        }
                    }
                    .font(.caption)
                }

                ForEach(messages) { message in
                    emailMessageRow(message)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.active)
                    .textSelection(.enabled)
            }
        }
    }

    private func emailMessageRow(_ message: EmailMessagePreview) -> some View {
        Button {
            if selectedMessageIDs.contains(message.id) {
                selectedMessageIDs.remove(message.id)
            } else {
                selectedMessageIDs.insert(message.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedMessageIDs.contains(message.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selectedMessageIDs.contains(message.id) ? WokeyDesign.blue : WokeyDesign.muted)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(message.subject.isEmpty ? "(제목 없음)" : message.subject)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(WokeyDesign.ink)
                            .lineLimit(1)

                        Spacer()

                        Text(message.receivedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(WokeyDesign.muted)
                    }

                    Text(message.sender)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                        .lineLimit(1)

                    if !senderFilters.map({ $0.lowercased() }).contains(message.sender.lowercased()) {
                        Button("이 발신자 확인") {
                            senderFilters.append(message.sender)
                        }
                        .font(.caption2)
                    }

                    Text(message.body)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .background(WokeyDesign.quietFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WokeyDesign.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("추출된 이메일 할 일 후보")
                .font(.title3)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            let emailCandidates = candidates.filter {
                ["naverMail", "gmail"].contains($0.sourceType)
            }

            if emailCandidates.isEmpty {
                Text("아직 이메일에서 추출한 후보가 없습니다.")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                ForEach(emailCandidates.prefix(8)) { candidate in
                    candidateCard(candidate)
                }
            }
        }
        .wokeyPanel()
    }

    private func candidateCard(_ candidate: TaskCandidate) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(sourceLabel(for: candidate.sourceType))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WokeyDesign.statusFill)
                    .clipShape(Capsule())

                Spacer()

                Text("신뢰도 \(candidate.confidence, specifier: "%.2f")")
                    .font(.caption2)
                    .foregroundStyle(WokeyDesign.muted)
            }

            Text(candidate.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(WokeyDesign.ink)

            if let detail = candidate.detail,
               !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .lineLimit(2)
            }

            if let dueText = candidate.dueText,
               !dueText.isEmpty {
                Text("추정 시간/마감: \(dueText)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            HStack {
                Button("수정하기") {
                    startEditingCandidate(candidate)
                }

                Button(candidate.isImported ? "추가됨" : "할 일 추가하기") {
                    importCandidateAsTask(candidate)
                }
                .disabled(candidate.isImported)

                Button("삭제") {
                    modelContext.delete(candidate)
                    try? modelContext.save()
                    showToast("후보를 삭제했습니다.")
                }

                Spacer()
            }
            .font(.caption)
        }
        .padding(14)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
    }

    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private var syncButtonTitle: String {
        hasImportedMail ? "새 메일 동기화" : "메일 가져오기"
    }

    private var allowedSenderFilters: [String] {
        senderFilters.map { $0.lowercased() }
    }

    private var selectedMessages: [EmailMessagePreview] {
        visibleMessages.filter { selectedMessageIDs.contains($0.id) }
    }

    private var visibleMessages: [EmailMessagePreview] {
        guard !allowedSenderFilters.isEmpty else {
            return importedMessages
        }

        return importedMessages.filter { message in
            let sender = message.sender.lowercased()
            return allowedSenderFilters.contains { sender.contains($0) }
        }
    }

    private func addSenderFilter() {
        let trimmed = senderInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let normalized = trimmed.lowercased()
        if !senderFilters.map({ $0.lowercased() }).contains(normalized) {
            senderFilters.append(trimmed)
        }

        senderInput = ""
    }

    private func removeSenderFilter(_ filter: String) {
        senderFilters.removeAll { $0 == filter }
    }

    private var extractionMessages: [EmailMessagePreview] {
        let selected = selectedMessages
        if !selected.isEmpty {
            return selected
        }

        return visibleMessages
    }

    private func fetchMail() async {
        let email = accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty,
              !accountPassword.isEmpty else {
            errorMessage = "\(selectedProvider.title) 이메일 주소와 IMAP 비밀번호를 입력해주세요."
            return
        }

        isFetchingMail = true
        errorMessage = nil

        do {
            let messages = try await imapService.fetchRecentMessages(
                provider: selectedProvider,
                username: email,
                password: accountPassword,
                daysBack: Int(daysBack),
                maxMessages: Int(maxMessages)
            )
            let existingIDs = Set(importedMessages.map(\.id))
            let newMessages = messages.filter { !existingIDs.contains($0.id) }
            importedMessages = (newMessages + importedMessages)
                .sorted { $0.receivedAt > $1.receivedAt }
                .prefix(Int(maxMessages))
                .map { $0 }
            selectedMessageIDs = Set(visibleMessages.map(\.id))
            hasImportedMail = true
            lastSyncedAt = Date()
            showToast(newMessages.isEmpty ? "새 메일이 없습니다." : "\(newMessages.count)개의 새 메일을 추가했습니다.")
        } catch {
            selectedMessageIDs.removeAll()
            errorMessage = error.localizedDescription
        }

        isFetchingMail = false
    }

    private func extractCandidates(from messages: [EmailMessagePreview]) async {
        guard let config = currentLLMConfig else {
            errorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        let sourceText = messages.map(\.llmSourceText).joined(separator: "\n\n---\n\n")
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "분석할 메일 내용이 없습니다."
            return
        }

        isExtracting = true
        errorMessage = nil

        let sourceImport = SourceImport(
            sourceType: selectedProvider.sourceType,
            title: "\(selectedProvider.title) selected email",
            rawText: sourceText
        )
        modelContext.insert(sourceImport)

        do {
            let extracted = try await llmService.extractTaskCandidates(
                sourceText: sourceText,
                sourceType: selectedProvider.sourceType,
                config: config
            )

            if extracted.isEmpty {
                errorMessage = "추출된 할 일 후보가 없습니다."
                showToast("추출된 후보가 없습니다.")
            } else {
                for item in extracted {
                    let candidate = TaskCandidate(
                        title: item.title,
                        detail: item.detail,
                        sourceType: selectedProvider.sourceType,
                        sourceText: sourceText,
                        suggestedDueAt: nil,
                        dueText: item.dueText,
                        confidence: item.confidence ?? 0.5
                    )
                    modelContext.insert(candidate)
                }

                try? modelContext.save()
                showToast("\(extracted.count)개의 이메일 후보를 추출했습니다.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isExtracting = false
    }

    private func startEditingCandidate(_ candidate: TaskCandidate) {
        editingCandidate = candidate
        editingCandidateTitle = candidate.title
        editingCandidateDetail = candidate.detail ?? ""
        editingCandidateDueText = candidate.dueText ?? ""
    }

    private func candidateEditSheet(_ candidate: TaskCandidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("할 일 후보 수정")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Button {
                    editingCandidate = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WokeyDesign.ink)
                        .frame(width: 28, height: 28)
                        .background(WokeyDesign.quietFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("닫기")
            }

            TextField("제목", text: $editingCandidateTitle)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("상세 설명")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                TextEditor(text: $editingCandidateDetail)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(WokeyDesign.quietFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            TextField("추정 시간/마감", text: $editingCandidateDueText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("저장") {
                    candidate.title = editingCandidateTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    candidate.detail = editingCandidateDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingCandidateDetail
                    candidate.dueText = editingCandidateDueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingCandidateDueText
                    try? modelContext.save()
                    editingCandidate = nil
                    showToast("후보를 수정했습니다.")
                }
                .disabled(editingCandidateTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("취소") {
                    editingCandidate = nil
                }

                Spacer()
            }
        }
        .padding(22)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 16)
    }

    private func importCandidateAsTask(_ candidate: TaskCandidate) {
        var detailParts: [String] = []

        if let detail = candidate.detail,
           !detail.isEmpty {
            detailParts.append(detail)
        }

        if let dueText = candidate.dueText,
           !dueText.isEmpty {
            detailParts.append("추정 시간/마감: \(dueText)")
        }

        detailParts.append("원본 출처: \(sourceLabel(for: candidate.sourceType))")

        let task = TaskItem(
            title: candidate.title,
            detail: detailParts.joined(separator: "\n"),
            source: candidate.sourceType,
            status: TaskStatus.pending.rawValue,
            dueAt: candidate.suggestedDueAt,
            relatedKeywords: candidate.title
        )
        task.scheduleType = ScheduleType.task.rawValue

        modelContext.insert(task)
        candidate.isImported = true

        let log = TaskChangeLog(
            taskTitle: task.title,
            changeType: "taskCreated",
            previousStatus: nil,
            newStatus: task.status,
            previousIsCompleted: false,
            newIsCompleted: task.isCompleted,
            previousDueAt: nil,
            newDueAt: task.dueAt,
            previousTitle: nil,
            newTitle: task.title,
            reason: "이메일 후보를 Task로 가져왔습니다.",
            source: candidate.sourceType,
            confidence: candidate.confidence
        )
        modelContext.insert(log)

        let notification = AppNotification(
            title: "새 Task가 추가되었습니다",
            message: "\(task.title) · 출처: \(sourceLabel(for: candidate.sourceType))",
            kind: "taskCandidate",
            source: candidate.sourceType,
            relatedTaskTitle: task.title,
            confidence: candidate.confidence
        )
        modelContext.insert(notification)

        try? modelContext.save()
        showToast("할 일로 추가했습니다: \(task.title)")
    }

    private func sourceLabel(for source: String) -> String {
        switch source {
        case "naverMail":
            return "Naver Mail"
        case "gmail":
            return "Gmail"
        default:
            return source
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}

private enum EmailProvider: String, CaseIterable, Identifiable {
    case naverMail
    case gmail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .naverMail:
            return "Naver Mail"
        case .gmail:
            return "Gmail"
        }
    }

    var subtitle: String {
        switch self {
        case .naverMail:
            return "IMAP으로 받은메일 가져오기"
        case .gmail:
            return "IMAP 또는 앱 비밀번호로 가져오기"
        }
    }

    var imapHost: String {
        switch self {
        case .naverMail:
            return "imap.naver.com"
        case .gmail:
            return "imap.gmail.com"
        }
    }

    var imapPort: UInt16 {
        993
    }

    var accountHelp: String {
        switch self {
        case .naverMail:
            return "네이버 메일 설정에서 IMAP/SMTP 사용을 켠 뒤, 네이버 이메일 주소와 비밀번호를 입력해주세요. 2단계 인증 사용 시 앱 비밀번호가 필요할 수 있습니다."
        case .gmail:
            return "Gmail은 계정 보안 정책상 일반 비밀번호 대신 앱 비밀번호 또는 OAuth 연결이 필요할 수 있습니다."
        }
    }

    var sourceType: String {
        switch self {
        case .naverMail:
            return "naverMail"
        case .gmail:
            return "gmail"
        }
    }

    var scopeHelp: String {
        switch self {
        case .naverMail:
            return "한 번 가져온 메일 목록은 유지됩니다. 이후 새 메일 동기화만 하고, 태그를 바꾸면 즉시 목록이 필터링됩니다."
        case .gmail:
            return "한 번 가져온 메일 목록은 유지됩니다. 이후 새 메일 동기화만 하고, 태그를 바꾸면 즉시 목록이 필터링됩니다."
        }
    }

    var emptyTitle: String {
        switch self {
        case .naverMail:
            return "가져온 Naver Mail 메일이 없습니다"
        case .gmail:
            return "가져온 Gmail 메일이 없습니다"
        }
    }

    var emptyDescription: String {
        switch self {
        case .naverMail:
            return "메일 가져오기를 실행하면 확인할 메일 목록이 여기에 표시됩니다."
        case .gmail:
            return "메일 가져오기를 실행하면 확인할 메일 목록이 여기에 표시됩니다."
        }
    }
}

private struct EmailMessagePreview: Identifiable, Hashable {
    let id: String
    let provider: EmailProvider
    let sender: String
    let subject: String
    let receivedAt: Date
    let body: String

    var llmSourceText: String {
        """
        Provider: \(provider.title)
        From: \(sender)
        Subject: \(subject)
        Received: \(receivedAt.formatted(date: .abbreviated, time: .shortened))

        \(body)
        """
    }
}

private final class IMAPEmailService {
    func fetchRecentMessages(
        provider: EmailProvider,
        username: String,
        password: String,
        daysBack: Int,
        maxMessages: Int
    ) async throws -> [EmailMessagePreview] {
        let client = IMAPClient(host: provider.imapHost, port: provider.imapPort)
        try await client.connect()

        defer {
            client.cancel()
        }

        _ = try await client.readUntilGreeting()
        _ = try await client.sendCommand(
            "LOGIN \(quote(username)) \(quote(password))",
            failureHint: "\(provider.title) 로그인에 실패했습니다. IMAP 사용 설정, 이메일 주소, 앱 비밀번호를 확인해주세요."
        )
        _ = try await client.sendCommand(
            "SELECT INBOX",
            failureHint: "받은메일함을 열지 못했습니다. IMAP 권한 또는 메일함 이름을 확인해주세요."
        )

        let sinceDate = imapDate(daysBack: daysBack)
        let searchResponse = try await client.sendCommand(
            "SEARCH SINCE \(sinceDate)",
            failureHint: "메일 검색에 실패했습니다."
        )
        let ids = parseSearchIDs(searchResponse).suffix(maxMessages)

        var messages: [EmailMessagePreview] = []
        for id in ids.reversed() {
            let response = try await client.sendCommand(
                "FETCH \(id) BODY.PEEK[]",
                failureHint: "메일 내용을 가져오지 못했습니다."
            )
            if let message = parseMessage(response, provider: provider, id: id) {
                messages.append(message)
            }
        }

        _ = try? await client.sendCommand("LOGOUT")
        return messages
    }

    private func quote(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func imapDate(daysBack: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter.string(from: date)
    }

    private func parseSearchIDs(_ response: String) -> [String] {
        response
            .components(separatedBy: .newlines)
            .first(where: { $0.uppercased().hasPrefix("* SEARCH") })?
            .components(separatedBy: .whitespaces)
            .dropFirst(2)
            .filter { !$0.isEmpty } ?? []
    }

    private func parseMessage(_ response: String, provider: EmailProvider, id: String) -> EmailMessagePreview? {
        let normalized = response.replacingOccurrences(of: "\r\n", with: "\n")
        let sender = headerValue("From", in: normalized) ?? "(알 수 없는 발신자)"
        let subject = decodedHeader(headerValue("Subject", in: normalized) ?? "(제목 없음)")
        let date = parseDate(headerValue("Date", in: normalized)) ?? Date()
        let body = messageBody(from: normalized)

        return EmailMessagePreview(
            id: "\(provider.sourceType)-\(id)",
            provider: provider,
            sender: decodedHeader(sender),
            subject: subject,
            receivedAt: date,
            body: body
        )
    }

    private func headerValue(_ name: String, in text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        var value: String?
        var isCollecting = false

        for line in lines {
            if line.lowercased().hasPrefix("\(name.lowercased()):") {
                value = String(line.dropFirst(name.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                isCollecting = true
                continue
            }

            if isCollecting,
               line.first == " " || line.first == "\t" {
                value = [value, line.trimmingCharacters(in: .whitespacesAndNewlines)]
                    .compactMap { $0 }
                    .joined(separator: " ")
            } else if isCollecting {
                break
            }
        }

        return value
    }

    private func decodedHeader(_ text: String) -> String {
        let compacted = text.replacingOccurrences(
            of: #"\?=\s+=\?"#,
            with: "?==?",
            options: .regularExpression
        )
        let nsText = compacted as NSString
        let pattern = #"=\?([^?]+)\?([bBqQ])\?([^?]*)\?="#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return compacted
        }

        let matches = regex.matches(
            in: compacted,
            range: NSRange(location: 0, length: nsText.length)
        )
        guard !matches.isEmpty else {
            return compacted
        }

        var decoded = ""
        var lastIndex = 0

        for match in matches {
            if match.range.location > lastIndex {
                decoded += nsText.substring(
                    with: NSRange(location: lastIndex, length: match.range.location - lastIndex)
                )
            }

            let charset = nsText.substring(with: match.range(at: 1))
            let encoding = nsText.substring(with: match.range(at: 2)).lowercased()
            let payload = nsText.substring(with: match.range(at: 3))
            let data = encoding == "b"
                ? Data(base64Encoded: payload)
                : decodeQuotedPrintable(payload.replacingOccurrences(of: "_", with: " "))

            if let data,
               let text = string(from: data, charset: charset) {
                decoded += text
            } else {
                decoded += nsText.substring(with: match.range)
            }

            lastIndex = match.range.location + match.range.length
        }

        if lastIndex < nsText.length {
            decoded += nsText.substring(
                with: NSRange(location: lastIndex, length: nsText.length - lastIndex)
            )
        }

        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDate(_ text: String?) -> Date? {
        guard let text else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in ["EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return nil
    }

    private func messageBody(from text: String) -> String {
        let contentType = headerValue("Content-Type", in: text) ?? "text/plain"
        let body = splitHeaderAndBody(text).body

        if let boundary = parameterValue("boundary", in: contentType) {
            let parts = body.components(separatedBy: "--\(boundary)")
            let decodedParts = parts.compactMap { decodedBodyPart($0) }

            if let plain = decodedParts.first(where: { $0.type == .plain }) {
                return trimmedBody(plain.text)
            }

            if let html = decodedParts.first(where: { $0.type == .html }) {
                return trimmedBody(htmlToText(html.text))
            }
        }

        let transferEncoding = headerValue("Content-Transfer-Encoding", in: text)
        let charset = parameterValue("charset", in: contentType)
        let decoded = decodeBody(body, transferEncoding: transferEncoding, charset: charset)

        if contentType.lowercased().contains("text/html") {
            return trimmedBody(htmlToText(decoded))
        }

        return trimmedBody(decoded)
    }

    private enum MailBodyType {
        case plain
        case html
    }

    private func decodedBodyPart(_ part: String) -> (type: MailBodyType, text: String)? {
        let normalized = part.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              !normalized.hasPrefix("--") else {
            return nil
        }

        let contentType = headerValue("Content-Type", in: normalized) ?? "text/plain"
        let lowercasedType = contentType.lowercased()
        guard lowercasedType.contains("text/plain") || lowercasedType.contains("text/html") else {
            return nil
        }

        let transferEncoding = headerValue("Content-Transfer-Encoding", in: normalized)
        let charset = parameterValue("charset", in: contentType)
        let body = splitHeaderAndBody(normalized).body
        let decoded = decodeBody(body, transferEncoding: transferEncoding, charset: charset)
        let type: MailBodyType = lowercasedType.contains("text/html") ? .html : .plain
        return (type, decoded)
    }

    private func splitHeaderAndBody(_ text: String) -> (headers: String, body: String) {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        guard let range = normalized.range(of: "\n\n") else {
            return ("", normalized)
        }

        return (
            String(normalized[..<range.lowerBound]),
            String(normalized[range.upperBound...])
        )
    }

    private func parameterValue(_ name: String, in header: String) -> String? {
        let pattern = "\(name)=\"?([^\";]+)\"?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsHeader = header as NSString
        guard let match = regex.firstMatch(
            in: header,
            range: NSRange(location: 0, length: nsHeader.length)
        ) else {
            return nil
        }

        return nsHeader.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeBody(_ body: String, transferEncoding: String?, charset: String?) -> String {
        let cleanBody = body
            .components(separatedBy: .newlines)
            .filter {
                !$0.hasPrefix(")") &&
                $0.range(of: #"^A\d{3} OK"#, options: .regularExpression) == nil
            }
            .joined(separator: "\n")

        let lowercasedEncoding = transferEncoding?.lowercased() ?? ""
        let data: Data?

        if lowercasedEncoding.contains("base64") {
            let compact = cleanBody
                .components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .joined()
            data = Data(base64Encoded: compact)
        } else if lowercasedEncoding.contains("quoted-printable") {
            data = decodeQuotedPrintable(cleanBody)
        } else {
            data = cleanBody.data(using: String.Encoding.utf8)
        }

        guard let data else {
            return cleanBody
        }

        return string(from: data, charset: charset) ?? String(data: data, encoding: .utf8) ?? cleanBody
    }

    private func decodeQuotedPrintable(_ text: String) -> Data {
        let normalized = text
            .replacingOccurrences(of: "=\r\n", with: "")
            .replacingOccurrences(of: "=\n", with: "")
        let bytes = Array(normalized.utf8)
        var output = Data()
        var index = 0

        while index < bytes.count {
            if bytes[index] == 61,
               index + 2 < bytes.count,
               let high = hexValue(bytes[index + 1]),
               let low = hexValue(bytes[index + 2]) {
                output.append(high * 16 + low)
                index += 3
            } else {
                output.append(bytes[index])
                index += 1
            }
        }

        return output
    }

    private func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57:
            return byte - 48
        case 65...70:
            return byte - 55
        case 97...102:
            return byte - 87
        default:
            return nil
        }
    }

    private func string(from data: Data, charset: String?) -> String? {
        let normalized = charset?
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))

        let encoding: String.Encoding
        switch normalized {
        case nil, "", "utf-8", "utf8":
            encoding = .utf8
        case "euc-kr", "ks_c_5601-1987":
            encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))
        case "cp949", "windows-949", "ks_c_5601-1989":
            encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosKorean.rawValue)))
        case "iso-8859-1", "latin1":
            encoding = .isoLatin1
        default:
            encoding = .utf8
        }

        return String(data: data, encoding: encoding)
    }

    private func htmlToText(_ html: String) -> String {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return html
        }

        return attributed.string
    }

    private func trimmedBody(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(6000))
    }
}

private final class IMAPClient {
    private let host: String
    private let port: UInt16
    private var connection: NWConnection?
    private var buffer = Data()
    private var commandIndex = 0

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    func connect() async throws {
        let tls = NWProtocolTLS.Options()
        let parameters = NWParameters(tls: tls)
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 993,
            using: parameters
        )
        self.connection = connection

        try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    func cancel() {
        connection?.cancel()
        connection = nil
    }

    func readUntilGreeting() async throws -> String {
        try await readUntil { $0.contains("* OK") || $0.contains("* PREAUTH") }
    }

    func sendCommand(_ command: String, failureHint: String? = nil) async throws -> String {
        commandIndex += 1
        let tag = "A\(String(format: "%03d", commandIndex))"
        try await send("\(tag) \(command)\r\n")
        let response = try await readUntil { text in
            text.contains("\(tag) OK") ||
            text.contains("\(tag) NO") ||
            text.contains("\(tag) BAD")
        }

        if response.contains("\(tag) NO") || response.contains("\(tag) BAD") {
            throw IMAPError.commandFailed(failureHint ?? "메일 서버 명령이 실패했습니다.", response)
        }

        return response
    }

    private func send(_ text: String) async throws {
        guard let connection,
              let data = text.data(using: .utf8) else {
            throw IMAPError.notConnected
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func readUntil(_ isComplete: @escaping (String) -> Bool) async throws -> String {
        while true {
            let current = String(data: buffer, encoding: .utf8) ?? ""
            if isComplete(current) {
                buffer.removeAll()
                return current
            }

            let chunk = try await receive()
            buffer.append(chunk)
        }
    }

    private func receive() async throws -> Data {
        guard let connection else {
            throw IMAPError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data,
                          !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: IMAPError.connectionClosed)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }
}

private enum IMAPError: LocalizedError {
    case notConnected
    case connectionClosed
    case commandFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "메일 서버에 연결되지 않았습니다."
        case .connectionClosed:
            return "메일 서버 연결이 종료되었습니다."
        case .commandFailed(let message, let response):
            let cleanResponse = response
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .suffix(3)
                .joined(separator: " ")
            return "\(message)\n서버 응답: \(cleanResponse)"
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > 0,
               currentX + size.width > maxWidth {
                totalHeight += currentRowHeight + rowSpacing
                widestRow = max(widestRow, currentX - spacing)
                currentX = 0
                currentRowHeight = 0
            }

            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        totalHeight += currentRowHeight
        widestRow = max(widestRow, currentX > 0 ? currentX - spacing : 0)

        return CGSize(width: maxWidth > 0 ? maxWidth : widestRow, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > bounds.minX,
               currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += currentRowHeight + rowSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )

            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
