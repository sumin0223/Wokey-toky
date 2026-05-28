//
//  ClaudeAPIKeyStore.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/14/26.
//

import Foundation

enum ClaudeAPIKeyStore {
    private static let key = "claude_api_key"

    static func saveAPIKey(_ apiKey: String) {
        UserDefaults.standard.set(apiKey, forKey: key)
    }

    static func readAPIKey() -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }

    static func hasAPIKey() -> Bool {
        !readAPIKey().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func deleteAPIKey() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
