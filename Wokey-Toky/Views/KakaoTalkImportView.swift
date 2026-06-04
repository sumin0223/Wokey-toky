//
//  KakaoTalkImportView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import SwiftUI
import SwiftData

struct KakaoTalkImportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskCandidate.createdAt, order: .reverse)
    private var candidates: [TaskCandidate]

    @Query private var llmConfigs: [LLMConfig]

    @Query private var kakaoSettingsList: [KakaoTalkSettings]

    @State private var isAvailable = false
    @State private var isChecking = false
    @State private var isLoadingChats = false
    @State private var isLoadingMessages = false
    @State private var isExtracting = false

    @State private var chatRooms: [KakaoTalkChatRoom] = []
    @State private var selectedChatRooms: Set<KakaoTalkChatRoom> = []
    @State private var messages: [KakaoTalkMessageItem] = []

    @State private var since = "1d"
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    
    @State private var editingCandidate: TaskCandidate?
    @State private var editingCandidateTitle = ""
    @State private var editingCandidateDetail = ""
    @State private var editingCandidateDueText = ""
    @State private var candidatePendingDelete: TaskCandidate?
    @State private var showCandidateDeleteConfirmation = false
    @State private var toastMessage: String?

    private let kakaoService = KakaoTalkService()
    private let llmService = LLMService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                settingsSummarySection
                connectionSection
                chatRoomSection
                messageSection
                candidateSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(item: $editingCandidate) { candidate in
                candidateEditSheet(candidate)
            }
            .overlay(alignment: .top) {
                if let toastMessage {
                    InAppToastView(message: toastMessage)
                }
            }
            .confirmationDialog(
                "이 후보를 삭제할까요?",
                isPresented: $showCandidateDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("후보 삭제", role: .destructive) {
                    if let candidate = candidatePendingDelete {
                        modelContext.delete(candidate)
                        showToast("후보를 삭제했습니다.")
                    }
                    candidatePendingDelete = nil
                }

                Button("취소", role: .cancel) {
                    candidatePendingDelete = nil
                }
            } message: {
                Text("삭제한 후보는 Task로 가져올 수 없습니다. 원문 메시지를 다시 읽으면 새로 추출할 수 있습니다.")
            }
        }
        .onAppear {
            applySettingsDefaults()
        }
    }
    
    private func candidateEditSheet(_ candidate: TaskCandidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("할 일 후보 수정")
                .font(.title2)
                .bold()

            TextField("제목", text: $editingCandidateTitle)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("상세")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $editingCandidateDetail)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            TextField("추정 시간/마감", text: $editingCandidateDueText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("저장") {
                    candidate.title = editingCandidateTitle
                    candidate.detail = editingCandidateDetail.isEmpty ? nil : editingCandidateDetail
                    candidate.dueText = editingCandidateDueText.isEmpty ? nil : editingCandidateDueText
                    editingCandidate = nil
                    showToast("후보를 수정했습니다.")
                }

                Button("취소") {
                    editingCandidate = nil
                }

                Spacer()
            }
        }
        .padding()
        .frame(width: 520, height: 360)
    }
    
    private func startEditingCandidate(_ candidate: TaskCandidate) {
        editingCandidate = candidate
        editingCandidateTitle = candidate.title
        editingCandidateDetail = candidate.detail ?? ""
        editingCandidateDueText = candidate.dueText ?? ""
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KakaoTalk Import")
                .font(.largeTitle)
                .bold()

            Text("선택한 카카오톡 채팅방의 최근 메시지에서 할 일 후보를 추출합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var settingsSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("연동 설정 요약")
                .font(.title2)
                .bold()

            if let settings = currentKakaoSettings {
                Text("연동 상태: \(settings.isEnabled ? "사용" : "꺼짐")")
                Text("개인정보 안내 동의: \(settings.hasAcceptedPrivacyNotice ? "완료" : "필요")")
                Text("분석 범위: \(scopeDisplayName(settings.analysisScope))")
                Text("분석 주기: \(intervalDisplayName(settings.analysisInterval))")
                Text("저장 방식: \(storageDisplayName(settings.storageMode))")
                Text("LLM 처리: \(llmModeDisplayName(settings.llmProcessingMode))")

                if !settings.isEnabled || !settings.hasAcceptedPrivacyNotice {
                    Text("Settings에서 카카오톡 연동을 켜고 개인정보 안내에 동의해야 메시지 분석을 사용할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if settings.llmProcessingMode == KakaoTalkLLMProcessingMode.allowExternalAPI.rawValue {
                    Text("외부 API 사용이 허용되어 있습니다. 선택한 메시지 일부가 외부 LLM 서버로 전송될 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else {
                Text("Settings에서 카카오톡 연동 설정을 먼저 저장해주세요.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연결 상태")
                .font(.title2)
                .bold()

            HStack {
                Button(isChecking ? "확인 중..." : "kakaocli 카카오톡 핼퍼 확인") {
                    Task {
                        await checkAvailability()
                    }
                }
                .disabled(isChecking)

                Text(isAvailable ? "사용 가능" : "확인 필요")
                    .foregroundStyle(isAvailable ? .green : .secondary)

                Spacer()
            }

            Text("필요 조건: KakaoTalk for Mac, k-skill helper(kakaocli, Full Disk Access, 필요 시 Accessibility 권한")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var chatRoomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("채팅방 선택")
                .font(.title2)
                .bold()

            HStack {
                Button(isLoadingChats ? "불러오는 중..." : "채팅방 목록 불러오기") {
                    Task {
                        await loadChatRooms()
                    }
                }
                .disabled(isLoadingChats || !canUseKakaoImport)

                TextField("최근 범위 예: 1h, 1d, 7d", text: $since)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)

                Spacer()
            }

            if chatRooms.isEmpty {
                Text("아직 불러온 채팅방이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(chatRooms) { room in
                    chatRoomCard(room)
                }
            }
        }
    }

    private func chatRoomCard(_ room: KakaoTalkChatRoom) -> some View {
        Button {
            if selectedChatRooms.contains(room) {
                selectedChatRooms.remove(room)
            } else {
                selectedChatRooms.insert(room)
            }
            messages = []
        } label: {
            HStack {
                Text(room.name)
                    .font(.headline)

                Spacer()

                if selectedChatRooms.contains(room) {
                    Text("선택됨")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.background)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedChatRooms.contains(room) ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 메시지")
                .font(.title2)
                .bold()

            HStack {
                Button(isLoadingMessages ? "읽는 중..." : "선택 채팅방 메시지 읽기") {
                    Task {
                        await loadMessages()
                    }
                }
                .disabled(isLoadingMessages || selectedChatRooms.isEmpty || !canUseKakaoImport)

                Button(isExtracting ? "추출 중..." : "메시지에서 할 일 후보 추출") {
                    Task {
                        await extractCandidatesFromMessages()
                    }
                }
                .disabled(isExtracting || messages.isEmpty || !canUseKakaoImport)

                Spacer()
            }

            if messages.isEmpty {
                Text("아직 읽은 메시지가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(messages.count)개의 메시지를 읽었습니다. 아래에는 최근 30개만 표시합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(messages.prefix(30)) { message in
                        messageCard(message)
                    }
                }
            }
        }
    }

    private func messageCard(_ message: KakaoTalkMessageItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let roomName = message.chatRoomName, !roomName.isEmpty {
                    Text(roomName)
                        .font(.caption)
                        .bold()
                }

                Text(message.sender ?? "알 수 없음")
                    .font(.caption)
                    .bold()

                Spacer()

                if let sentAt = message.sentAt {
                    Text(sentAt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(message.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KakaoTalk 추출 후보")
                .font(.title2)
                .bold()

            let kakaoCandidates = candidates.filter {
                $0.sourceType == "kakaoTalk"
            }

            if kakaoCandidates.isEmpty {
                Text("아직 카카오톡에서 추출된 후보가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(kakaoCandidates) { candidate in
                    candidateCard(candidate)
                }
            }
        }
    }

    private func candidateCard(_ candidate: TaskCandidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(candidate.title)
                    .font(.headline)

                Spacer()

                Text("신뢰도 \(candidate.confidence, specifier: "%.2f")")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            if let detail = candidate.detail,
               !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let dueText = candidate.dueText,
               !dueText.isEmpty {
                Text("추정 시간/마감: \(dueText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("수정") {
                    startEditingCandidate(candidate)
                }
                
                Button(candidate.isImported ? "이미 Task로 가져옴" : "Task로 가져오기") {
                    importCandidateAsTask(candidate)
                }
                .disabled(candidate.isImported)

                Button("후보 삭제") {
                    candidatePendingDelete = candidate
                    showCandidateDeleteConfirmation = true
                }

                Spacer()
            }
            .font(.caption)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private var currentKakaoSettings: KakaoTalkSettings? {
        kakaoSettingsList.first
    }

    private var canUseKakaoImport: Bool {
        guard let settings = currentKakaoSettings else {
            return false
        }

        return settings.isEnabled && settings.hasAcceptedPrivacyNotice
    }

    private func applySettingsDefaults() {
        guard let settings = currentKakaoSettings else {
            return
        }

        if settings.analysisScope == KakaoTalkAnalysisScope.selectedChats.rawValue,
           !settings.selectedChatNamesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            statusMessage = "Settings에 선택 채팅방이 저장되어 있습니다: \(settings.selectedChatNamesText)"
        }
    }

    private func checkAvailability() async {
        isChecking = true
        errorMessage = nil

        let available = await kakaoService.checkAvailability()
        isAvailable = available
        statusMessage = available ? "카카오톡 helper를 사용할 수 있습니다." : "카카오톡 helper를 찾지 못했습니다."
        showToast(available ? "카카오톡 helper 확인 완료" : "카카오톡 helper 확인 필요")

        isChecking = false
    }

    private func loadChatRooms() async {
        isLoadingChats = true
        errorMessage = nil

        do {
            let rooms = try await kakaoService.fetchChatRooms(limit: 30)
            chatRooms = filterRoomsBySettings(rooms)
            statusMessage = "\(chatRooms.count)개의 채팅방을 불러왔습니다."
            showToast("채팅방 \(chatRooms.count)개를 불러왔습니다.")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingChats = false
    }

    private func loadMessages() async {
        guard !selectedChatRooms.isEmpty else {
            return
        }

        isLoadingMessages = true
        errorMessage = nil

        var loadedMessages: [KakaoTalkMessageItem] = []
        var failedRooms: [String] = []

        for room in selectedChatRooms {
            do {
                let roomMessages = try await kakaoService.fetchMessages(
                    chatId: room.lookupName,
                    since: since
                )

                loadedMessages.append(contentsOf: roomMessages.map { $0.withChatRoomName(room.name) })
            } catch {
                failedRooms.append(room.name)
            }
        }

        messages = loadedMessages

        if failedRooms.isEmpty {
            statusMessage = "\(selectedChatRooms.count)개 채팅방에서 \(messages.count)개의 메시지를 읽었습니다."
        } else {
            statusMessage = "\(messages.count)개의 메시지를 읽었습니다. 실패한 채팅방: \(failedRooms.joined(separator: ", "))"
        }
        showToast("메시지 \(messages.count)개를 읽었습니다. 분석에는 아직 토큰을 사용하지 않았습니다.")

        isLoadingMessages = false
    }

    private func extractCandidatesFromMessages() async {
        guard let config = currentLLMConfig else {
            errorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        guard !selectedChatRooms.isEmpty else {
            errorMessage = "먼저 채팅방을 선택해주세요."
            return
        }

        if let settings = currentKakaoSettings,
           settings.llmProcessingMode == KakaoTalkLLMProcessingMode.localOnly.rawValue {
            if config.isClaudeConfigured || !isLocalEndpoint(config.endpoint) {
                errorMessage = "카카오톡 설정이 '로컬 Ollama만 사용'입니다. Claude 또는 외부 endpoint를 쓰려면 카카오톡 설정에서 외부 API 허용을 선택하세요."
                return
            }
        }

        isExtracting = true
        errorMessage = nil

        let rawText = filteredMessagesForExtraction(messages)
            .map { message in
                let sender = message.sender ?? "알 수 없음"
                let time = message.sentAt ?? ""
                let room = message.chatRoomName ?? "선택 채팅방"
                return "[\(time)] [\(room)] \(sender): \(message.text)"
            }
            .joined(separator: "\n")

        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "분석할 메시지가 없습니다. 키워드 설정 또는 메시지 범위를 확인해주세요."
            isExtracting = false
            return
        }

        let sourceImport = SourceImport(
            sourceType: "kakaoTalk",
            title: selectedChatRooms.map { $0.name }.joined(separator: ", "),
            rawText: sourceTextToStore(rawText)
        )
        modelContext.insert(sourceImport)

        do {
            let extracted = try await llmService.extractTaskCandidates(
                sourceText: rawText,
                sourceType: "kakaoTalk",
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
                        sourceType: "kakaoTalk",
                        sourceText: candidateSourceText(rawText),
                        suggestedDueAt: nil,
                        dueText: item.dueText,
                        confidence: item.confidence ?? 0.5
                    )

                    modelContext.insert(candidate)
                }

                statusMessage = "\(extracted.count)개의 할 일 후보를 추출했습니다."
                showToast("\(extracted.count)개의 후보를 추출했습니다.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isExtracting = false
    }

    private func filterRoomsBySettings(_ rooms: [KakaoTalkChatRoom]) -> [KakaoTalkChatRoom] {
        guard let settings = currentKakaoSettings else {
            return rooms
        }

        var result = rooms

        if settings.excludeBrandChats {
            result = result.filter { !isLikelyBrandOrAdChat($0) }
        }

        if settings.analysisScope == KakaoTalkAnalysisScope.selectedChats.rawValue {
            let selectedNames = splitCommaText(settings.selectedChatNamesText)

            guard !selectedNames.isEmpty else {
                return result
            }

            return result.filter { room in
                selectedNames.contains { selected in
                    room.name.localizedCaseInsensitiveContains(selected) ||
                    selected.localizedCaseInsensitiveContains(room.name)
                }
            }
        }

        return result
    }

    private func filteredMessagesForExtraction(_ input: [KakaoTalkMessageItem]) -> [KakaoTalkMessageItem] {
        let base = input
            .filter { !isLikelyBrandOrAdMessage($0) }
            .filter { message in
                let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count >= 3
            }

        guard let settings = currentKakaoSettings else {
            return base
        }

        if settings.analysisScope == KakaoTalkAnalysisScope.keywordMessages.rawValue {
            let keywords = splitCommaText(settings.keywordsText)

            guard !keywords.isEmpty else {
                return base
            }

            return base.filter { message in
                keywords.contains { keyword in
                    message.text.localizedCaseInsensitiveContains(keyword)
                }
            }
        }

        return base
    }

    private func sourceTextToStore(_ rawText: String) -> String {
        guard let settings = currentKakaoSettings else {
            return rawText
        }

        switch settings.storageMode {
        case KakaoTalkStorageMode.noRawMessage.rawValue:
            return "원문 메시지 저장 안 함"
        case KakaoTalkStorageMode.deleteRawAfterExtraction.rawValue:
            return "후보 생성 후 원문 삭제 설정"
        default:
            return rawText.prefix(1000).description
        }
    }

    private func candidateSourceText(_ rawText: String) -> String {
        guard let settings = currentKakaoSettings else {
            return rawText.prefix(1000).description
        }

        switch settings.storageMode {
        case KakaoTalkStorageMode.noRawMessage.rawValue:
            return "원문 메시지 저장 안 함"
        case KakaoTalkStorageMode.deleteRawAfterExtraction.rawValue:
            return "후보 생성 후 원문 삭제 설정"
        default:
            return rawText.prefix(1000).description
        }
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

        detailParts.append("원본 출처: KakaoTalk")

        let task = TaskItem(
            title: candidate.title,
            detail: detailParts.joined(separator: "\n"),
            source: "kakaoTalk",
            status: TaskStatus.pending.rawValue,
            dueAt: candidate.suggestedDueAt,
            relatedKeywords: candidate.title
        )

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
            reason: "KakaoTalk 후보를 Task로 가져왔습니다.",
            source: "kakaoTalk",
            confidence: candidate.confidence
        )
        modelContext.insert(log)

        let notification = AppNotification(
            title: "새 Task가 추가되었습니다",
            message: "\(task.title) · 출처: KakaoTalk",
            kind: "taskCandidate",
            source: "kakaoTalk",
            relatedTaskTitle: task.title,
            confidence: candidate.confidence
        )
        modelContext.insert(notification)
        showToast("Task로 추가했습니다: \(task.title)")
    }
    
    private func isLikelyBrandOrAdChat(_ room: KakaoTalkChatRoom) -> Bool {
        let text = room.name.lowercased()

        let adKeywords = [
            "광고", "혜택", "쿠폰", "이벤트", "event", "coupon", "benefit", "할인", "특가",
            "쇼핑", "스토어", "배송", "주문", "브랜드", "채널", "플러스친구", "알림톡", "친구톡",
            "kakaotalk channel", "channel", "공식", "마케팅", "프로모션", "예약", "페이", "pay",
            "스팸", "newsletter", "뉴스레터", "고객센터", "cs", "카드", "보험", "증권", "은행"
        ]

        return adKeywords.contains { keyword in
            text.localizedCaseInsensitiveContains(keyword)
        }
    }


    private func isLikelyBrandOrAdMessage(_ message: KakaoTalkMessageItem) -> Bool {
        let text = message.text.lowercased()
        let adKeywords = [
            "광고", "혜택", "쿠폰", "이벤트", "event", "coupon", "benefit", "할인", "특가",
            "무료배송", "배송비", "적립", "포인트", "선착순", "구매", "주문", "스토어",
            "수신거부", "마케팅", "프로모션", "카카오톡 채널", "알림톡", "친구톡", "브랜드"
        ]

        return adKeywords.contains { keyword in
            text.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func splitCommaText(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isLocalEndpoint(_ endpoint: String) -> Bool {
        endpoint.contains("127.0.0.1") ||
        endpoint.contains("localhost")
    }

    private func scopeDisplayName(_ rawValue: String) -> String {
        KakaoTalkAnalysisScope(rawValue: rawValue)?.displayName ?? rawValue
    }

    private func intervalDisplayName(_ rawValue: String) -> String {
        KakaoTalkAnalysisInterval(rawValue: rawValue)?.displayName ?? rawValue
    }

    private func storageDisplayName(_ rawValue: String) -> String {
        KakaoTalkStorageMode(rawValue: rawValue)?.displayName ?? rawValue
    }

    private func llmModeDisplayName(_ rawValue: String) -> String {
        KakaoTalkLLMProcessingMode(rawValue: rawValue)?.displayName ?? rawValue
    }
}
