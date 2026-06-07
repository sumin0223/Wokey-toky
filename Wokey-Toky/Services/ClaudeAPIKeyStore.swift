//
//  ClaudeAPIKeyStore.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/14/26.
//

import Foundation
import Security

enum ClaudeAPIKeyStore {
    private static let service = "com.ssh.Wokey-Toky.claude-api-key"
    private static let account = "anthropic"

    static func saveAPIKey(_ apiKey: String) {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAPIKey.isEmpty,
              let data = trimmedAPIKey.data(using: .utf8) else {
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let existingStatus = SecItemCopyMatching(query as CFDictionary, nil)

        if existingStatus == errSecSuccess {
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]

            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else if existingStatus == errSecItemNotFound {
            let item: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]

            SecItemAdd(item as CFDictionary, nil)
        }
    }

    static func readAPIKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return ""
        }

        return apiKey
    }

    static func hasAPIKey() -> Bool {
        !readAPIKey().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
