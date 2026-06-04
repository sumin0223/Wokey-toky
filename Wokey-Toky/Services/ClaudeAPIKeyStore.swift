//
//  ClaudeAPIKeyStore.swift
//  Wokey-Toky
//
//  Created by Codex on 5/11/26.
//

import Foundation
import Security

enum ClaudeAPIKeyStore {
    private static let service = "com.ssh.Wokey-Toky.claude-api-key"
    private static let account = "anthropic"

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

    static func saveAPIKey(_ apiKey: String) throws {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = trimmedAPIKey.data(using: .utf8) else {
            return
        }

        if hasAPIKey() {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]

            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]

            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

            guard status == errSecSuccess else {
                throw KeychainError.unhandled(status)
            }
        } else {
            let item: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]

            let status = SecItemAdd(item as CFDictionary, nil)

            guard status == errSecSuccess else {
                throw KeychainError.unhandled(status)
            }
        }
    }

    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            return "Keychain 작업에 실패했습니다. OSStatus: \(status)"
        }
    }
}
