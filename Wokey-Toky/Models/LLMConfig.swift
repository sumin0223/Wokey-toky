//
//  LLMConfig.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import Foundation
import SwiftData

@Model
final class LLMConfig {
    static let defaultClaudeEndpoint = "https://api.anthropic.com/v1/messages"
    static let latestSonnetModel = "claude-sonnet-4-6"

    var providerName: String
    var claudeEndpoint: String?
    var claudeModelName: String?
    var claudeAPIKey: String?
    var isClaudeEnabled: Bool?

    // Local fallback uses an OpenAI-compatible endpoint such as Ollama.
    var endpoint: String
    var modelName: String
    var apiKey: String
    var isEnabled: Bool
    var isLocalFallbackEnabled: Bool?

    var createdAt: Date
    var updatedAt: Date

    init(
        providerName: String = "Claude",
        claudeEndpoint: String = LLMConfig.defaultClaudeEndpoint,
        claudeModelName: String = LLMConfig.latestSonnetModel,
        claudeAPIKey: String = "",
        isClaudeEnabled: Bool = true,
        endpoint: String = "http://127.0.0.1:11434/v1/chat/completions",
        modelName: String = "qwen2.5:7b",
        apiKey: String = "",
        isEnabled: Bool = false,
        isLocalFallbackEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.providerName = providerName
        self.claudeEndpoint = claudeEndpoint
        self.claudeModelName = claudeModelName
        self.claudeAPIKey = claudeAPIKey
        self.isClaudeEnabled = isClaudeEnabled
        self.endpoint = endpoint
        self.modelName = modelName
        self.apiKey = apiKey
        self.isEnabled = isEnabled
        self.isLocalFallbackEnabled = isLocalFallbackEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isClaudeConfigured: Bool {
        isClaudeEnabledResolved &&
        ClaudeAPIKeyStore.hasAPIKey()
    }

    var isLocalFallbackConfigured: Bool {
        isLocalFallbackEnabledResolved && isEnabled
    }

    var claudeEndpointResolved: String {
        Self.defaultClaudeEndpoint
    }

    var claudeModelNameResolved: String {
        Self.latestSonnetModel
    }

    var claudeAPIKeyResolved: String {
        ClaudeAPIKeyStore.readAPIKey()
    }

    var isClaudeEnabledResolved: Bool {
        isClaudeEnabled ?? true
    }

    var isLocalFallbackEnabledResolved: Bool {
        isLocalFallbackEnabled ?? true
    }
}
