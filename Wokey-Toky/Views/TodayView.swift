//
//  TodayView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var captureManager: ContextCaptureManager

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \ScreenContextSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ScreenContextSnapshot]
    
    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]
    
    @Query(sort: \Briefing.createdAt, order: .reverse)
    private var briefings: [Briefing]
    
    @Query(sort: \DailySummary.createdAt, order: .reverse)
    private var summaries: [DailySummary]
    
    @Query(sort: \Suggestion.createdAt, order: .reverse)
    private var suggestions: [Suggestion]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                statusSection

                statsSection

                recentActivitySection

                recentScreenContextSection
                
                tasksSection
                
                briefingSection
                
                summarySection

                suggestionSection
            }
            .padding()
        }
        .navigationTitle("Today")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘의 작업")
                .font(.largeTitle)
                .bold()

            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusSection: some View {
        HStack {
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(captureManager.isCapturing ? .green : .gray)

            Text(captureManager.isCapturing ? "자동 수집 중" : "자동 수집 꺼짐")
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            statCard(
                title: "활동 기록",
                value: "\(todayActivities.count)",
                subtitle: "focus 앱 전환"
            )

            statCard(
                title: "화면 기록",
                value: "\(todaySnapshots.count)",
                subtitle: "화면 맥락 스냅샷"
            )

            statCard(
                title: "최근 앱",
                value: latestActivity?.appName ?? "-",
                subtitle: "마지막 focus"
            )
        }
    }

    private func statCard(
        title: String,
        value: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .bold()
                .lineLimit(1)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 활동")
                .font(.title2)
                .bold()

            if todayActivities.isEmpty {
                Text("아직 오늘 활동 기록이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todayActivities.prefix(5)) { activity in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.appName)
                            .font(.headline)

                        if let windowTitle = activity.windowTitle,
                           !windowTitle.isEmpty {
                            Text(windowTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text(activityTimeRangeText(activity))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var recentScreenContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 화면 맥락")
                .font(.title2)
                .bold()

            if let snapshot = todaySnapshots.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.capturedAt.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let primaryAppName = snapshot.primaryAppName {
                        Text("Primary: \(primaryAppName)")
                            .font(.headline)
                    }

                    let windows = sortedWindows(snapshot.windows)

                    ForEach(windows.prefix(5)) { window in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(window.appName)
                                    .font(.subheadline)
                                    .bold()

                                if !window.windowTitle.isEmpty {
                                    Text(window.windowTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Text(window.classification)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                }
            } else {
                Text("아직 화면 맥락 기록이 없습니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘 점검할 할 일")
                .font(.title2)
                .bold()

            let visibleTasks = prioritizedTasks

            if visibleTasks.isEmpty {
                Text("아직 점검할 할 일이 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleTasks.prefix(5)) { task in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(task.title)
                                .font(.headline)

                            Spacer()

                            Text(statusDisplayName(task.status))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }

                        if let plannedStartAt = task.plannedStartAt {
                            Text("시작: \(plannedStartAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let dueAt = task.dueAt {
                            Text("마감: \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let evidence = task.evidenceSummary,
                           !evidence.isEmpty {
                            Text("근거: \(evidence)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 브리핑")
                .font(.title2)
                .bold()

            if let latest = briefings.first {
                Text(latest.title)
                    .font(.headline)

                Text(latest.content)
                    .font(.body)
                    .lineLimit(6)

                if !latest.questions.isEmpty {
                    Divider()

                    Text("확인 질문")
                        .font(.headline)

                    Text(latest.questions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }

                Text(latest.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("아직 생성된 브리핑이 없습니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘 요약")
                .font(.title2)
                .bold()

            if let summary = todaySummary {
                Text(summary.content)
                    .font(.body)
                    .lineLimit(8)
                    .textSelection(.enabled)

                Text("업데이트: \(summary.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("아직 저장된 오늘 요약이 없습니다. Summary 화면에서 요약을 생성해보세요.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("제안")
                .font(.title2)
                .bold()

            let activeSuggestions = suggestions.filter { !$0.isDismissed }

            if activeSuggestions.isEmpty {
                Text(ruleBasedSuggestion)
                    .font(.body)
                    .foregroundStyle(.primary)
            } else {
                ForEach(activeSuggestions.prefix(3)) { suggestion in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(suggestion.title)
                                .font(.headline)

                            Spacer()

                            Text(suggestion.type)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }

                        Text(suggestion.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var todayActivities: [ActivityEvent] {
        activities.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    private var todaySnapshots: [ScreenContextSnapshot] {
        snapshots.filter { Calendar.current.isDateInToday($0.capturedAt) }
    }

    private var latestActivity: ActivityEvent? {
        todayActivities.first
    }

    private var ruleBasedSuggestion: String {
        if !captureManager.isCapturing {
            return "자동 수집을 시작하면 오늘 작업 흐름과 화면 맥락을 기록할 수 있어요."
        }

        if todayActivities.isEmpty && todaySnapshots.isEmpty {
            return "수집은 켜져 있지만 아직 기록이 거의 없어요. Xcode, Safari, Finder 같은 작업 창을 오가며 테스트해보세요."
        }

        if let latestActivity {
            return "최근에는 \(latestActivity.appName)을 사용 중이에요. 작업이 어느 정도 쌓이면 오늘 요약을 생성할 수 있게 만들 예정입니다."
        }

        return "오늘 작업 기록을 바탕으로 다음 행동을 제안할 수 있게 준비 중입니다."
    }

    private func activityTimeRangeText(_ event: ActivityEvent) -> String {
        let start = event.startedAt.formatted(date: .omitted, time: .shortened)

        if let endedAt = event.endedAt {
            let end = endedAt.formatted(date: .omitted, time: .shortened)
            return "\(start) - \(end)"
        } else {
            return "\(start) - 현재"
        }
    }

    private func sortedWindows(_ windows: [VisibleWindowRecord]) -> [VisibleWindowRecord] {
        windows.sorted { first, second in
            if first.classification == "primary" {
                return true
            }

            if second.classification == "primary" {
                return false
            }

            return first.screenShare > second.screenShare
        }
    }
    
    private var todaySummary: DailySummary? {
        summaries.first {
            Calendar.current.isDateInToday($0.date)
        }
    }
    
    private var prioritizedTasks: [TaskItem] {
        tasks
            .filter { !$0.isCompleted }
            .sorted { first, second in
                let firstScore = taskPriorityScore(first)
                let secondScore = taskPriorityScore(second)

                if firstScore != secondScore {
                    return firstScore > secondScore
                }

                return (first.dueAt ?? .distantFuture) < (second.dueAt ?? .distantFuture)
            }
    }

    private func taskPriorityScore(_ task: TaskItem) -> Int {
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

    private func statusDisplayName(_ rawValue: String) -> String {
        TaskStatus(rawValue: rawValue)?.displayName ?? rawValue
    }
}
