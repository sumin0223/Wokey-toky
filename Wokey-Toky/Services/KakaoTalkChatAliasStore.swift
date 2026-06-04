//
//  KakaoTalkChatAliasStore.swift
//  Wokey-Toky
//
//  Created by 조수민 on 6/2/26.
//

import Foundation

enum KakaoTalkChatAliasStore {
    private static let key = "kakao_chat_aliases"

    static func readAliases() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    static func alias(for chatId: String) -> String? {
        let value = readAliases()[chatId]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let value, !value.isEmpty {
            return value
        }

        return nil
    }

    static func saveAlias(_ alias: String, for chatId: String) {
        var aliases = readAliases()
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            aliases.removeValue(forKey: chatId)
        } else {
            aliases[chatId] = trimmed
        }

        UserDefaults.standard.set(aliases, forKey: key)
    }

    static func deleteAlias(for chatId: String) {
        var aliases = readAliases()
        aliases.removeValue(forKey: chatId)
        UserDefaults.standard.set(aliases, forKey: key)
    }
}

