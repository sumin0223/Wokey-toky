//
//  AccessibilityService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import Foundation
import ApplicationServices
import AppKit

final class AccessibilityService {
    func isAccessibilityPermissionGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func getFocusedWindowTitle() -> String? {
        guard AXIsProcessTrusted() else {
            return nil
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

        // 1순위: focused window
        if let title = getWindowTitle(
            appElement: appElement,
            attribute: kAXFocusedWindowAttribute as CFString
        ) {
            return title
        }

        // 2순위: main window
        if let title = getWindowTitle(
            appElement: appElement,
            attribute: kAXMainWindowAttribute as CFString
        ) {
            return title
        }

        // 3순위: window list에서 첫 번째 창 제목
        var windowsValue: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        )

        if windowsResult == .success,
           let windows = windowsValue as? [AXUIElement] {
            for window in windows {
                var titleValue: CFTypeRef?
                let titleResult = AXUIElementCopyAttributeValue(
                    window,
                    kAXTitleAttribute as CFString,
                    &titleValue
                )

                if titleResult == .success,
                   let title = titleValue as? String,
                   !title.isEmpty {
                    return title
                }
            }
        }

        return nil
    }
    
    private func getWindowTitle(
        appElement: AXUIElement,
        attribute: CFString
    ) -> String? {
        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            attribute,
            &windowValue
        )

        guard result == .success,
              let windowValue else {
            return nil
        }

        let windowElement = windowValue as! AXUIElement

        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            windowElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        guard titleResult == .success,
              let title = titleValue as? String,
              !title.isEmpty else {
            return nil
        }

        return title
    }
}
