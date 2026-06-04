//
//  TaskEvaluationService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation

final class TaskEvaluationService {
    func evaluateTasks(
        tasks: [TaskItem],
        activities: [ActivityEvent]
    ) -> [TaskEvaluationResult] {
        let activeTasks = tasks.filter {
            !$0.isCompleted &&
            ($0.scheduleType ?? ScheduleType.task.rawValue) == ScheduleType.task.rawValue &&
            $0.status != TaskStatus.deferred.rawValue
        }

        return activeTasks.map { task in
            evaluateTask(task, activities: activities)
        }
    }

    func applyEvaluationResults(_ results: [TaskEvaluationResult]) {
        for result in results {
            let task = result.task

            task.status = result.status.rawValue
            task.evidenceSummary = result.evidenceSummary
            task.needsUserConfirmation = result.needsUserConfirmation

            if result.status == .completed {
                task.isCompleted = true
                task.completedAt = Date()
            }
        }
    }

    private func evaluateTask(
        _ task: TaskItem,
        activities: [ActivityEvent]
    ) -> TaskEvaluationResult {
        let relatedActivities = findRelatedActivities(
            task: task,
            activities: activities
        )

        let totalMinutes = calculateTotalMinutes(relatedActivities)

        if relatedActivities.isEmpty {
            return TaskEvaluationResult(
                task: task,
                status: .pending,
                evidenceSummary: "관련 활동 기록이 없습니다.",
                needsUserConfirmation: isDueSoonOrOverdue(task),
                relatedActivityMinutes: 0
            )
        }

        if totalMinutes < 10 {
            return TaskEvaluationResult(
                task: task,
                status: .pending,
                evidenceSummary: "관련 활동 기록이 \(totalMinutes)분 정도 있습니다. 작업량이 적어 미완료 가능성이 높습니다.",
                needsUserConfirmation: true,
                relatedActivityMinutes: totalMinutes
            )
        }

        if totalMinutes < 60 {
            return TaskEvaluationResult(
                task: task,
                status: .uncertain,
                evidenceSummary: "관련 활동 기록이 \(totalMinutes)분 있습니다. 완료 여부 확인이 필요합니다.",
                needsUserConfirmation: true,
                relatedActivityMinutes: totalMinutes
            )
        }

        return TaskEvaluationResult(
            task: task,
            status: .inProgress,
            evidenceSummary: "관련 활동 기록이 \(totalMinutes)분 이상 있습니다. 진행 흔적이 충분하지만 완료 여부는 확인이 필요합니다.",
            needsUserConfirmation: true,
            relatedActivityMinutes: totalMinutes
        )
    }

    private func findRelatedActivities(
        task: TaskItem,
        activities: [ActivityEvent]
    ) -> [ActivityEvent] {
        let keywords = extractKeywords(from: task)

        guard !keywords.isEmpty else {
            return []
        }

        return activities.filter { activity in
            Calendar.current.isDateInToday(activity.startedAt) &&
            matches(activity: activity, keywords: keywords)
        }
    }

    private func extractKeywords(from task: TaskItem) -> [String] {
        var keywords: [String] = []

        keywords.append(task.title)

        if let detail = task.detail {
            keywords.append(detail)
        }

        if let relatedKeywords = task.relatedKeywords {
            let splitKeywords = relatedKeywords
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            keywords.append(contentsOf: splitKeywords)
        }

        return keywords
            .flatMap { splitTextIntoSearchTokens($0) }
            .filter { $0.count >= 2 }
    }

    private func splitTextIntoSearchTokens(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: " ,./\\-_()[]{}|:;#\n\t"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func matches(
        activity: ActivityEvent,
        keywords: [String]
    ) -> Bool {
        let searchableText = [
            activity.appName,
            activity.windowTitle ?? "",
            activity.url ?? "",
            activity.bundleIdentifier ?? ""
        ]
        .joined(separator: " ")
        .lowercased()

        return keywords.contains { keyword in
            searchableText.contains(keyword.lowercased())
        }
    }

    private func calculateTotalMinutes(_ activities: [ActivityEvent]) -> Int {
        let totalSeconds = activities.reduce(0.0) { partialResult, activity in
            let end = activity.endedAt ?? Date()
            return partialResult + max(0, end.timeIntervalSince(activity.startedAt))
        }

        return Int(totalSeconds / 60)
    }

    private func isDueSoonOrOverdue(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        let now = Date()
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: now
        ) ?? now

        return dueAt <= tomorrow
    }
}
