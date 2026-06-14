//
//  KakaoTalkChatAliasStore.swift
//  Wokey-Toky
//
//  Created by 조수민 on 6/2/26.
//

import Foundation

enum KakaoTalkChatAliasStore {
    private static let key = "kakao_chat_aliases"
    private static let excludedKey = "kakao_chat_excluded_rooms"
    private static let pinnedKey = "kakao_chat_pinned_rooms"

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

    static func readExcludedRooms() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: excludedKey) ?? [])
    }

    static func isExcluded(chatId: String) -> Bool {
        readExcludedRooms().contains(chatId)
    }

    static func setExcluded(_ excluded: Bool, for chatId: String) {
        var rooms = readExcludedRooms()

        if excluded {
            rooms.insert(chatId)
        } else {
            rooms.remove(chatId)
        }

        UserDefaults.standard.set(Array(rooms), forKey: excludedKey)
    }

    static func readPinnedRooms() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: pinnedKey) ?? [])
    }

    static func isPinned(chatId: String) -> Bool {
        readPinnedRooms().contains(chatId)
    }

    static func setPinned(_ pinned: Bool, for chatId: String) {
        var rooms = readPinnedRooms()

        if pinned {
            rooms.insert(chatId)
        } else {
            rooms.remove(chatId)
        }

        UserDefaults.standard.set(Array(rooms), forKey: pinnedKey)
    }
}
