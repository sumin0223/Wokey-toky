//
//  SuggestionsView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import SwiftUI
import SwiftData

struct SuggestionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Suggestion.createdAt, order: .reverse)
    private var suggestions: [Suggestion]

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \ScreenContextSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ScreenContextSnapshot]

    private let suggestionEngine = SuggestionEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            activeSuggestionsSection

            dismissedSuggestionsSection
        }
        .padding()
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggestions")
                    .font(.largeTitle)
                    .bold()

                Text("작업 기록을 바탕으로 다음 행동을 제안합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("제안 생성") {
                generateSuggestions()
            }
        }
    }

    private var activeSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("활성 제안")
                .font(.title2)
                .bold()

            if activeSuggestions.isEmpty {
                ContentUnavailableView(
                    "현재 제안이 없습니다",
                    systemImage: "lightbulb",
                    description: Text("제안 생성 버튼을 눌러보세요.")
                )
            } else {
                List {
                    ForEach(activeSuggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }
        }
    }

    private var dismissedSuggestionsSection: some View {
        Group {
            if !dismissedSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("숨긴 제안")
                        .font(.title2)
                        .bold()

                    List {
                        ForEach(dismissedSuggestions.prefix(10)) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.title)
                    .font(.headline)

                Spacer()

                Text(suggestion.type)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Text(suggestion.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(suggestion.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !suggestion.isConvertedToTask {
                    Button("Task로 전환") {
                        convertToTask(suggestion)
                    }
                }

                Button(suggestion.isDismissed ? "다시 표시" : "숨기기") {
                    toggleDismiss(suggestion)
                }

                Button("삭제") {
                    deleteSuggestion(suggestion)
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }

    private var activeSuggestions: [Suggestion] {
        suggestions.filter { !$0.isDismissed }
    }

    private var dismissedSuggestions: [Suggestion] {
        suggestions.filter { $0.isDismissed }
    }

    private func generateSuggestions() {
        suggestionEngine.generateSuggestions(
            activities: activities,
            snapshots: snapshots,
            existingSuggestions: suggestions,
            modelContext: modelContext
        )
    }

    private func convertToTask(_ suggestion: Suggestion) {
        let task = TaskItem(
            title: suggestion.title,
            detail: suggestion.message,
            source: "suggestion",
            status: TaskStatus.pending.rawValue,
            needsUserConfirmation: false
        )

        modelContext.insert(task)
        suggestion.isConvertedToTask = true
    }

    private func toggleDismiss(_ suggestion: Suggestion) {
        suggestion.isDismissed.toggle()
    }

    private func deleteSuggestion(_ suggestion: Suggestion) {
        modelContext.delete(suggestion)
    }
}
