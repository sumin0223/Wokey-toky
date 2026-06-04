//
//  ActivityEvent.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

// 어떤 앱을 언제부터 어떤 창 제목으로 보고 있었는지

import Foundation
import SwiftData

@Model
final class ActivityEvent {
    var appName: String
    var bundleIdentifier: String?
    var windowTitle: String?
    var capturedText: String?
    var url: String?
    var startedAt: Date
    var endedAt: Date?

    init(
        appName: String,
        bundleIdentifier: String?,
        windowTitle: String? = nil,
        capturedText: String? = nil,
        url: String? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.capturedText = capturedText
        self.url = url
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
