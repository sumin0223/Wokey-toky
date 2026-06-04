//
//  SettingsView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import SwiftUI
import SwiftData

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

    @State private var showDeleteConfirmation = false
    @State private var isAccessibilityGranted = false
    
    @State private var claudeAPIKey = ""
    @State private var isClaudeEnabled = true
    @State private var isClaudeAPIKeySaved = false
    @State private var keychainErrorMessage: String?

    @State private var localEndpoint = "http://127.0.0.1:11434/v1/chat/completions"
    @State private var localModelName = "qwen2.5:7b"
    @State private var localAPIKey = ""
    @State private var isLocalLLMEnabled = false
    @State private var isLocalFallbackEnabled = true
    
    private let accessibilityService = AccessibilityService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                captureSection
                
                permissionSection
                
                llmSection

                dataSection

                excludedAppsSection

                dangerZoneSection
            }
            .padding(WokeyDesign.pagePadding)
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
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.largeTitle)
                .bold()

            Text("Wokey-Toky의 수집 상태와 로컬 데이터를 관리합니다.")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)
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
                    .foregroundStyle(captureManager.isCapturing ? WokeyDesign.active : WokeyDesign.muted)

                Text(captureManager.isCapturing ? "자동 수집 중" : "자동 수집 꺼짐")
                    .font(.headline)

                Spacer()

                Button(captureManager.isCapturing ? "중지" : "시작") {
                    if captureManager.isCapturing {
                        captureManager.stop(modelContext: modelContext)
                    } else {
                        captureManager.start(modelContext: modelContext)
                    }
                }
            }

            Text("자동 수집은 focus 앱 변화와 화면에 보이는 창 구성이 바뀔 때 기록합니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
        }
        .wokeyPanel()
    }
    
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("권한")
                .font(.title2)
                .bold()

            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(isAccessibilityGranted ? WokeyDesign.active : WokeyDesign.muted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isAccessibilityGranted ? "Accessibility 권한 허용됨" : "Accessibility 권한 필요")
                        .font(.headline)

                    Text("창 제목과 현재 focus된 창 정보를 더 정확하게 기록하기 위해 필요합니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
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
        .wokeyPanel()
    }
    
    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI 설정")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 12) {
                Text("Claude API")
                    .font(.headline)

                Toggle("Claude를 기본 AI로 사용", isOn: $isClaudeEnabled)

                Text("모델: \(LLMConfig.latestSonnetModel)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                SecureField("Claude API Key", text: $claudeAPIKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text(isClaudeAPIKeySaved ? "Keychain에 저장된 키가 있습니다." : "저장된 Claude API 키가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)

                    Spacer()

                    Button("Claude 키 삭제") {
                        deleteClaudeAPIKey()
                    }
                    .disabled(!isClaudeAPIKeySaved)
                }

                if let keychainErrorMessage {
                    Text(keychainErrorMessage)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.active)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("로컬 fallback")
                    .font(.headline)

                Toggle("Claude 실패 시 로컬 모델 사용", isOn: $isLocalFallbackEnabled)

                Toggle("로컬 LLM 활성화", isOn: $isLocalLLMEnabled)

                TextField("Local Endpoint", text: $localEndpoint)
                    .textFieldStyle(.roundedBorder)

                TextField("Local Model", text: $localModelName)
                    .textFieldStyle(.roundedBorder)

                SecureField("Local API Key 선택 입력", text: $localAPIKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("설정 저장") {
                    saveLLMConfig()
                }

                Button("설정 불러오기") {
                    loadLLMConfig()
                }

                Spacer()
            }

            Text("Claude Messages API와 최신 Sonnet 모델은 앱 코드에서 관리합니다. Claude 호출이 실패하거나 비활성화되어 있으면 OpenAI-compatible 로컬 endpoint를 fallback으로 사용할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
        }
        .wokeyPanel()
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
                .foregroundStyle(WokeyDesign.muted)
        }
        .wokeyPanel()
    }

    private func dataCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)

            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(WokeyDesign.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var excludedAppsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기본 제외 권장 앱")
                .font(.title2)
                .bold()

            Text("아직 실제 제외 기능은 연결하지 않았지만, 화면 캡처와 세부 텍스트 분석을 붙일 때 아래 앱들은 기본 제외 대상으로 둘 예정입니다.")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)

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
                        .background(WokeyDesign.panel)
                        .clipShape(Capsule())
                }
            }
        }
        .wokeyPanel()
    }

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("데이터 삭제")
                .font(.title2)
                .bold()

            Text("개발 테스트 중 쌓인 데이터를 모두 삭제할 수 있습니다.")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)

            Button("전체 데이터 삭제") {
                showDeleteConfirmation = true
            }
            .foregroundStyle(WokeyDesign.active)
        }
        .wokeyPanel()
    }

    private func deleteAllData() {
        for activity in activities {
            modelContext.delete(activity)
        }

        for snapshot in snapshots {
            modelContext.delete(snapshot)
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
        if let config = currentLLMConfig {
            config.providerName = "Claude"
            config.claudeEndpoint = LLMConfig.defaultClaudeEndpoint
            config.claudeModelName = LLMConfig.latestSonnetModel
            config.claudeAPIKey = ""
            config.isClaudeEnabled = isClaudeEnabled
            config.endpoint = localEndpoint
            config.modelName = localModelName
            config.apiKey = localAPIKey
            config.isEnabled = isLocalLLMEnabled
            config.isLocalFallbackEnabled = isLocalFallbackEnabled
            config.updatedAt = Date()
        } else {
            let config = LLMConfig(
                claudeEndpoint: LLMConfig.defaultClaudeEndpoint,
                claudeModelName: LLMConfig.latestSonnetModel,
                claudeAPIKey: "",
                isClaudeEnabled: isClaudeEnabled,
                endpoint: localEndpoint,
                modelName: localModelName,
                apiKey: localAPIKey,
                isEnabled: isLocalLLMEnabled,
                isLocalFallbackEnabled: isLocalFallbackEnabled
            )

            modelContext.insert(config)
        }

        do {
            let trimmedClaudeAPIKey = claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedClaudeAPIKey.isEmpty {
                try ClaudeAPIKeyStore.saveAPIKey(trimmedClaudeAPIKey)
                claudeAPIKey = ""
            }

            isClaudeAPIKeySaved = ClaudeAPIKeyStore.hasAPIKey()
            keychainErrorMessage = nil
        } catch {
            keychainErrorMessage = error.localizedDescription
        }
    }

    private func loadLLMConfig() {
        isClaudeAPIKeySaved = ClaudeAPIKeyStore.hasAPIKey()

        guard let config = currentLLMConfig else {
            return
        }

        claudeAPIKey = ""
        isClaudeEnabled = config.isClaudeEnabledResolved
        localEndpoint = config.endpoint
        localModelName = config.modelName
        localAPIKey = config.apiKey
        isLocalLLMEnabled = config.isEnabled
        isLocalFallbackEnabled = config.isLocalFallbackEnabledResolved
    }

    private func deleteClaudeAPIKey() {
        do {
            try ClaudeAPIKeyStore.deleteAPIKey()
            claudeAPIKey = ""
            isClaudeAPIKeySaved = false
            keychainErrorMessage = nil

            for config in llmConfigs {
                config.claudeAPIKey = ""
            }
        } catch {
            keychainErrorMessage = error.localizedDescription
        }
    }
}
