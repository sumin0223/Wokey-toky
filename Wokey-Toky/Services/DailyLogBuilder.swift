//
//  DailyLogBuilder.swift.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import Foundation

final class DailyLogBuilder {
    func buildTodayLog(
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot],
        tasks: [TaskItem],
        suggestions: [Suggestion]
    ) -> String {
        let todayActivities = activities
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }

        let todaySnapshots = snapshots
            .filter { Calendar.current.isDateInToday($0.capturedAt) }
            .sorted { $0.capturedAt < $1.capturedAt }

        let activeTasks = tasks
            .filter { !$0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }

        let completedTasks = tasks
            .filter {
                guard let completedAt = $0.completedAt else {
                    return false
                }
                return Calendar.current.isDateInToday(completedAt)
            }
            .sorted {
                ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
            }

        let activeSuggestions = suggestions
            .filter { !$0.isDismissed }
            .sorted { $0.createdAt < $1.createdAt }

        var lines: [String] = []

        lines.append("# 오늘 작업 로그")
        lines.append("")
        lines.append("날짜: \(Date().formatted(date: .complete, time: .omitted))")
        lines.append("")

        lines.append("## 1. Focus 활동 기록")
        if todayActivities.isEmpty {
            lines.append("- 기록 없음")
        } else {
            for activity in todayActivities {
                lines.append(activityLine(activity))
            }
        }

        lines.append("")
        lines.append("## 2. 화면 맥락 스냅샷")
        if todaySnapshots.isEmpty {
            lines.append("- 기록 없음")
        } else {
            for snapshot in todaySnapshots {
                lines.append(snapshotBlock(snapshot))
            }
        }

        lines.append("")
        lines.append("## 3. 진행 중인 Tasks")
        if activeTasks.isEmpty {
            lines.append("- 진행 중인 할 일 없음")
        } else {
            for task in activeTasks {
                lines.append("- \(task.title)")
                lines.append("  - 상태: \(task.status)")
                lines.append("  - 출처: \(task.source)")

                if let dueAt = task.dueAt {
                    lines.append("  - 마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                }

                if let detail = task.detail, !detail.isEmpty {
                    lines.append("  - 상세: \(detail)")
                }

                if let evidence = task.evidenceSummary, !evidence.isEmpty {
                    lines.append("  - 근거: \(evidence)")
                }

                if task.needsUserConfirmation {
                    lines.append("  - 사용자 확인 필요")
                }
            }
        }

        lines.append("")
        lines.append("## 4. 오늘 완료한 Tasks")
        if completedTasks.isEmpty {
            lines.append("- 오늘 완료한 할 일 없음")
        } else {
            for task in completedTasks {
                lines.append("- \(task.title)")
            }
        }

        lines.append("")
        lines.append("## 5. 활성 Suggestions")
        if activeSuggestions.isEmpty {
            lines.append("- 활성 제안 없음")
        } else {
            for suggestion in activeSuggestions {
                lines.append("- [\(suggestion.type)] \(suggestion.title)")
                lines.append("  - \(suggestion.message)")
            }
        }

        return lines.joined(separator: "\n")
    }

    func buildMockSummary(from log: String) -> String {
        let hasXcode = log.localizedCaseInsensitiveContains("Xcode")
        let hasBrowser = log.localizedCaseInsensitiveContains("Safari") ||
            log.localizedCaseInsensitiveContains("Chrome") ||
            log.localizedCaseInsensitiveContains("ChatGPT")
        let hasTasks = log.localizedCaseInsensitiveContains("Tasks") ||
            log.localizedCaseInsensitiveContains("할 일")

        var lines: [String] = []

        lines.append("# 오늘 요약")
        lines.append("")
        lines.append("## 주요 작업")
        lines.append("- 오늘의 활동 기록과 화면 맥락 스냅샷을 바탕으로 작업 흐름을 정리했습니다.")

        if hasXcode {
            lines.append("- Xcode 사용 기록이 있어 개발 작업이 주요 흐름으로 보입니다.")
        }

        if hasBrowser {
            lines.append("- 브라우저 또는 ChatGPT 사용 기록이 있어 자료 참고, 검색, 문제 해결 과정이 함께 있었던 것으로 보입니다.")
        }

        lines.append("")
        lines.append("## 화면 맥락")
        lines.append("- primary/mainVisible/peripheral 창 정보를 통해 사용자가 어떤 앱을 중심으로 작업했는지 확인할 수 있습니다.")

        lines.append("")
        lines.append("## 이어서 할 일")
        if hasTasks {
            lines.append("- Tasks에 등록된 항목을 기준으로 다음 작업을 이어가면 좋습니다.")
        } else {
            lines.append("- 다음 단계에서 해야 할 일을 Tasks에 정리해두는 것을 추천합니다.")
        }

        lines.append("")
        lines.append("## 메모")
        lines.append("- 이 요약은 아직 LLM 기반이 아니라 규칙 기반 Mock 요약입니다.")
        lines.append("- 다음 단계에서 LLMService를 연결하면 실제 작업 맥락을 더 자연스럽게 요약할 수 있습니다.")

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

        let time = snapshot.capturedAt.formatted(date: .omitted, time: .shortened)
        lines.append("- \(time) 화면 상태")

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

        for window in sortedWindows.prefix(6) {
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
}
