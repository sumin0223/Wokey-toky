//
//  BriefingContextBuilder.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation

final class BriefingContextBuilder {
    func buildContext(
        type: BriefingType,
        tasks: [TaskItem],
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot],
        userResponses: [UserTaskResponse]
    ) -> String {
        var lines: [String] = []

        lines.append("# Wokey-Toky 브리핑 생성용 컨텍스트")
        lines.append("")
        lines.append("브리핑 종류: \(type.displayName)")
        lines.append("현재 날짜: \(Date().formatted(date: .complete, time: .shortened))")
        lines.append("")

        lines.append("## 1. 할 일 목록")
        let relevantTasks = tasks
            .filter { shouldIncludeTask($0, type: type) }
            .sorted { first, second in
                (first.dueAt ?? Date.distantFuture) < (second.dueAt ?? Date.distantFuture)
            }

        if relevantTasks.isEmpty {
            lines.append("- 관련 할 일 없음")
        } else {
            for task in relevantTasks {
                lines.append(taskBlock(task))
            }
        }

        lines.append("")
        lines.append("## 2. 오늘 실제 활동 기록")
        let todayActivities = activities
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }

        if todayActivities.isEmpty {
            lines.append("- 오늘 활동 기록 없음")
        } else {
            for activity in todayActivities.prefix(40) {
                lines.append(activityLine(activity))
            }
        }

        lines.append("")
        lines.append("## 3. 최근 화면 맥락")
        let todaySnapshots = snapshots
            .filter { Calendar.current.isDateInToday($0.capturedAt) }
            .sorted { $0.capturedAt < $1.capturedAt }

        if todaySnapshots.isEmpty {
            lines.append("- 화면 맥락 기록 없음")
        } else {
            for snapshot in todaySnapshots.suffix(10) {
                lines.append(snapshotBlock(snapshot))
            }
        }

        lines.append("")
        lines.append("## 4. 사용자 답변 기록")
        let todayResponses = userResponses
            .filter { Calendar.current.isDateInToday($0.createdAt) }
            .sorted { $0.createdAt < $1.createdAt }

        if todayResponses.isEmpty {
            lines.append("- 오늘 사용자 답변 없음")
        } else {
            for response in todayResponses {
                lines.append("- \(response.createdAt.formatted(date: .omitted, time: .shortened)) \(response.taskTitle)")
                lines.append("  - 응답: \(response.responseType)")
                lines.append("  - 반영 상태: \(response.interpretedStatus)")

                if let deferredTo = response.deferredTo {
                    lines.append("  - 연기일: \(deferredTo.formatted(date: .abbreviated, time: .shortened))")
                }

                if let responseText = response.responseText,
                   !responseText.isEmpty {
                    lines.append("  - 원문: \(responseText)")
                }
            }
        }

        lines.append("")
        lines.append("## 5. 작성 지침")
        lines.append("- 사용자가 바로 이해할 수 있는 브리핑 형태로 작성한다.")
        lines.append("- 할 일의 상태, 마감, 실제 활동 근거를 함께 반영한다.")
        lines.append("- 완료 여부가 불확실한 일은 확인 질문으로 분리한다.")
        lines.append("- 이미 사용자가 답변한 내용은 다시 묻지 않는다.")
        lines.append("- 로그에 없는 내용을 단정하지 않는다.")
        lines.append("- 한국어로 작성한다.")

        return lines.joined(separator: "\n")
    }

    private func shouldIncludeTask(
        _ task: TaskItem,
        type: BriefingType
    ) -> Bool {
        if task.isCompleted {
            return type == .evening && isCompletedToday(task)
        }

        switch type {
        case .morning:
            return isDueToday(task) ||
                isDeferredToToday(task) ||
                task.dueAt == nil ||
                task.status == TaskStatus.pending.rawValue ||
                task.status == TaskStatus.inProgress.rawValue ||
                task.status == TaskStatus.uncertain.rawValue

        case .lunch:
            return isDueToday(task) ||
                task.status == TaskStatus.pending.rawValue ||
                task.status == TaskStatus.inProgress.rawValue ||
                task.status == TaskStatus.uncertain.rawValue ||
                task.needsUserConfirmation

        case .evening:
            return true
        }
    }

    private func taskBlock(_ task: TaskItem) -> String {
        var lines: [String] = []

        lines.append("- \(task.title)")
        lines.append("  - 상태: \(task.status)")
        lines.append("  - 출처: \(task.source)")

        if let plannedStartAt = task.plannedStartAt {
            lines.append("  - 시작: \(plannedStartAt.formatted(date: .abbreviated, time: .shortened))")
        }

        if let dueAt = task.dueAt {
            lines.append("  - 마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
        }

        if let detail = task.detail,
           !detail.isEmpty {
            lines.append("  - 상세: \(detail)")
        }

        if let evidence = task.evidenceSummary,
           !evidence.isEmpty {
            lines.append("  - 근거: \(evidence.replacingOccurrences(of: "\n", with: " / "))")
        }

        if task.needsUserConfirmation {
            lines.append("  - 사용자 확인 필요")
        }

        if let deferredTo = task.deferredTo {
            lines.append("  - 연기일: \(deferredTo.formatted(date: .abbreviated, time: .shortened))")
        }

        if let keywords = task.relatedKeywords,
           !keywords.isEmpty {
            lines.append("  - 관련 키워드: \(keywords)")
        }

        return lines.joined(separator: "\n")
    }

    private func activityLine(_ activity: ActivityEvent) -> String {
        var text = "- \(timeRangeText(activity)) \(activity.appName)"

        if let windowTitle = activity.windowTitle,
           !windowTitle.isEmpty {
            text += " / \(windowTitle)"
        }

        if let url = activity.url,
           !url.isEmpty {
            text += " / \(url)"
        }

        return text
    }

    private func snapshotBlock(_ snapshot: ScreenContextSnapshot) -> String {
        var lines: [String] = []

        lines.append("- \(snapshot.capturedAt.formatted(date: .omitted, time: .shortened)) 화면 상태")

        if let primaryAppName = snapshot.primaryAppName {
            lines.append("  - Primary: \(primaryAppName)")
        }

        if let primaryWindowTitle = snapshot.primaryWindowTitle,
           !primaryWindowTitle.isEmpty {
            lines.append("  - Primary Window: \(primaryWindowTitle)")
        }

        let sortedWindows = snapshot.windows.sorted { first, second in
            if first.classification == "primary" {
                return true
            }

            if second.classification == "primary" {
                return false
            }

            return first.screenShare > second.screenShare
        }

        for window in sortedWindows.prefix(5) {
            var line = "  - \(window.classification): \(window.appName)"

            if !window.windowTitle.isEmpty {
                line += " / \(window.windowTitle)"
            }

            line += " / screen \(Int(window.screenShare * 100))%"
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func timeRangeText(_ event: ActivityEvent) -> String {
        let start = event.startedAt.formatted(date: .omitted, time: .shortened)

        if let endedAt = event.endedAt {
            let end = endedAt.formatted(date: .omitted, time: .shortened)
            return "\(start)-\(end)"
        } else {
            return "\(start)-현재"
        }
    }

    private func isDueToday(_ task: TaskItem) -> Bool {
        guard let dueAt = task.dueAt else {
            return false
        }

        return Calendar.current.isDateInToday(dueAt)
    }

    private func isDeferredToToday(_ task: TaskItem) -> Bool {
        guard let deferredTo = task.deferredTo else {
            return false
        }

        return Calendar.current.isDateInToday(deferredTo)
    }

    private func isCompletedToday(_ task: TaskItem) -> Bool {
        guard let completedAt = task.completedAt else {
            return false
        }

        return Calendar.current.isDateInToday(completedAt)
    }
}
