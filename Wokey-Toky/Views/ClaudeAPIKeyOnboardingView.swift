//
//  ClaudeAPIKeyOnboardingView.swift
//  Wokey-Toky
//
//  Created by Codex on 5/11/26.
//

import SwiftUI
import SwiftData

struct ClaudeAPIKeyOnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    let config: LLMConfig?
    let onComplete: () -> Void

    @State private var apiKey = ""
    @State private var useLocalFallback = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection

            formSection

            fallbackSection

            actionSection
        }
        .padding(28)
        .frame(width: 520)
        .onAppear {
            loadExistingConfig()
        }
        .onDisappear {
            if !ClaudeAPIKeyStore.hasAPIKey() {
                saveFallbackOnlyConfig()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude API 연결")
                .font(.largeTitle)
                .bold()

            Text("Wokey-Toky는 Claude를 기본 AI로 사용하고, 필요하면 로컬 모델을 fallback으로 사용합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)

            SecureField("sk-ant-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            Text("모델: \(LLMConfig.latestSonnetModel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("키는 macOS Keychain에 저장됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var fallbackSection: some View {
        Toggle("Claude 호출 실패 시 로컬 fallback 사용", isOn: $useLocalFallback)
    }

    private var actionSection: some View {
        HStack {
            Button("나중에") {
                saveFallbackOnlyConfig()
                onComplete()
            }

            Spacer()

            Button("시작하기") {
                saveConfig(useClaude: true)
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func loadExistingConfig() {
        guard let config else {
            return
        }

        useLocalFallback = config.isLocalFallbackEnabledResolved
    }

    private func saveConfig(useClaude: Bool) {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if let config {
            config.providerName = "Claude"
            config.claudeEndpoint = LLMConfig.defaultClaudeEndpoint
            config.claudeModelName = LLMConfig.latestSonnetModel
            config.claudeAPIKey = ""
            config.isClaudeEnabled = useClaude
            config.isLocalFallbackEnabled = useLocalFallback
            if !useClaude {
                config.isEnabled = true
            }
            config.updatedAt = Date()
        } else {
            let newConfig = LLMConfig(
                claudeEndpoint: LLMConfig.defaultClaudeEndpoint,
                claudeModelName: LLMConfig.latestSonnetModel,
                claudeAPIKey: "",
                isClaudeEnabled: useClaude,
                isEnabled: !useClaude,
                isLocalFallbackEnabled: useLocalFallback
            )

            modelContext.insert(newConfig)
        }

        do {
            if useClaude {
                try ClaudeAPIKeyStore.saveAPIKey(trimmedAPIKey)
            } else {
                try ClaudeAPIKeyStore.deleteAPIKey()
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        onComplete()
    }

    private func saveFallbackOnlyConfig() {
        if let config {
            config.providerName = "Claude"
            config.claudeEndpoint = LLMConfig.defaultClaudeEndpoint
            config.claudeModelName = LLMConfig.latestSonnetModel
            config.claudeAPIKey = ""
            config.isClaudeEnabled = false
            config.isLocalFallbackEnabled = true
            config.isEnabled = true
            config.updatedAt = Date()
        } else {
            let newConfig = LLMConfig(
                claudeEndpoint: LLMConfig.defaultClaudeEndpoint,
                claudeModelName: LLMConfig.latestSonnetModel,
                claudeAPIKey: "",
                isClaudeEnabled: false,
                isEnabled: true,
                isLocalFallbackEnabled: true
            )

            modelContext.insert(newConfig)
        }

        try? ClaudeAPIKeyStore.deleteAPIKey()
    }
}
