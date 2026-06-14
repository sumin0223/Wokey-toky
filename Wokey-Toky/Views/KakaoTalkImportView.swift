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
    @State private var showChatRoomFilterSheet = false
    @State private var editingChatRoom: KakaoTalkChatRoom?
    @State private var editingChatRoomAlias = ""

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
            VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
                settingsSummarySection
                connectionSection
                chatRoomSection
                messageSection
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
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                .zIndex(20)
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
                    try? modelContext.save()
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
        .sheet(isPresented: $showChatRoomFilterSheet) {
            chatRoomFilterSheet
        }
        .onAppear {
            applySettingsDefaults()
        }
    }
    
    private func candidateEditSheet(_ candidate: TaskCandidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("할 일 후보 수정")
                    .font(.title2)
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
                Text("상세")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                TextEditor(text: $editingCandidateDetail)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(WokeyDesign.quietFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .padding(24)
        .frame(width: 520, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    }
    
    private func startEditingCandidate(_ candidate: TaskCandidate) {
        editingCandidate = candidate
        editingCandidateTitle = candidate.title
        editingCandidateDetail = candidate.detail ?? ""
        editingCandidateDueText = candidate.dueText ?? ""
    }



    private var settingsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("개인정보 및 Claude 분석")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text("선택한 채팅방의 메시지만 읽고, 후보 추출을 실행할 때만 Claude API를 호출합니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                if canUseKakaoImport {
                    Label("연동됨", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(WokeyDesign.selection)
                        .clipShape(Capsule())
                }
            }

            if !canUseKakaoImport {
                Text("메시지 분석을 시작하려면 읽기 전용 분석과 선택 메시지의 Claude 전송에 동의해야 합니다.")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                Button("개인정보 안내에 동의하고 연동 시작") {
                    enableKakaoImport()
                }
            } else if let settings = currentKakaoSettings {
                HStack(spacing: 16) {
                    Label(scopeDisplayName(settings.analysisScope), systemImage: "text.magnifyingglass")
                    Label(storageDisplayName(settings.storageMode), systemImage: "externaldrive")
                    Label("Claude", systemImage: "sparkles")
                }
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
            }
        }
        .wokeyPanel()
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연결 상태")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            HStack {
                Button(isChecking ? "확인 중..." : "KakaoTalk helper 확인") {
                    Task {
                        await checkAvailability()
                    }
                }
                .disabled(isChecking)

                Label(
                    isAvailable ? "사용 가능" : "확인 필요",
                    systemImage: isAvailable ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(isAvailable ? WokeyDesign.blue : WokeyDesign.muted)

                Spacer()
            }

            Text("필요 조건: KakaoTalk for Mac, k-skill helper(kakaocli), Full Disk Access, 필요 시 Accessibility 권한")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.active)
                    .textSelection(.enabled)
            }
        }
        .wokeyPanel()
    }

    private var chatRoomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("채팅방 선택")
                        .font(.title2)
                        .bold()

                    Text("최근 범위에 해당하는 채팅방만 불러오고, 항상 추출할 방은 상세 필터에서 저장할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                Button {
                    showChatRoomFilterSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 30)
                }
                .buttonStyle(.bordered)
                .help("채팅방 상세 필터")
                .disabled(chatRooms.isEmpty)
            }

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

            let visibleRooms = visibleChatRoomsForMainList
            let pinnedCount = KakaoTalkChatAliasStore.readPinnedRooms().count

            if chatRooms.isEmpty {
                Text("아직 불러온 채팅방이 없습니다.")
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                HStack(spacing: 10) {
                    Label("선택 \(selectedChatRooms.count)개", systemImage: "checkmark.circle")
                    Label("항상 추출 \(pinnedCount)개", systemImage: "pin.fill")
                    Label("전체 \(visibleRooms.count)개", systemImage: "list.bullet")
                }
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(visibleRooms) { room in
                            chatRoomCard(room)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 280)

                if chatRooms.count > visibleRooms.count {
                    Text("목록은 최대 8개만 짧게 보여줍니다. 나머지 채팅방은 상세 필터에서 관리할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func chatRoomCard(_ room: KakaoTalkChatRoom) -> some View {
        let isSelected = selectedChatRooms.contains(room)
        let isPinned = KakaoTalkChatAliasStore.isPinned(chatId: chatId(for: room))
        let name = displayName(for: room)

        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                if isSelected {
                    selectedChatRooms.remove(room)
                } else {
                    selectedChatRooms.insert(room)
                }
                messages = []
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)

                    if name != room.name {
                        Text(room.name)
                            .font(.caption2)
                            .foregroundStyle(WokeyDesign.muted)
                    }
                }

                Spacer()

                if isPinned {
                    Label("항상", systemImage: "pin.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(WokeyDesign.statusFill)
                        .clipShape(Capsule())
                }

                if isSelected {
                    Label("선택됨", systemImage: "checkmark")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(WokeyDesign.selection)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? WokeyDesign.selection : WokeyDesign.quietFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? WokeyDesign.blue.opacity(0.35) : WokeyDesign.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var chatRoomFilterSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("채팅방 상세 필터")
                        .font(.title2)
                        .bold()

                    Text("이번 추출 선택은 현재 화면에서만 유지되고, 항상 추출/제외 체크는 누르는 즉시 저장됩니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                Button("닫기") {
                    showChatRoomFilterSheet = false
                    editingChatRoom = nil
                    editingChatRoomAlias = ""
                }
                .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 10) {
                Label("이번", systemImage: "checkmark.square")

                Divider()
                    .frame(height: 14)

                Label("항상", systemImage: "pin.fill")

                Divider()
                    .frame(height: 14)

                Label("제외", systemImage: "eye.slash")
                Text("광고/알림방으로 제외")
            }
            .font(.caption)
            .foregroundStyle(WokeyDesign.muted)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WokeyDesign.quietFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let editingChatRoom {
                VStack(alignment: .leading, spacing: 8) {
                    Text("채팅방 이름 수정")
                        .font(.headline)

                    TextField("표시할 채팅방 이름", text: $editingChatRoomAlias)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("저장") {
                            saveAlias(for: editingChatRoom)
                        }
                        .disabled(editingChatRoomAlias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button("별칭 삭제") {
                            KakaoTalkChatAliasStore.deleteAlias(for: chatId(for: editingChatRoom))
                            self.editingChatRoom = nil
                            editingChatRoomAlias = ""
                        }

                        Button("취소") {
                            self.editingChatRoom = nil
                            editingChatRoomAlias = ""
                        }

                        Spacer()
                    }
                }
                .padding(12)
                .background(WokeyDesign.quietFill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(chatRooms) { room in
                        chatRoomFilterRow(room)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 260, maxHeight: 520)
        }
        .padding(24)
        .frame(width: 720, height: 520)
    }

    private func chatRoomFilterRow(_ room: KakaoTalkChatRoom) -> some View {
        let roomId = chatId(for: room)
        let name = displayName(for: room)
        let isSelected = selectedChatRooms.contains(room)
        let isExcluded = KakaoTalkChatAliasStore.isExcluded(chatId: roomId)
        let isPinned = KakaoTalkChatAliasStore.isPinned(chatId: roomId)

        return HStack(spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    if isSelected {
                        selectedChatRooms.remove(room)
                    } else {
                        selectedChatRooms.insert(room)
                    }
                    messages = []
                }
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(isExcluded)
            .help("이번 메시지 읽기에만 포함합니다. 앱을 나갔다 오면 유지되지 않습니다.")

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(isExcluded ? WokeyDesign.muted : WokeyDesign.ink)

                if name != room.name {
                    Text("원래 이름: \(room.name)")
                        .font(.caption2)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }

            Spacer()

            Toggle("항상", isOn: Binding(
                get: { KakaoTalkChatAliasStore.isPinned(chatId: roomId) },
                set: { newValue in
                    KakaoTalkChatAliasStore.setPinned(newValue, for: roomId)
                    showToast(newValue ? "항상 추출 대상에 저장했습니다." : "항상 추출 대상에서 해제했습니다.")
                }
            ))
            .toggleStyle(.checkbox)
            .disabled(isExcluded)
            .help("체크하는 즉시 저장됩니다. 다음에 다시 들어와도 메시지 읽기 대상에 포함됩니다.")

            Toggle("제외", isOn: Binding(
                get: { KakaoTalkChatAliasStore.isExcluded(chatId: roomId) },
                set: { newValue in
                    KakaoTalkChatAliasStore.setExcluded(newValue, for: roomId)
                    if newValue {
                        selectedChatRooms.remove(room)
                        KakaoTalkChatAliasStore.setPinned(false, for: roomId)
                        showToast("광고/알림방 제외 목록에 저장했습니다.")
                    } else {
                        showToast("제외 목록에서 해제했습니다.")
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .help("체크하는 즉시 저장됩니다. 제외된 방은 선택과 항상 추출에서 빠집니다.")

            Button("이름 수정") {
                editingChatRoom = room
                editingChatRoomAlias = displayName(for: room)
            }
            .font(.caption)
        }
        .padding(12)
        .background(isExcluded ? WokeyDesign.quietFill.opacity(0.55) : WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
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
                .disabled(isLoadingMessages || selectedAndPinnedChatTargets().isEmpty || !canUseKakaoImport)

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
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(messages.count)개의 메시지를 읽었습니다. 아래에는 최근 30개만 표시합니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)

                    ForEach(messages.prefix(30)) { message in
                        messageCard(message)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
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
                        .foregroundStyle(WokeyDesign.muted)
                }
            }

            Text(message.text)
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                ForEach(kakaoCandidates) { candidate in
                    candidateCard(candidate)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
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
                    .background(WokeyDesign.statusFill)
                    .clipShape(Capsule())
            }

            if let detail = candidate.detail,
               !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
                    .textSelection(.enabled)
            }

            if let dueText = candidate.dueText,
               !dueText.isEmpty {
                Text("추정 시간/마감: \(dueText)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
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
        .padding(16)
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

    private var currentKakaoSettings: KakaoTalkSettings? {
        kakaoSettingsList.first
    }

    private var canUseKakaoImport: Bool {
        guard let settings = currentKakaoSettings else {
            return false
        }

        return settings.isEnabled && settings.hasAcceptedPrivacyNotice
    }

    private func enableKakaoImport() {
        if let settings = currentKakaoSettings {
            settings.isEnabled = true
            settings.hasAcceptedPrivacyNotice = true
            settings.llmProcessingMode = KakaoTalkLLMProcessingMode.allowExternalAPI.rawValue
            settings.updatedAt = Date()
        } else {
            modelContext.insert(
                KakaoTalkSettings(
                    isEnabled: true,
                    hasAcceptedPrivacyNotice: true,
                    llmProcessingMode: KakaoTalkLLMProcessingMode.allowExternalAPI.rawValue
                )
            )
        }

        try? modelContext.save()
        statusMessage = "카카오톡 연동을 켰습니다. helper 상태를 확인한 뒤 채팅방을 불러오세요."
        showToast("카카오톡 연동을 켰습니다.")
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
            let rooms = try await kakaoService.fetchChatRooms(limit: 100)
            persistAutoExcludedRoomsIfNeeded(rooms)
            chatRooms = filterRoomsBySettings(rooms)
            selectedChatRooms = selectedChatRooms.filter { selected in
                chatRooms.contains { chatId(for: $0) == chatId(for: selected) }
            }
            statusMessage = "\(chatRooms.count)개의 채팅방을 불러왔습니다. 광고/알림방 제외와 항상 추출 대상은 상세 필터에서 조정할 수 있습니다."
            showToast("채팅방 \(chatRooms.count)개를 불러왔습니다.")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingChats = false
    }

    private func loadMessages() async {
        let targets = selectedAndPinnedChatTargets()

        guard !targets.isEmpty else {
            return
        }

        isLoadingMessages = true
        errorMessage = nil

        var loadedMessages: [KakaoTalkMessageItem] = []
        var failedRooms: [String] = []

        for target in targets {
            do {
                let roomMessages = try await kakaoService.fetchMessages(
                    chatId: target.chatId,
                    since: since
                )

                loadedMessages.append(contentsOf: roomMessages.map { $0.withChatRoomName(target.displayName) })
            } catch {
                failedRooms.append(target.displayName)
            }
        }

        messages = loadedMessages

        if failedRooms.isEmpty {
            statusMessage = "\(targets.count)개 채팅방에서 \(messages.count)개의 메시지를 읽었습니다."
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

        let targets = selectedAndPinnedChatTargets()

        guard !targets.isEmpty else {
            errorMessage = "먼저 채팅방을 선택하거나 항상 추출할 채팅방을 저장해주세요."
            return
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
            title: targets.map { $0.displayName }.joined(separator: ", "),
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
                try? modelContext.save()
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
            return rooms.filter { !shouldExcludeRoom($0) && !isLikelyBrandOrAdChat($0) }
        }

        var result = rooms.filter { !shouldExcludeRoom($0) && !isLikelyBrandOrAdChat($0) }

        if settings.analysisScope == KakaoTalkAnalysisScope.selectedChats.rawValue {
            let selectedNames = splitCommaText(settings.selectedChatNamesText)

            guard !selectedNames.isEmpty else {
                return result
            }

            return result.filter { room in
                selectedNames.contains { selected in
                    displayName(for: room).localizedCaseInsensitiveContains(selected) ||
                    room.name.localizedCaseInsensitiveContains(selected) ||
                    selected.localizedCaseInsensitiveContains(displayName(for: room)) ||
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
        try? modelContext.save()
        showToast("Task로 추가했습니다: \(task.title)")
    }
    
    private func isLikelyBrandOrAdChat(_ room: KakaoTalkChatRoom) -> Bool {
        let text = "\(room.name) \(room.lookupName) \(room.rawDescription)".lowercased()

        let adKeywords = [
            "광고", "혜택", "쿠폰", "이벤트", "event", "coupon", "benefit", "할인", "특가",
            "쇼핑", "스토어", "배송", "주문", "브랜드", "채널", "플러스친구", "알림톡", "친구톡",
            "kakaotalk channel", "channel", "공식", "마케팅", "프로모션", "예약", "페이", "pay",
            "스팸", "newsletter", "뉴스레터", "고객센터", "cs", "카드", "보험", "증권", "은행",
            "배달의민족", "배민", "드림베이프", "카카오톡 선물하기", "선물하기", "토스오더", "에이드온",
            "티머니", "다이소멤버십", "다이소", "멤버십", "포인트", "리워드", "캐시", "적립",
            "입고", "출고", "구매", "결제", "영수증", "오더", "order", "맴버십", "라이브", "카카오페이지", "마켓", "삼쩜삼", "빗썸"
        ]

        return adKeywords.contains { keyword in
            text.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var visibleChatRoomsForMainList: [KakaoTalkChatRoom] {
        let pinnedRooms = chatRooms.filter {
            KakaoTalkChatAliasStore.isPinned(chatId: chatId(for: $0))
        }

        let selectedRooms = chatRooms.filter {
            selectedChatRooms.contains($0)
        }

        let regularRooms = chatRooms.filter { room in
            !selectedChatRooms.contains(room) &&
            !KakaoTalkChatAliasStore.isPinned(chatId: chatId(for: room))
        }

        var result: [KakaoTalkChatRoom] = []

        for room in pinnedRooms + selectedRooms + regularRooms {
            if !result.contains(where: { chatId(for: $0) == chatId(for: room) }) {
                result.append(room)
            }
        }

        return result
    }

    private func chatId(for room: KakaoTalkChatRoom) -> String {
        room.lookupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func displayName(for room: KakaoTalkChatRoom) -> String {
        let roomId = chatId(for: room)
        let aliases = KakaoTalkChatAliasStore.readAliases()
        let alias = aliases[roomId]?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let alias, !alias.isEmpty {
            return alias
        }

        return room.name
    }

    private func shouldExcludeRoom(_ room: KakaoTalkChatRoom) -> Bool {
        KakaoTalkChatAliasStore.isExcluded(chatId: chatId(for: room))
    }
    
    private func persistAutoExcludedRoomsIfNeeded(_ rooms: [KakaoTalkChatRoom]) {
        for room in rooms where isLikelyBrandOrAdChat(room) {
            let roomId = chatId(for: room)

            guard !KakaoTalkChatAliasStore.isPinned(chatId: roomId) else {
                continue
            }

            KakaoTalkChatAliasStore.setExcluded(true, for: roomId)
        }
    }

    private func saveAlias(for room: KakaoTalkChatRoom) {
        let trimmed = editingChatRoomAlias.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }

        KakaoTalkChatAliasStore.saveAlias(trimmed, for: chatId(for: room))
        editingChatRoom = nil
        editingChatRoomAlias = ""
        showToast("채팅방 이름을 저장했습니다.")
    }

    private func selectedAndPinnedChatTargets() -> [(chatId: String, displayName: String)] {
        let pinnedIds = KakaoTalkChatAliasStore.readPinnedRooms()
        var targets: [(chatId: String, displayName: String)] = []

        for room in chatRooms {
            let roomId = chatId(for: room)

            guard !KakaoTalkChatAliasStore.isExcluded(chatId: roomId) else {
                continue
            }

            if selectedChatRooms.contains(room) || pinnedIds.contains(roomId) {
                targets.append((roomId, displayName(for: room)))
            }
        }

        for pinnedId in pinnedIds {
            guard !targets.contains(where: { $0.chatId == pinnedId }) else {
                continue
            }

            guard !KakaoTalkChatAliasStore.isExcluded(chatId: pinnedId) else {
                continue
            }

            let aliases = KakaoTalkChatAliasStore.readAliases()
            targets.append((pinnedId, aliases[pinnedId] ?? pinnedId))
        }

        return targets
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

    private func scopeDisplayName(_ rawValue: String) -> String {
        KakaoTalkAnalysisScope(rawValue: rawValue)?.displayName ?? rawValue
    }

    private func storageDisplayName(_ rawValue: String) -> String {
        KakaoTalkStorageMode(rawValue: rawValue)?.displayName ?? rawValue
    }
}
