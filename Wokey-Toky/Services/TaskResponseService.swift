//
//  TaskResponseService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation
import SwiftData

final class TaskResponseService {
    private func snapshot(_ task: TaskItem) -> (status: String, isCompleted: Bool, completedAt: Date?, deferredTo: Date?, dueAt: Date?) {
        (task.status, task.isCompleted, task.completedAt, task.deferredTo, task.dueAt)
    }

    private func recordTaskChange(
        task: TaskItem,
        previous: (status: String, isCompleted: Bool, completedAt: Date?, deferredTo: Date?, dueAt: Date?),
        reason: String,
        source: String,
        confidence: Double? = nil,
        modelContext: ModelContext
    ) {
        guard previous.status != task.status ||
                previous.isCompleted != task.isCompleted ||
                previous.completedAt != task.completedAt ||
                previous.deferredTo != task.deferredTo ||
                previous.dueAt != task.dueAt else {
            return
        }

        let log = TaskChangeLog(
            taskTitle: task.title,
            changeType: "statusChanged",
            previousStatus: previous.status,
            newStatus: task.status,
            previousIsCompleted: previous.isCompleted,
            newIsCompleted: task.isCompleted,
            previousCompletedAt: previous.completedAt,
            newCompletedAt: task.completedAt,
            previousDeferredTo: previous.deferredTo,
            newDeferredTo: task.deferredTo,
            previousDueAt: previous.dueAt,
            newDueAt: task.dueAt,
            previousTitle: task.title,
            newTitle: task.title,
            reason: reason,
            source: source,
            confidence: confidence
        )
        modelContext.insert(log)

        let notification = AppNotification(
            title: "Task 상태 변경",
            message: "\(task.title): \(previous.status) → \(task.status)",
            kind: "taskChange",
            source: source,
            relatedTaskTitle: task.title,
            suggestedStatus: task.status,
            confidence: confidence
        )
        modelContext.insert(notification)
    }

    func markCompleted(
        task: TaskItem,
        modelContext: ModelContext
    ) {
        let previous = snapshot(task)

        task.status = TaskStatus.completed.rawValue
        task.isCompleted = true
        task.completedAt = Date()
        task.needsUserConfirmation = false
        task.evidenceSummary = appendResponseNote(
            existing: task.evidenceSummary,
            note: "사용자가 완료로 확정했습니다."
        )

        recordTaskChange(
            task: task,
            previous: previous,
            reason: "사용자가 완료 버튼으로 확정했습니다.",
            source: "manual",
            modelContext: modelContext
        )

        insertResponse(
            task: task,
            responseType: "completed",
            interpretedStatus: TaskStatus.completed.rawValue,
            deferredTo: nil,
            modelContext: modelContext
        )
    }

    func markInProgress(
        task: TaskItem,
        modelContext: ModelContext
    ) {
        let previous = snapshot(task)

        task.status = TaskStatus.inProgress.rawValue
        task.isCompleted = false
        task.completedAt = nil
        task.needsUserConfirmation = false
        task.evidenceSummary = appendResponseNote(
            existing: task.evidenceSummary,
            note: "사용자가 진행 중으로 확정했습니다."
        )

        recordTaskChange(
            task: task,
            previous: previous,
            reason: "사용자가 진행 중 버튼으로 확정했습니다.",
            source: "manual",
            modelContext: modelContext
        )

        insertResponse(
            task: task,
            responseType: "inProgress",
            interpretedStatus: TaskStatus.inProgress.rawValue,
            deferredTo: nil,
            modelContext: modelContext
        )
    }

    func markPending(
        task: TaskItem,
        modelContext: ModelContext
    ) {
        let previous = snapshot(task)

        task.status = TaskStatus.pending.rawValue
        task.isCompleted = false
        task.completedAt = nil
        task.needsUserConfirmation = false
        task.evidenceSummary = appendResponseNote(
            existing: task.evidenceSummary,
            note: "사용자가 아직 미완료로 확정했습니다."
        )

        recordTaskChange(
            task: task,
            previous: previous,
            reason: "사용자가 미완료 버튼으로 확정했습니다.",
            source: "manual",
            modelContext: modelContext
        )

        insertResponse(
            task: task,
            responseType: "pending",
            interpretedStatus: TaskStatus.pending.rawValue,
            deferredTo: nil,
            modelContext: modelContext
        )
    }

    func deferToTomorrow(
        task: TaskItem,
        modelContext: ModelContext
    ) {
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Date()
        ) ?? Date()

        deferTask(
            task: task,
            deferredTo: tomorrow,
            reason: "사용자가 내일로 넘겼습니다.",
            source: "manual",
            responseText: nil,
            modelContext: modelContext
        )
    }

    func applyInterpretation(
        _ interpretation: TaskResponseInterpretation,
        to task: TaskItem,
        modelContext: ModelContext
    ) {
        switch interpretation.status {
        case .completed:
            markCompletedWithText(
                task: task,
                responseText: interpretation.responseText,
                confidence: interpretation.confidence,
                modelContext: modelContext
            )

        case .inProgress:
            markInProgressWithText(
                task: task,
                responseText: interpretation.responseText,
                confidence: interpretation.confidence,
                modelContext: modelContext
            )

        case .pending:
            markPendingWithText(
                task: task,
                responseText: interpretation.responseText,
                confidence: interpretation.confidence,
                modelContext: modelContext
            )

        case .deferred:
            deferTask(
                task: task,
                deferredTo: interpretation.deferredTo,
                reason: "사용자 답변 자동 해석으로 연기 처리: \(interpretation.responseText)",
                source: "naturalLanguage",
                responseText: interpretation.responseText,
                confidence: interpretation.confidence,
                modelContext: modelContext
            )

        case .uncertain:
            let previous = snapshot(task)
            task.status = TaskStatus.uncertain.rawValue
            task.needsUserConfirmation = true
            task.evidenceSummary = appendResponseNote(
                existing: task.evidenceSummary,
                note: "사용자 답변 해석 결과 확인 필요: \(interpretation.responseText)"
            )
            recordTaskChange(
                task: task,
                previous: previous,
                reason: "사용자 답변 해석 결과 확인 필요: \(interpretation.responseText)",
                source: "naturalLanguage",
                confidence: interpretation.confidence,
                modelContext: modelContext
            )
        }
    }

    private func markCompletedWithText(
        task: TaskItem,
        responseText: String,
        confidence: Double?,
        modelContext: ModelContext
    ) {
        let previous = snapshot(task)

        task.status = TaskStatus.completed.rawValue
        task.isCompleted = true
        task.completedAt = Date()
        task.needsUserConfirmation = false
        task.evidenceSummary = appendResponseNote(
            existing: task.evidenceSummary,
            note: "사용자 답변으로 완료 확정: \(responseText)"
        )

        recordTaskChange(
            task: task,
            previous: previous,
            reason: "사용자 답변 자동 해석으로 완료 처리: \(responseText)",
            source: "naturalLanguage",
            confidence: confidence,
            modelContext: modelContext
        )

        insertResponse(
            task: task,
            responseType: "completed",
            interpretedStatus: TaskStatus.completed.rawValue,
            deferredTo: nil,
            responseText: responseText,
            modelContext: modelContext
        )
    }

    private func markInProgressWithText(
        task: TaskItem,
        responseText: String,
        confidence: Double?,
        modelContext: ModelContext
    ) {
        let previous = snapshot(task)

        task.status = TaskStatus.inProgress.rawValue
        task.isCompleted = false
        task.completedAt = nil
        task.needsUserConfirmation = false
        task.evidenceSummary = appendResponseNote(
            existing: task.evidenceSummary,
            note: "사용자 답변으로 진행 중 확정: \(responseText)"
        )

        recordTaskChange(
            task: task,
            previous: previous,
            reason: "사용자 답변 자동 해석으로 진행 중 처리: \(responseText)",
            source: "naturalLanguage",
            confidence: confidence,
            modelContext: modelContext
        )

        insertResponse(
            task: task,
            responseType: "inProgress",
            interpretedStatus: TaskStatus.inProgress.rawValue,
            deferredTo: nil,
            responseText: responseText,
            modelContext: modelContext
        )
    }

    private func markPendingWithText(
        task: TaskItem,
        responseText: String,
        confidence: Double?,
        modelContext: ModelContext
    ) {
        let previous = snapshot(task)

        task.status = TaskStatus.pending.rawValue
        task.isCompleted = false
        task.completedAt = nil
        task.needsUserConfirmation = false
        task.evidenceSummary = appendResponseNote(
            existing: task.evidenceSummary,
            note: "사용자 답변으로 미완료 확정: \(responseText)"
        )

        recordTaskChange(
            task: task,
            previous: previous,
            reason: "사용자 답변 자동 해석으로 미완료 처리: \(responseText)",
            source: "naturalLanguage",
            confidence: confidence,
            modelContext: modelContext
        )

        insertResponse(
            task: task,
            responseType: "pending",
            interpretedStatus: TaskStatus.pending.rawValue,
            deferredTo: nil,
            responseText: responseText,
            modelContext: modelContext
        )
    }

    private func deferTask(
        task: TaskItem,
        deferredTo: Date?,
        reason: String,
        source: String,
        responseText: String?,
        confidence: Double? = nil,
        modelContext: ModelContext
    ) {
        let previous = snapshot(task)
        let finalDeferredTo = deferredTo ?? Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Date()
        ) ?? Date()

        task.status = TaskStatus.deferred.rawValue
        task.isCompleted = false
        task.completedAt = nil
        task.needsUserConfirmation = false
        task.deferredTo = finalDeferredTo
        task.evidenceSummary = appendResponseNote(
            existing: task.evidenceSummary,
            note: reason
        )

        recordTaskChange(
            task: task,
            previous: previous,
            reason: reason,
            source: source,
            confidence: confidence,
            modelContext: modelContext
        )

        insertResponse(
            task: task,
            responseType: "deferred",
            interpretedStatus: TaskStatus.deferred.rawValue,
            deferredTo: finalDeferredTo,
            responseText: responseText,
            modelContext: modelContext
        )
    }

    private func insertResponse(
        task: TaskItem,
        responseType: String,
        interpretedStatus: String,
        deferredTo: Date?,
        responseText: String? = nil,
        modelContext: ModelContext
    ) {
        let response = UserTaskResponse(
            taskTitle: task.title,
            responseType: responseType,
            responseText: responseText,
            interpretedStatus: interpretedStatus,
            deferredTo: deferredTo
        )

        modelContext.insert(response)
    }

    private func appendResponseNote(
        existing: String?,
        note: String
    ) -> String {
        let timestamp = Date().formatted(date: .omitted, time: .shortened)

        if let existing,
           !existing.isEmpty {
            return "\(existing)\n[\(timestamp)] \(note)"
        } else {
            return "[\(timestamp)] \(note)"
        }
    }
}
