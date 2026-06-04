//
//  ActivityCaptureService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import AppKit
import CoreGraphics

final class ActivityCaptureService {
    private let accessibilityService = AccessibilityService()
    private let browserURLService = BrowserURLService()

    func captureFrontmostApp() -> CapturedActivity? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appName = app.localizedName ?? "Unknown"
        let bundleIdentifier = app.bundleIdentifier
        let processIdentifier = app.processIdentifier

        let cgWindowTitle = getFrontmostWindowTitleFromCGWindowList(
            processIdentifier: processIdentifier
        )

        let accessibilityTitle = accessibilityService.getFocusedWindowTitle()

        let windowTitle = firstNonEmpty([
            cgWindowTitle,
            accessibilityTitle
        ])
        
        let url = browserURLService.getCurrentURL(for: bundleIdentifier)

        print("Captured app:", appName)
        print("CG title:", cgWindowTitle ?? "nil")
        print("AX title:", accessibilityTitle ?? "nil")
        print("Final title:", windowTitle ?? "nil")

        return CapturedActivity(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            url: url
        )
    }

    private func getFrontmostWindowTitleFromCGWindowList(
        processIdentifier: pid_t
    ) -> String? {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for info in windowInfoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == processIdentifier else {
                continue
            }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0

            guard layer == 0 else {
                continue
            }

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let width = boundsDict["Width"] as? Double,
                  let height = boundsDict["Height"] as? Double else {
                continue
            }

            if width < 40 || height < 40 {
                continue
            }

            if let title = info[kCGWindowName as String] as? String,
               !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return title
            }
        }

        return nil
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            guard let value else {
                continue
            }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }
}

struct CapturedActivity {
    let appName: String
    let bundleIdentifier: String?
    let windowTitle: String?
    let url: String?
}
