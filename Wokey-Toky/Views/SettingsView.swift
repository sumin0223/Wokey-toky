//
//  SettingsView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var captureManager: ContextCaptureManager

    @Query private var activities: [ActivityEvent]
    @Query private var snapshots: [ScreenContextSnapshot]
    @Query private var windowRecords: [VisibleWindowRecord]
    @Query private var tasks: [TaskItem]
    @Query private var suggestions: [Suggestion]
    @Query private var llmConfigs: [LLMConfig]
    @Query private var userTaskResponses: [UserTaskResponse]
    @Query private var responseSettingsList: [ResponseSettings]
    @Query private var chatMessages: [ChatMessage]
    @Query private var taskCandidates: [TaskCandidate]
    @Query private var sourceImports: [SourceImport]
    @Query private var kakaoTalkSettingsList: [KakaoTalkSettings]
    @Query private var appNotifications: [AppNotification]
    @Query private var taskChangeLogs: [TaskChangeLog]

    @State private var showDeleteConfirmation = false
    @State private var isAccessibilityGranted = false
    
    @State private var llmEndpoint = "http://127.0.0.1:11434/v1/chat/completions"
    @State private var llmModelName = "qwen2.5:7b"
    @State private var llmAPIKey = ""
    @State private var isLLMEnabled = false
    
    @State private var autoApplyNaturalResponses = true
    @State private var autoApplyConfidenceThreshold = 0.75
    @State private var reviewConfidenceThreshold = 0.45
    @State private var askClarificationWhenUncertain = true
    @State private var notificationStatusText = "확인 전"
    @State private var notificationMessage: String?
    
    @State private var kakaoIsEnabled = false
    @State private var kakaoHasAcceptedPrivacyNotice = false

    @State private var kakaoAnalysisScope = KakaoTalkAnalysisScope.selectedChats.rawValue
    @State private var kakaoAnalysisInterval = KakaoTalkAnalysisInterval.manual.rawValue
    @State private var kakaoStorageMode = KakaoTalkStorageMode.evidenceSnippetOnly.rawValue
    @State private var kakaoLLMProcessingMode = KakaoTalkLLMProcessingMode.localOnly.rawValue

    @State private var kakaoKeywordsText = "과제,회의,마감,제출,보내줘,공유,내일,오늘,까지"
    @State private var kakaoSelectedChatNamesText = ""

    @State private var kakaoSettingsMessage: String?
    
    @State private var kakaoExcludeBrandChats = true
    
    @State private var claudeAPIKey = ""
    @State private var isClaudeEnabled = true
    @State private var isLocalFallbackEnabled = false
    @State private var personalGlossaryText = PersonalGlossaryStore.readGlossaryText()
    @State private var personalGlossaryMessage: String?
    
    private let accessibilityService = AccessibilityService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                captureSection
                
                permissionSection
                
                llmSection
                
                responseSettingsSection

                personalGlossarySection
                
                kakaoTalkSettingsSection
                
                notificationSection

                dataSection

                excludedAppsSection

                dangerZoneSection
            }
            .padding()
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "정말 모든 데이터를 삭제할까요?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("전체 데이터 삭제", role: .destructive) {
                deleteAllData()
            }

            Button("취소", role: .cancel) { }
        } message: {
            Text("오늘의 활동, 화면 기록, Tasks, Suggestions가 모두 삭제됩니다.")
        }
        .onAppear {
            refreshAccessibilityStatus()
            loadLLMConfig()
            loadResponseSettings()
            loadKakaoTalkSettings()
            personalGlossaryText = PersonalGlossaryStore.readGlossaryText()
            
            Task {
                    await refreshNotificationStatus()
                }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.largeTitle)
                .bold()

            Text("Wokey-Toky의 수집 상태와 로컬 데이터를 관리합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("자동 수집")
                .font(.title2)
                .bold()

            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(captureManager.isCapturing ? .green : .gray)

                Text(captureManager.isCapturing ? "자동 수집 중" : "자동 수집 꺼짐")
                    .font(.headline)

                Spacer()

                Button(captureManager.isCapturing ? "중지" : "시작") {
                    if captureManager.isCapturing {
                        captureManager.stop()
                    } else {
                        captureManager.start(modelContext: modelContext)
                    }
                }
            }

            Text("자동 수집은 focus 앱 변화와 화면에 보이는 창 구성이 바뀔 때 기록합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("권한")
                .font(.title2)
                .bold()

            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(isAccessibilityGranted ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isAccessibilityGranted ? "Accessibility 권한 허용됨" : "Accessibility 권한 필요")
                        .font(.headline)

                    Text("창 제목과 현재 focus된 창 정보를 더 정확하게 기록하기 위해 필요합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("권한 요청") {
                    accessibilityService.requestAccessibilityPermission()
                    refreshAccessibilityStatus()
                }

                Button("설정 열기") {
                    accessibilityService.openAccessibilitySettings()
                }

                Button("새로고침") {
                    refreshAccessibilityStatus()
                }
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LLM 설정")
                .font(.title2)
                .bold()
            
            Toggle("Claude Sonnet 사용", isOn: $isClaudeEnabled)

            SecureField("Claude API Key", text: $claudeAPIKey)
                .textFieldStyle(.roundedBorder)

            Toggle("Claude 실패 시 로컬 Ollama로 대체", isOn: $isLocalFallbackEnabled)

            Text("외부 Claude API를 사용하면 브리핑/채팅/메모/카카오톡에서 분석하는 텍스트 일부가 Anthropic 서버로 전송될 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("LLM 요약 사용", isOn: $isLLMEnabled)

            TextField("Endpoint", text: $llmEndpoint)
                .textFieldStyle(.roundedBorder)

            TextField("Model", text: $llmModelName)
                .textFieldStyle(.roundedBorder)

            SecureField("API Key", text: $llmAPIKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("설정 저장") {
                    saveLLMConfig()
                }

                Button("설정 불러오기") {
                    loadLLMConfig()
                }

                Spacer()
            }

            Text("OpenAI-compatible chat completions endpoint를 기준으로 동작합니다. 로컬 모델 서버를 사용할 경우 endpoint를 해당 서버 주소로 바꾸면 됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var responseSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("답변 처리 설정")
                .font(.title2)
                .bold()

            Toggle("자연어 답변 자동 반영", isOn: $autoApplyNaturalResponses)

            VStack(alignment: .leading, spacing: 8) {
                Text("자동 반영 최소 확신도: \(autoApplyConfidenceThreshold, specifier: "%.2f")")
                    .font(.subheadline)

                Slider(
                    value: $autoApplyConfidenceThreshold,
                    in: 0.5...0.95,
                    step: 0.05
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("검토 필요 확신도 기준: \(reviewConfidenceThreshold, specifier: "%.2f")")
                    .font(.subheadline)

                Slider(
                    value: $reviewConfidenceThreshold,
                    in: 0.1...0.75,
                    step: 0.05
                )
            }

            Toggle("애매한 답변은 역질문으로 넘기기", isOn: $askClarificationWhenUncertain)

            HStack {
                Button("답변 설정 저장") {
                    saveResponseSettings()
                }

                Button("답변 설정 불러오기") {
                    loadResponseSettings()
                }

                Spacer()
            }

            Text("확신도가 높은 답변은 자동으로 Task 상태에 반영하고, 낮은 답변은 검토 또는 역질문으로 분류합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var personalGlossarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("개인 용어 사전")
                .font(.title2)
                .bold()

            Text("카카오톡/메모의 줄임말, 과목명, 프로젝트명을 정식 표현으로 풀어 쓰기 위한 사전입니다. 예: 스작설 = 스마트작업설계")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $personalGlossaryText)
                .frame(minHeight: 120)
                .padding(8)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Button("용어 사전 저장") {
                    PersonalGlossaryStore.saveGlossaryText(personalGlossaryText)
                    personalGlossaryMessage = "개인 용어 사전을 저장했습니다. 다음 LLM 분석부터 반영됩니다."
                }

                Button("기본 예시로 복원") {
                    personalGlossaryText = PersonalGlossaryStore.defaultGlossary
                    PersonalGlossaryStore.saveGlossaryText(personalGlossaryText)
                    personalGlossaryMessage = "기본 예시로 복원했습니다."
                }

                Spacer()
            }

            if let personalGlossaryMessage {
                Text(personalGlossaryMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var kakaoTalkSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("카카오톡 연동 설정")
                .font(.title2)
                .bold()

            privacyNoticeBox

            Toggle("카카오톡 메시지 기반 할 일 감지 사용", isOn: $kakaoIsEnabled)

            Toggle("개인정보 안내를 확인했고, 선택한 범위의 메시지 분석에 동의합니다", isOn: $kakaoHasAcceptedPrivacyNotice)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("분석 범위")
                    .font(.headline)

                Picker("분석 범위", selection: $kakaoAnalysisScope) {
                    ForEach(KakaoTalkAnalysisScope.allCases) { scope in
                        Text(scope.displayName).tag(scope.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            Toggle("광고성/브랜드 채팅방 기본 제외", isOn: $kakaoExcludeBrandChats)

            Text("쿠폰, 이벤트, 혜택, 브랜드 알림처럼 할 일과 관련성이 낮은 채팅방을 기본적으로 제외합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if kakaoAnalysisScope == KakaoTalkAnalysisScope.selectedChats.rawValue {
                VStack(alignment: .leading, spacing: 8) {
                    Text("선택 채팅방 이름")
                        .font(.headline)

                    TextField("예: 팀플방, 과제방, 동아리방", text: $kakaoSelectedChatNamesText)
                        .textFieldStyle(.roundedBorder)

                    Text("여러 개는 쉼표로 구분합니다. 예: 팀플방, 과제방")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if kakaoAnalysisScope == KakaoTalkAnalysisScope.keywordMessages.rawValue {
                VStack(alignment: .leading, spacing: 8) {
                    Text("감지 키워드")
                        .font(.headline)

                    TextField("과제,회의,마감,제출,보내줘", text: $kakaoKeywordsText)
                        .textFieldStyle(.roundedBorder)

                    Text("전체 대화 중 이 키워드가 포함된 메시지만 분석합니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if kakaoAnalysisScope == KakaoTalkAnalysisScope.recentAllChats.rawValue {
                Text("전체 채팅방 최근 메시지 분석은 실험 기능입니다. 민감한 대화가 포함될 수 있으므로 기본값으로 권장하지 않습니다.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("분석 주기")
                    .font(.headline)

                Picker("분석 주기", selection: $kakaoAnalysisInterval) {
                    ForEach(KakaoTalkAnalysisInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("데이터 저장")
                    .font(.headline)

                Picker("데이터 저장", selection: $kakaoStorageMode) {
                    ForEach(KakaoTalkStorageMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("LLM 처리 방식")
                    .font(.headline)

                Picker("LLM 처리 방식", selection: $kakaoLLMProcessingMode) {
                    ForEach(KakaoTalkLLMProcessingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                if kakaoLLMProcessingMode == KakaoTalkLLMProcessingMode.allowExternalAPI.rawValue {
                    Text("외부 API를 사용하면 선택한 메시지 일부가 외부 LLM 서버로 전송될 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("카카오톡 설정 저장") {
                    saveKakaoTalkSettings()
                }

                Button("카카오톡 설정 불러오기") {
                    loadKakaoTalkSettings()
                }

                Spacer()
            }

            if let kakaoSettingsMessage {
                Text(kakaoSettingsMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("알림 설정")
                .font(.title2)
                .bold()

            Text("현재 알림 권한: \(notificationStatusText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("알림 권한 요청") {
                    Task {
                        let granted = await NotificationService.shared.requestAuthorization()
                        notificationStatusText = granted ? "허용됨" : "거부됨"
                    }
                }

                Button("알림 상태 새로고침") {
                    Task {
                        await refreshNotificationStatus()
                    }
                }

                Button("테스트 알림") {
                    NotificationService.shared.sendTestNotification()
                }
            }
            
            if let notificationMessage {
                Text(notificationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("아침 알림 예약") {
                    NotificationService.shared.scheduleBriefingNotification(
                        type: .morning,
                        hour: 9,
                        minute: 0
                    )
                    notificationMessage = "아침 브리핑 알림이 매일 09:00에 예약되었습니다."
                }

                Button("점심 알림 예약") {
                    NotificationService.shared.scheduleBriefingNotification(
                        type: .lunch,
                        hour: 12,
                        minute: 30
                    )
                    notificationMessage = "점심 점검 알림이 매일 12:30에 예약되었습니다."
                }

                Button("저녁 알림 예약") {
                    NotificationService.shared.scheduleBriefingNotification(
                        type: .evening,
                        hour: 21,
                        minute: 0
                    )
                    notificationMessage = "저녁 회고 알림이 매일 21:00에 예약되었습니다."
                }
            }

            Button("예약된 알림 전체 삭제") {
                NotificationService.shared.removeAllScheduledNotifications()
                notificationMessage = "예약된 알림을 모두 삭제했습니다."
            }
            .foregroundStyle(.red)

            Text("1차 버전에서는 고정 시간으로 아침 9시, 점심 12시 30분, 저녁 9시에 브리핑 알림을 예약합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("저장된 데이터")
                .font(.title2)
                .bold()

            HStack(spacing: 16) {
                    dataCard(title: "활동 기록", value: "\(activities.count)")
                    dataCard(title: "화면 스냅샷", value: "\(snapshots.count)")
                    dataCard(title: "화면 창 기록", value: "\(windowRecords.count)")
            }

            HStack(spacing: 16) {
                dataCard(title: "진행 중 Tasks", value: "\(activeTasks.count)")
                dataCard(title: "완료 Tasks", value: "\(completedTasks.count)")
                dataCard(title: "활성 Suggestions", value: "\(activeSuggestions.count)")
            }

            Text("현재 데이터는 사용자의 Mac 안에 SwiftData로 저장됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dataCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var excludedAppsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기본 제외 권장 앱")
                .font(.title2)
                .bold()

            Text("아직 실제 제외 기능은 연결하지 않았지만, 화면 캡처와 세부 텍스트 분석을 붙일 때 아래 앱들은 기본 제외 대상으로 둘 예정입니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let apps = [
                "1Password",
                "Bitwarden",
                "Keychain Access",
                "System Settings",
                "Mail",
                "Messages",
                "KakaoTalk",
                "은행/증권 앱"
            ]

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], alignment: .leading, spacing: 8) {
                ForEach(apps, id: \.self) { app in
                    Text(app)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.background)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("데이터 삭제")
                .font(.title2)
                .bold()

            Text("개발 테스트 중 쌓인 데이터를 모두 삭제할 수 있습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("전체 데이터 삭제") {
                showDeleteConfirmation = true
            }
            .foregroundStyle(.red)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func deleteAllData() {
        for activity in activities {
            modelContext.delete(activity)
        }

        for snapshot in snapshots {
            modelContext.delete(snapshot)
        }

        for windowRecord in windowRecords {
            modelContext.delete(windowRecord)
        }

        for task in tasks {
            modelContext.delete(task)
        }

        for suggestion in suggestions {
            modelContext.delete(suggestion)
        }

        for response in userTaskResponses {
            modelContext.delete(response)
        }

        for settings in responseSettingsList {
            modelContext.delete(settings)
        }
        
        for message in chatMessages {
            modelContext.delete(message)
        }
        
        for candidate in taskCandidates {
            modelContext.delete(candidate)
        }

        for sourceImport in sourceImports {
            modelContext.delete(sourceImport)
        }
        
        for settings in kakaoTalkSettingsList {
            modelContext.delete(settings)
        }

        for notification in appNotifications {
            modelContext.delete(notification)
        }

        for log in taskChangeLogs {
            modelContext.delete(log)
        }
    }
    
    private var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted }
    }

    private var activeSuggestions: [Suggestion] {
        suggestions.filter { !$0.isDismissed }
    }

    private var dismissedSuggestions: [Suggestion] {
        suggestions.filter { $0.isDismissed }
    }
    
    private func refreshAccessibilityStatus() {
        isAccessibilityGranted = accessibilityService.isAccessibilityPermissionGranted()
    }
    
    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private func saveLLMConfig() {
        ClaudeAPIKeyStore.saveAPIKey(claudeAPIKey)

        if let config = llmConfigs.first {
            config.providerName = isClaudeEnabled ? "Claude" : "Local"

            config.claudeEndpoint = LLMConfig.defaultClaudeEndpoint
            config.claudeModelName = LLMConfig.latestSonnetModel
            config.claudeAPIKey = nil
            config.isClaudeEnabled = isClaudeEnabled

            config.endpoint = llmEndpoint
            config.modelName = llmModelName
            config.apiKey = llmAPIKey
            config.isEnabled = isLLMEnabled
            config.isLocalFallbackEnabled = isLocalFallbackEnabled

            config.updatedAt = Date()
        } else {
            let config = LLMConfig(
                providerName: isClaudeEnabled ? "Claude" : "Local",
                claudeEndpoint: LLMConfig.defaultClaudeEndpoint,
                claudeModelName: LLMConfig.latestSonnetModel,
                claudeAPIKey: "",
                isClaudeEnabled: isClaudeEnabled,
                endpoint: llmEndpoint,
                modelName: llmModelName,
                apiKey: llmAPIKey,
                isEnabled: isLLMEnabled,
                isLocalFallbackEnabled: isLocalFallbackEnabled
            )

            modelContext.insert(config)
        }
    }
    
    private func loadLLMConfig() {
        guard let config = llmConfigs.first else {
            llmEndpoint = "http://127.0.0.1:11434/v1/chat/completions"
            llmModelName = "qwen2.5:7b"
            llmAPIKey = ""
            isLLMEnabled = false

            claudeAPIKey = ClaudeAPIKeyStore.readAPIKey()
            isClaudeEnabled = true
            isLocalFallbackEnabled = false
            return
        }

        llmEndpoint = config.endpoint
        llmModelName = config.modelName
        llmAPIKey = config.apiKey
        isLLMEnabled = config.isEnabled

        claudeAPIKey = ClaudeAPIKeyStore.readAPIKey()
        isClaudeEnabled = config.isClaudeEnabledResolved
        isLocalFallbackEnabled = config.isLocalFallbackEnabledResolved
    }

    // 저장 및 불러오기 함수
    private var currentResponseSettings: ResponseSettings? {
        responseSettingsList.first
    }

    private func saveResponseSettings() {
        if let settings = currentResponseSettings {
            settings.autoApplyNaturalResponses = autoApplyNaturalResponses
            settings.autoApplyConfidenceThreshold = autoApplyConfidenceThreshold
            settings.reviewConfidenceThreshold = reviewConfidenceThreshold
            settings.askClarificationWhenUncertain = askClarificationWhenUncertain
            settings.updatedAt = Date()
        } else {
            let settings = ResponseSettings(
                autoApplyNaturalResponses: autoApplyNaturalResponses,
                autoApplyConfidenceThreshold: autoApplyConfidenceThreshold,
                reviewConfidenceThreshold: reviewConfidenceThreshold,
                askClarificationWhenUncertain: askClarificationWhenUncertain
            )

            modelContext.insert(settings)
        }
    }

    private func loadResponseSettings() {
        guard let settings = currentResponseSettings else {
            return
        }

        autoApplyNaturalResponses = settings.autoApplyNaturalResponses
        autoApplyConfidenceThreshold = settings.autoApplyConfidenceThreshold
        reviewConfidenceThreshold = settings.reviewConfidenceThreshold
        askClarificationWhenUncertain = settings.askClarificationWhenUncertain
    }
    
    // 알림 상태 새로고침
    @MainActor
    private func refreshNotificationStatus() async {
        let status = await NotificationService.shared.getAuthorizationStatus()

        switch status {
        case .notDetermined:
            notificationStatusText = "권한 요청 전"
        case .denied:
            notificationStatusText = "거부됨"
        case .authorized:
            notificationStatusText = "허용됨"
        case .provisional:
            notificationStatusText = "임시 허용"
        case .ephemeral:
            notificationStatusText = "임시 세션 허용"
        @unknown default:
            notificationStatusText = "알 수 없음"
        }
    }
    
    // 개인정보 안내 박스(카톡)
    private var privacyNoticeBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("연동 전 안내")
                .font(.headline)

            Text("• Wokey-Toky는 카카오톡 메시지를 읽기 전용으로 분석합니다.")
            Text("• 자동 메시지 전송, 삭제, 수정은 하지 않습니다.")
            Text("• 기본값은 선택한 채팅방만 분석하는 방식입니다.")
            Text("• 원문 메시지는 설정한 저장 방식에 따라 최소한으로 처리합니다.")
            Text("• 로컬 Ollama 사용 시 메시지는 사용자의 Mac 안에서 분석됩니다.")
            Text("• 외부 LLM API 사용 시 선택한 메시지 일부가 외부 서버로 전송될 수 있습니다.")

            Text("전체 채팅방 분석과 실시간에 가까운 감지는 실험 기능이며, 사용자가 명시적으로 켠 경우에만 사용됩니다.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // 저장/불러오기 함수
    private var currentKakaoTalkSettings: KakaoTalkSettings? {
        kakaoTalkSettingsList.first
    }

    private func saveKakaoTalkSettings() {
        if kakaoIsEnabled && !kakaoHasAcceptedPrivacyNotice {
            kakaoSettingsMessage = "카카오톡 연동을 사용하려면 개인정보 안내 확인에 동의해야 합니다."
            return
        }

        if kakaoAnalysisScope == KakaoTalkAnalysisScope.recentAllChats.rawValue &&
            kakaoIsEnabled &&
            !kakaoHasAcceptedPrivacyNotice {
            kakaoSettingsMessage = "전체 채팅방 분석은 개인정보 안내 동의 후 사용할 수 있습니다."
            return
        }

        if let settings = currentKakaoTalkSettings {
            settings.isEnabled = kakaoIsEnabled
            settings.hasAcceptedPrivacyNotice = kakaoHasAcceptedPrivacyNotice
            settings.analysisScope = kakaoAnalysisScope
            settings.analysisInterval = kakaoAnalysisInterval
            settings.storageMode = kakaoStorageMode
            settings.llmProcessingMode = kakaoLLMProcessingMode
            settings.keywordsText = kakaoKeywordsText
            settings.selectedChatNamesText = kakaoSelectedChatNamesText
            settings.excludeBrandChats = kakaoExcludeBrandChats
            settings.updatedAt = Date()
        } else {
            let settings = KakaoTalkSettings(
                isEnabled: kakaoIsEnabled,
                hasAcceptedPrivacyNotice: kakaoHasAcceptedPrivacyNotice,
                analysisScope: kakaoAnalysisScope,
                analysisInterval: kakaoAnalysisInterval,
                storageMode: kakaoStorageMode,
                llmProcessingMode: kakaoLLMProcessingMode,
                keywordsText: kakaoKeywordsText,
                selectedChatNamesText: kakaoSelectedChatNamesText,
                excludeBrandChats: kakaoExcludeBrandChats
            )

            modelContext.insert(settings)
        }

        kakaoSettingsMessage = "카카오톡 연동 설정을 저장했습니다."
    }

    private func loadKakaoTalkSettings() {
        guard let settings = currentKakaoTalkSettings else {
            return
        }

        kakaoIsEnabled = settings.isEnabled
        kakaoHasAcceptedPrivacyNotice = settings.hasAcceptedPrivacyNotice
        kakaoAnalysisScope = settings.analysisScope
        kakaoAnalysisInterval = settings.analysisInterval
        kakaoStorageMode = settings.storageMode
        kakaoLLMProcessingMode = settings.llmProcessingMode
        kakaoKeywordsText = settings.keywordsText
        kakaoSelectedChatNamesText = settings.selectedChatNamesText
        kakaoExcludeBrandChats = settings.excludeBrandChats

        kakaoSettingsMessage = "카카오톡 연동 설정을 불러왔습니다."
    }
}
