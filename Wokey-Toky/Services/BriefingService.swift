//
//  BriefingService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation

final class BriefingService {
    func generateBriefing(
        type: BriefingType,
        tasks: [TaskItem],
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot]
    ) -> Briefing {
        switch type {
        case .morning:
            return generateMorningBriefing(
                tasks: tasks,
                activities: activities,
                snapshots: snapshots
            )

        case .lunch:
            return generateLunchBriefing(
                tasks: tasks,
                activities: activities,
                snapshots: snapshots
            )

        case .evening:
            return generateEveningBriefing(
                tasks: tasks,
                activities: activities,
                snapshots: snapshots
            )
        }
    }

    private func generateMorningBriefing(
        tasks: [TaskItem],
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot]
    ) -> Briefing {
        let todayTasks = tasksForTodayOrDeferred(tasks)
        let sortedTasks = sortTasksByUrgency(todayTasks)

        var contentLines: [String] = []
        var questionLines: [String] = []

        contentLines.append("오늘 우선 처리할 일을 정리했어요.")
        contentLines.append("")

        if sortedTasks.isEmpty {
            contentLines.append("오늘 등록된 할 일이 없습니다.")
        } else {
            for (index, task) in sortedTasks.enumerated() {
                contentLines.append("\(index + 1). \(task.title)")
                contentLines.append("- 상태: \(statusDisplayName(task.status))")
                contentLines.append("- 출처: \(task.source)")

                if let plannedStartAt = task.plannedStartAt {
                    contentLines.append("- 시작: \(plannedStartAt.formatted(date: .abbreviated, time: .shortened))")
                }

                if let dueAt = task.dueAt {
                    contentLines.append("- 마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                }

                if let evidence = task.evidenceSummary,
                   !evidence.isEmpty {
                    contentLines.append("- 근거: \(evidence)")
                }

                contentLines.append("")
            }
        }

        let questionTasks = sortedTasks.filter {
            $0.needsUserConfirmation ||
            $0.status == TaskStatus.uncertain.rawValue
        }

        if questionTasks.isEmpty {
            questionLines.append("확인 질문 없음")
        } else {
            for (index, task) in questionTasks.enumerated() {
                questionLines.append("Q\(index + 1). \(questionText(for: task, type: .morning))")
            }
        }

        return Briefing(
            type: BriefingType.morning.rawValue,
            title: "아침 브리핑",
            content: contentLines.joined(separator: "\n"),
            questions: questionLines.joined(separator: "\n\n")
        )
    }

    private func generateLunchBriefing(
        tasks: [TaskItem],
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot]
    ) -> Briefing {
        let unfinishedTasks = tasks
            .filter { !$0.isCompleted }
            .filter {
                $0.status != TaskStatus.deferred.rawValue ||
                isDeferredToToday($0)
            }

        let sortedTasks = sortTasksByUrgency(unfinishedTasks)

        var contentLines: [String] = []
        var questionLines: [String] = []

        contentLines.append("오전 이후 아직 점검이 필요한 일을 정리했어요.")
        contentLines.append("")

        if sortedTasks.isEmpty {
            contentLines.append("현재 남아 있는 할 일이 없습니다.")
        } else {
            for (index, task) in sortedTasks.enumerated() {
                contentLines.append("\(index + 1). \(task.title)")
                contentLines.append("- 상태: \(statusDisplayName(task.status))")

                if let dueAt = task.dueAt {
                    contentLines.append("- 마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                }

                if let evidence = task.evidenceSummary,
                   !evidence.isEmpty {
                    contentLines.append("- 근거: \(evidence)")
                }

                contentLines.append("")
            }
        }

        let questionTasks = sortedTasks.filter {
            $0.needsUserConfirmation ||
            $0.status == TaskStatus.uncertain.rawValue
        }

        if questionTasks.isEmpty {
            questionLines.append("확인 질문 없음")
        } else {
            for (index, task) in questionTasks.enumerated() {
                questionLines.append("Q\(index + 1). \(questionText(for: task, type: .lunch))")
            }
        }

        return Briefing(
            type: BriefingType.lunch.rawValue,
            title: "점심 점검",
            content: contentLines.joined(separator: "\n"),
            questions: questionLines.joined(separator: "\n\n")
        )
    }

    private func generateEveningBriefing(
        tasks: [TaskItem],
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot]
    ) -> Briefing {
        let completedTasks = tasks.filter {
            $0.isCompleted &&
            isCompletedToday($0)
        }

        let unfinishedTasks = tasks.filter {
            !$0.isCompleted
        }

        var contentLines: [String] = []
        var questionLines: [String] = []

        contentLines.append("오늘 완료한 일과 내일로 넘길 일을 정리했어요.")
        contentLines.append("")

        contentLines.append("## 오늘 완료한 일")
        if completedTasks.isEmpty {
            contentLines.append("- 완료된 할 일이 없습니다.")
        } else {
            for task in completedTasks {
                contentLines.append("- \(task.title)")
            }
        }

        contentLines.append("")
        contentLines.append("## 아직 남아 있는 일")
        if unfinishedTasks.isEmpty {
            contentLines.append("- 남아 있는 할 일이 없습니다.")
        } else {
            for task in sortTasksByUrgency(unfinishedTasks) {
                contentLines.append("- \(task.title)")
                contentLines.append("  - 상태: \(statusDisplayName(task.status))")

                if let dueAt = task.dueAt {
                    contentLines.append("  - 마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                }

                if let evidence = task.evidenceSummary,
                   !evidence.isEmpty {
                    contentLines.append("  - 근거: \(evidence)")
                }
            }
        }

        let questionTasks = unfinishedTasks.filter {
            $0.needsUserConfirmation ||
            $0.status == TaskStatus.uncertain.rawValue
        }

        if questionTasks.isEmpty {
            questionLines.append("확인 질문 없음")
        } else {
            for (index, task) in questionTasks.enumerated() {
                questionLines.append("Q\(index + 1). \(questionText(for: task, type: .evening))")
            }
        }

        return Briefing(
            type: BriefingType.evening.rawValue,
            title: "저녁 회고",
            content: contentLines.joined(separator: "\n"),
            questions: questionLines.joined(separator: "\n\n")
        )
    }

    private func tasksForTodayOrDeferred(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { task in
            if task.isCompleted {
                return false
            }

            if let dueAt = task.dueAt,
               Calendar.current.isDateInToday(dueAt) {
                return true
            }

            if isDeferredToToday(task) {
                return true
            }

            if task.dueAt == nil &&
                task.status != TaskStatus.completed.rawValue {
                return true
            }

            return false
        }
    }

    private func sortTasksByUrgency(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { first, second in
            let firstScore = urgencyScore(first)
            let secondScore = urgencyScore(second)

            if firstScore != secondScore {
                return firstScore > secondScore
            }

            return (first.dueAt ?? .distantFuture) < (second.dueAt ?? .distantFuture)
        }
    }

    private func urgencyScore(_ task: TaskItem) -> Int {
        if task.needsUserConfirmation {
            return 100
        }

        if task.status == TaskStatus.uncertain.rawValue {
            return 90
        }

        if let dueAt = task.dueAt {
            if dueAt < Date() {
                return 80
            }

            if Calendar.current.isDateInToday(dueAt) {
                return 70
            }
        }

        if task.status == TaskStatus.inProgress.rawValue {
            return 60
        }

        if task.status == TaskStatus.deferred.rawValue {
            return 30
        }

        return 40
    }

    private func questionText(
        for task: TaskItem,
        type: BriefingType
    ) -> String {
        let evidence = task.evidenceSummary ?? "관련 활동 기록이 충분하지 않습니다."

        switch type {
        case .morning:
            return "\(task.title)은(는) 오늘 점검이 필요합니다. \(evidence) 현재 상태가 완료, 진행 중, 미완료 중 무엇인가요?"

        case .lunch:
            return "\(task.title)은(는) 아직 완료 여부가 확실하지 않습니다. \(evidence) 현재까지 처리된 상태인가요?"

        case .evening:
            return "\(task.title)은(는) 오늘 마무리되었나요, 아니면 내일로 넘겨야 하나요? \(evidence)"
        }
    }

    private func statusDisplayName(_ rawValue: String) -> String {
        TaskStatus(rawValue: rawValue)?.displayName ?? rawValue
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
