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
    
    var claudeAPIKeyResolved: String {
        let storedKey = ClaudeAPIKeyStore.readAPIKey()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !storedKey.isEmpty {
            return storedKey
        }

        return claudeAPIKey?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
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
        isLocalFallbackEnabled: Bool = false,
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
        isClaudeEnabledResolved && ClaudeAPIKeyStore.hasAPIKey()
    }

    var isLocalFallbackConfigured: Bool {
        isLocalFallbackEnabledResolved && isEnabled
    }

    var claudeEndpointResolved: String {
        let value = claudeEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? Self.defaultClaudeEndpoint : value
    }

    var claudeModelNameResolved: String {
        let value = claudeModelName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? Self.latestSonnetModel : value
    }

    var isClaudeEnabledResolved: Bool {
        isClaudeEnabled ?? true
    }

    var isLocalFallbackEnabledResolved: Bool {
        isLocalFallbackEnabled ?? false
    }
}
