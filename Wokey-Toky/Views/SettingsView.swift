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
    @State private var selectedSection: SettingsSection = .ai
    @State private var isSubmenuVisible = false
    @Environment(\.modelContext) private var modelContext
    
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
    
    
    @State private var autoApplyNaturalResponses = true
    @State private var autoApplyConfidenceThreshold = 0.75
    @State private var reviewConfidenceThreshold = 0.45
    @State private var askClarificationWhenUncertain = true
    @State private var notificationStatusText = "확인 전"
    @State private var notificationMessage: String?
    
    
    @State private var claudeAPIKey = ""
    @State private var isClaudeEnabled = true
    @State private var isClaudeAPIKeySaved = false
    @State private var personalGlossaryText = PersonalGlossaryStore.readGlossaryText()
    @State private var personalGlossaryMessage: String?
    
    private let accessibilityService = AccessibilityService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedSection.title)
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text(selectedSection.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(WokeyDesign.muted)
                }

                selectedSectionContent
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .overlay(alignment: .topTrailing) {
            if isSubmenuVisible {
                settingsSubmenuBar
                    .padding(.top, 10)
                    .padding(.trailing, WokeyDesign.pagePadding)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .offset(y: -8))
                                .combined(with: .scale(scale: 0.985, anchor: .topTrailing)),
                            removal: .opacity
                        )
                    )
                    .zIndex(10)
            }
        }
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
            personalGlossaryText = PersonalGlossaryStore.readGlossaryText()

            Task {
                await refreshNotificationStatus()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.22)) {
                    isSubmenuVisible = true
                }
            }
        }
        .onDisappear {
            isSubmenuVisible = false
        }
    }

    private var settingsSubmenuBar: some View {
        ViewThatFits(in: .horizontal) {
            fullSettingsSubmenuBar
            compactSettingsSubmenuMenu
        }
    }

    private var fullSettingsSubmenuBar: some View {
        HStack(spacing: 2) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 12, weight: .semibold))

                        Text(section.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(
                        selectedSection == section
                        ? WokeyDesign.ink
                        : WokeyDesign.muted
                    )
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background {
                        if selectedSection == section {
                            Capsule()
                                .fill(WokeyDesign.selection)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            Capsule()
                .fill(WokeyDesign.panel)
                .shadow(
                    color: Color.black.opacity(0.11),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        }
        .compositingGroup()
    }

    private var compactSettingsSubmenuMenu: some View {
        Menu {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: selectedSection.systemImage)
                    .font(.system(size: 12, weight: .semibold))

                Text(selectedSection.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Image(systemName: "chevron.right.2")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WokeyDesign.muted)
            }
            .foregroundStyle(WokeyDesign.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background {
                Capsule()
                    .fill(WokeyDesign.panel)
                    .shadow(
                        color: Color.black.opacity(0.11),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
            }
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
    }
    
    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .ai:
            llmSection
        case .response:
            responseSettingsSection
        case .glossary:
            personalGlossarySection
        case .notifications:
            notificationSection
        case .privacy:
            permissionSection
            excludedAppsSection
        case .data:
            dataSection
            dangerZoneSection
        }
    }
    
    // headerSection and captureSection removed
    
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
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text("모델: \(LLMConfig.latestSonnetModel)")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                Toggle("Claude 사용", isOn: $isClaudeEnabled)
                    .toggleStyle(.switch)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("API Key")
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                HStack(spacing: 8) {
                    Circle()
                        .fill(isClaudeAPIKeySaved ? WokeyDesign.active : WokeyDesign.muted)
                        .frame(width: 8, height: 8)

                    Text(isClaudeAPIKeySaved ? "저장된 Claude API 키가 있습니다." : "저장된 Claude API 키가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                SecureField("새 Claude API Key 입력", text: $claudeAPIKey)
                    .textFieldStyle(.roundedBorder)

                Text("저장된 키의 실제 값은 화면에 다시 표시하지 않습니다. 새 키를 저장하면 기존 키가 교체됩니다.")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                HStack {
                    Button("설정 및 키 저장") {
                        saveLLMConfig()
                    }

                    Button("저장된 키 삭제", role: .destructive) {
                        deleteClaudeAPIKey()
                    }
                    .disabled(!isClaudeAPIKeySaved)

                    Spacer()
                }
            }

            Divider()

            Text("브리핑, 요약, 자연어 답변 처리에 필요한 텍스트 일부가 Anthropic API로 전송될 수 있습니다. Endpoint와 모델은 앱에서 고정 관리합니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
        }
        .wokeyPanel()
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
    
    // kakaoTalkSettingsSection removed
    
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
    
    // dismissedSuggestions removed
    
    private func refreshAccessibilityStatus() {
        isAccessibilityGranted = accessibilityService.isAccessibilityPermissionGranted()
    }
    
    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }
    
    private func saveLLMConfig() {
        let trimmedKey = claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedKey.isEmpty {
            ClaudeAPIKeyStore.saveAPIKey(trimmedKey)
            claudeAPIKey = ""
        }

        if let config = currentLLMConfig {
            config.providerName = "Claude"
            config.claudeEndpoint = LLMConfig.defaultClaudeEndpoint
            config.claudeModelName = LLMConfig.latestSonnetModel
            config.claudeAPIKey = ""
            config.isClaudeEnabled = isClaudeEnabled
            config.endpoint = ""
            config.modelName = ""
            config.apiKey = ""
            config.isEnabled = false
            config.updatedAt = Date()
        } else {
            let config = LLMConfig(
                providerName: "Claude",
                claudeEndpoint: LLMConfig.defaultClaudeEndpoint,
                claudeModelName: LLMConfig.latestSonnetModel,
                claudeAPIKey: "",
                isClaudeEnabled: isClaudeEnabled,
                endpoint: "",
                modelName: "",
                apiKey: "",
                isEnabled: false
            )

            modelContext.insert(config)
        }

        isClaudeAPIKeySaved = ClaudeAPIKeyStore.hasAPIKey()
        try? modelContext.save()
    }
    
    private func loadLLMConfig() {
        claudeAPIKey = ""
        isClaudeAPIKeySaved = ClaudeAPIKeyStore.hasAPIKey()
        isClaudeEnabled = currentLLMConfig?.isClaudeEnabledResolved ?? true
    }

    private func deleteClaudeAPIKey() {
        ClaudeAPIKeyStore.deleteAPIKey()
        claudeAPIKey = ""
        isClaudeAPIKeySaved = false

        for config in llmConfigs {
            config.claudeAPIKey = ""
        }

        try? modelContext.save()
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
    
    // 저장/불러오기 함수
    private enum SettingsSection: String, CaseIterable, Identifiable {
        case ai
        case response
        case glossary
        case notifications
        case privacy
        case data
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .ai:
                return "AI"
            case .response:
                return "답변 처리"
            case .glossary:
                return "개인 용어 사전"
            case .notifications:
                return "알림"
            case .privacy:
                return "권한 및 개인정보"
            case .data:
                return "데이터"
            }
        }
        
        var subtitle: String {
            switch self {
            case .ai:
                return "Claude 사용 여부와 API 설정을 관리합니다."
            case .response:
                return "자연어 답변의 자동 반영과 역질문 기준을 조정합니다."
            case .glossary:
                return "개인적인 줄임말과 프로젝트 이름을 AI가 이해하도록 등록합니다."
            case .notifications:
                return "macOS 알림 권한과 브리핑 알림 일정을 관리합니다."
            case .privacy:
                return "화면 수집 권한과 민감한 앱 제외 권장 사항을 확인합니다."
            case .data:
                return "로컬 저장 데이터 현황을 확인하고 삭제합니다."
            }
        }
        
        var systemImage: String {
            switch self {
            case .ai:
                return "sparkles"
            case .response:
                return "bubble.left.and.exclamationmark.bubble.right"
            case .glossary:
                return "text.book.closed"
            case .notifications:
                return "bell"
            case .privacy:
                return "lock.shield"
            case .data:
                return "internaldrive"
            }
        }
    }
}

