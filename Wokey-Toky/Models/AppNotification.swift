//
//  AppNotification.swift
//  Wokey-Toky
//

import Foundation
import SwiftData

@Model
final class AppNotification {
    var title: String
    var message: String
    // taskChange / taskCandidate / rollback / system / kakaoTalk
    var kind: String
    var source: String
    var relatedTaskTitle: String?
    var suggestedStatus: String?
    var confidence: Double?
    var isResolved: Bool
    var createdAt: Date
    var resolvedAt: Date?

    init(
        title: String,
        message: String,
        kind: String = "system",
        source: String = "app",
        relatedTaskTitle: String? = nil,
        suggestedStatus: String? = nil,
        confidence: Double? = nil,
        isResolved: Bool = false,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.title = title
        self.message = message
        self.kind = kind
        self.source = source
        self.relatedTaskTitle = relatedTaskTitle
        self.suggestedStatus = suggestedStatus
        self.confidence = confidence
        self.isResolved = isResolved
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
}
