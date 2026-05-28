//
//  BrowserURLService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import Foundation
import AppKit

final class BrowserURLService {
    func getCurrentURL(for bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier else {
            return nil
        }

        switch bundleIdentifier {
        case "com.apple.Safari":
            return getSafariURL()

        case "com.google.Chrome":
            return getChromeURL()

        default:
            return nil
        }
    }

    private func getSafariURL() -> String? {
        runAppleScript("""
        tell application "Safari"
            if (count of windows) is 0 then return ""
            return URL of current tab of front window
        end tell
        """)
    }

    private func getChromeURL() -> String? {
        runAppleScript("""
        tell application "Google Chrome"
            if (count of windows) is 0 then return ""
            return URL of active tab of front window
        end tell
        """)
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return nil
        }

        let output = script.executeAndReturnError(&error)

        if let error {
            print("AppleScript error:", error)
            return nil
        }

        let result = output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)

        if result?.isEmpty == true {
            return nil
        }

        return result
    }
}
