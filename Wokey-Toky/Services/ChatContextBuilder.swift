//
//  ChatContextBuilder.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation

final class ChatContextBuilder {
    func buildContext(
        tasks: [TaskItem],
        activities: [ActivityEvent],
        briefings: [Briefing],
        userResponses: [UserTaskResponse],
        workStateSessions: [UserWorkStateSession] = []
    ) -> String {
        var lines: [String] = []

        lines.append("# Wokey-Toky Chat Context")
        lines.append("현재 시각: \(Date().formatted(date: .complete, time: .shortened))")
        lines.append("")

        lines.append("## 1. 현재 할 일")
        let activeTasks = tasks
            .filter { !$0.isCompleted }
            .sorted { first, second in
                (first.dueAt ?? Date.distantFuture) < (second.dueAt ?? Date.distantFuture)
            }

        if activeTasks.isEmpty {
            lines.append("- 현재 남아 있는 할 일이 없습니다.")
        } else {
            for task in activeTasks {
                lines.append(taskLine(task))
            }
        }

        lines.append("")
        lines.append("## 2. 완료된 할 일")
        let completedTasks = tasks
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }

        if completedTasks.isEmpty {
            lines.append("- 완료된 할 일이 없습니다.")
        } else {
            for task in completedTasks.prefix(10) {
                lines.append("- \(task.title)")
                if let completedAt = task.completedAt {
                    lines.append("  - 완료 시각: \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                }
            }
        }

        lines.append("")
        lines.append("## 3. 최근 브리핑")
        if let latestBriefing = briefings.first {
            lines.append("- 제목: \(latestBriefing.title)")
            lines.append("- 생성: \(latestBriefing.createdAt.formatted(date: .abbreviated, time: .shortened))")
            lines.append("- 내용:")
            lines.append(latestBriefing.content.prefix(2000).description)
        } else {
            lines.append("- 최근 브리핑 없음")
        }

        lines.append("")
        lines.append("## 4. 오늘 사용자 상태 기록")
        let todayWorkStateSessions = workStateSessions
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }

        if todayWorkStateSessions.isEmpty {
            lines.append("- 오늘 사용자 상태 전환 기록 없음")
        } else {
            for session in todayWorkStateSessions {
                lines.append(workStateSessionLine(session))
            }
        }

        lines.append("")
        lines.append("## 5. 오늘 활동 기록")
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
        lines.append("## 6. 오늘 사용자 답변 기록")
        let todayResponses = userResponses
            .filter { Calendar.current.isDateInToday($0.createdAt) }
            .sorted { $0.createdAt < $1.createdAt }

        if todayResponses.isEmpty {
            lines.append("- 오늘 사용자 답변 기록 없음")
        } else {
            for response in todayResponses {
                lines.append("- \(response.taskTitle)")
                lines.append("  - 응답 유형: \(response.responseType)")
                lines.append("  - 반영 상태: \(response.interpretedStatus)")
                if let responseText = response.responseText {
                    lines.append("  - 답변: \(responseText)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func workStateSessionLine(_ session: UserWorkStateSession) -> String {
        let stateName = UserWorkState(rawValue: session.state)?.displayName ?? session.state
        let start = session.startedAt.formatted(date: .omitted, time: .shortened)
        let end = session.endedAt?.formatted(date: .omitted, time: .shortened) ?? "현재"

        return "- \(start)-\(end) \(stateName)"
    }

    private func taskLine(_ task: TaskItem) -> String {
        var lines: [String] = []

        lines.append("- \(task.title)")
        lines.append("  - 상태: \(TaskStatus(rawValue: task.status)?.displayName ?? task.status)")
        lines.append("  - 출처: \(task.source)")

        if let plannedStartAt = task.plannedStartAt {
            lines.append("  - 시작: \(plannedStartAt.formatted(date: .abbreviated, time: .shortened))")
        }

        if let dueAt = task.dueAt {
            lines.append("  - 마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
        }

        if let evidence = task.evidenceSummary, !evidence.isEmpty {
            lines.append("  - 근거: \(evidence.replacingOccurrences(of: "\n", with: " / "))")
        }

        if task.needsUserConfirmation {
            lines.append("  - 사용자 확인 필요")
        }

        if let deferredTo = task.deferredTo {
            lines.append("  - 연기일: \(deferredTo.formatted(date: .abbreviated, time: .shortened))")
        }

        return lines.joined(separator: "\n")
    }

    private func activityLine(_ activity: ActivityEvent) -> String {
        var text = "- \(activity.startedAt.formatted(date: .omitted, time: .shortened)) \(activity.appName)"

        if let windowTitle = activity.windowTitle, !windowTitle.isEmpty {
            text += " / \(windowTitle)"
        }

        if let url = activity.url, !url.isEmpty {
            text += " / \(url)"
        }

        return text
    }
}
