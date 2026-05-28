//
//  TaskChangeLog.swift
//  Wokey-Toky
//

import Foundation
import SwiftData

@Model
final class TaskChangeLog {
    var taskTitle: String
    // statusChanged / taskCreated / taskEdited
    var changeType: String
    var previousStatus: String?
    var newStatus: String?
    var previousIsCompleted: Bool
    var newIsCompleted: Bool
    var previousCompletedAt: Date?
    var newCompletedAt: Date?
    var previousDeferredTo: Date?
    var newDeferredTo: Date?
    var previousDueAt: Date?
    var newDueAt: Date?
    var previousTitle: String?
    var newTitle: String?
    var reason: String
    var source: String
    var confidence: Double?
    var isRolledBack: Bool
    var createdAt: Date
    var rolledBackAt: Date?

    init(
        taskTitle: String,
        changeType: String = "statusChanged",
        previousStatus: String? = nil,
        newStatus: String? = nil,
        previousIsCompleted: Bool = false,
        newIsCompleted: Bool = false,
        previousCompletedAt: Date? = nil,
        newCompletedAt: Date? = nil,
        previousDeferredTo: Date? = nil,
        newDeferredTo: Date? = nil,
        previousDueAt: Date? = nil,
        newDueAt: Date? = nil,
        previousTitle: String? = nil,
        newTitle: String? = nil,
        reason: String,
        source: String = "manual",
        confidence: Double? = nil,
        isRolledBack: Bool = false,
        createdAt: Date = Date(),
        rolledBackAt: Date? = nil
    ) {
        self.taskTitle = taskTitle
        self.changeType = changeType
        self.previousStatus = previousStatus
        self.newStatus = newStatus
        self.previousIsCompleted = previousIsCompleted
        self.newIsCompleted = newIsCompleted
        self.previousCompletedAt = previousCompletedAt
        self.newCompletedAt = newCompletedAt
        self.previousDeferredTo = previousDeferredTo
        self.newDeferredTo = newDeferredTo
        self.previousDueAt = previousDueAt
        self.newDueAt = newDueAt
        self.previousTitle = previousTitle
        self.newTitle = newTitle
        self.reason = reason
        self.source = source
        self.confidence = confidence
        self.isRolledBack = isRolledBack
        self.createdAt = createdAt
        self.rolledBackAt = rolledBackAt
    }
}
