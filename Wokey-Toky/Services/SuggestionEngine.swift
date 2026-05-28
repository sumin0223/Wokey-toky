//
//  SuggestionEngine.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import Foundation
import SwiftData

@MainActor
final class SuggestionEngine {
    func generateSuggestions(
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot],
        existingSuggestions: [Suggestion],
        modelContext: ModelContext
    ) {
        let todayActivities = activities.filter {
            Calendar.current.isDateInToday($0.startedAt)
        }

        let todaySnapshots = snapshots.filter {
            Calendar.current.isDateInToday($0.capturedAt)
        }

        if shouldSuggestStartCapture(
            activities: todayActivities,
            snapshots: todaySnapshots,
            existingSuggestions: existingSuggestions
        ) {
            insertSuggestion(
                title: "자동 수집을 시작해볼까요?",
                message: "아직 오늘 기록이 거의 없어요. 자동 수집을 켜면 작업 흐름과 화면 맥락을 기록할 수 있습니다.",
                type: "capture",
                modelContext: modelContext
            )
        }

        if shouldSuggestDailySummary(
            activities: todayActivities,
            snapshots: todaySnapshots,
            existingSuggestions: existingSuggestions
        ) {
            insertSuggestion(
                title: "오늘 작업을 요약해볼까요?",
                message: "오늘 활동과 화면 기록이 어느 정도 쌓였어요. 지금까지의 작업을 요약하면 다음에 이어서 하기 쉬워집니다.",
                type: "summary",
                modelContext: modelContext
            )
        }

        if shouldSuggestDevelopmentCheckpoint(
            activities: todayActivities,
            snapshots: todaySnapshots,
            existingSuggestions: existingSuggestions
        ) {
            insertSuggestion(
                title: "개발 작업 체크포인트를 남겨볼까요?",
                message: "Xcode와 ChatGPT를 함께 사용한 기록이 반복적으로 보입니다. 지금까지 구현한 내용을 할 일이나 요약으로 정리해두면 좋아요.",
                type: "checkpoint",
                modelContext: modelContext
            )
        }

        if shouldSuggestTaskExtraction(
            activities: todayActivities,
            snapshots: todaySnapshots,
            existingSuggestions: existingSuggestions
        ) {
            insertSuggestion(
                title: "다음 할 일을 정리해볼까요?",
                message: "작업 기록이 쌓였습니다. 지금 단계에서 이어서 해야 할 일을 Tasks에 추가해두는 것을 추천합니다.",
                type: "task",
                modelContext: modelContext
            )
        }
    }

    private func shouldSuggestStartCapture(
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot],
        existingSuggestions: [Suggestion]
    ) -> Bool {
        guard activities.isEmpty && snapshots.isEmpty else {
            return false
        }

        return !hasRecentSuggestion(
            type: "capture",
            existingSuggestions: existingSuggestions,
            withinMinutes: 60
        )
    }

    private func shouldSuggestDailySummary(
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot],
        existingSuggestions: [Suggestion]
    ) -> Bool {
        guard activities.count >= 5 || snapshots.count >= 5 else {
            return false
        }

        return !hasRecentSuggestion(
            type: "summary",
            existingSuggestions: existingSuggestions,
            withinMinutes: 60
        )
    }

    private func shouldSuggestDevelopmentCheckpoint(
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot],
        existingSuggestions: [Suggestion]
    ) -> Bool {
        let hasXcode = activities.contains {
            $0.appName.localizedCaseInsensitiveContains("Xcode")
        }

        let hasChatOrBrowser = activities.contains {
            $0.appName.localizedCaseInsensitiveContains("Safari") ||
            $0.appName.localizedCaseInsensitiveContains("Chrome") ||
            $0.appName.localizedCaseInsensitiveContains("ChatGPT")
        }

        guard hasXcode && hasChatOrBrowser else {
            return false
        }

        return !hasRecentSuggestion(
            type: "checkpoint",
            existingSuggestions: existingSuggestions,
            withinMinutes: 60
        )
    }

    private func shouldSuggestTaskExtraction(
        activities: [ActivityEvent],
        snapshots: [ScreenContextSnapshot],
        existingSuggestions: [Suggestion]
    ) -> Bool {
        guard activities.count >= 8 || snapshots.count >= 8 else {
            return false
        }

        return !hasRecentSuggestion(
            type: "task",
            existingSuggestions: existingSuggestions,
            withinMinutes: 90
        )
    }

    private func insertSuggestion(
        title: String,
        message: String,
        type: String,
        modelContext: ModelContext
    ) {
        let suggestion = Suggestion(
            title: title,
            message: message,
            type: type,
            source: "rule"
        )

        modelContext.insert(suggestion)
    }

    private func hasRecentSuggestion(
        type: String,
        existingSuggestions: [Suggestion],
        withinMinutes: Int
    ) -> Bool {
        let cutoff = Calendar.current.date(
            byAdding: .minute,
            value: -withinMinutes,
            to: Date()
        ) ?? Date()

        return existingSuggestions.contains {
            $0.type == type && $0.createdAt >= cutoff
        }
    }
}
