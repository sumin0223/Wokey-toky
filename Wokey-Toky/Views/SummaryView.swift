//
//  SummaryView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import SwiftUI
import SwiftData

struct SummaryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \ScreenContextSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ScreenContextSnapshot]

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @Query(sort: \Suggestion.createdAt, order: .reverse)
    private var suggestions: [Suggestion]

    @Query(sort: \DailySummary.createdAt, order: .reverse)
    private var summaries: [DailySummary]
    
    @Query private var llmConfigs: [LLMConfig]

    @State private var sourceLog: String = ""
    @State private var generatedSummary: String = ""
    @State private var isGeneratingLLMSummary = false
    @State private var llmErrorMessage: String?

    private let logBuilder = DailyLogBuilder()
    private let llmService = LLMService()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            actionSection
            
            errorSection

            contentSection
        }
        .padding()
        .onAppear {
            buildLogPreview()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Summary")
                    .font(.largeTitle)
                    .bold()

                Text("오늘의 작업 로그를 요약하고 저장합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var actionSection: some View {
        HStack {
            Button("오늘 로그 새로고침") {
                buildLogPreview()
            }

            Button("Mock 요약 생성") {
                generateMockSummary()
            }
            
            Button(isGeneratingLLMSummary ? "LLM 요약 생성 중..." : "LLM 요약 생성") {
                Task {
                    await generateLLMSummary()
                }
            }
            .disabled(isGeneratingLLMSummary)

            Button("요약 저장") {
                saveSummary()
            }
            .disabled(generatedSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()

            if let latest = latestTodaySummary {
                Text("마지막 저장: \(latest.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var errorSection: some View {
        Group {
            if let llmErrorMessage {
                Text(llmErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var contentSection: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("오늘 로그")
                    .font(.title2)
                    .bold()

                ScrollView {
                    Text(sourceLog.isEmpty ? "아직 생성된 로그가 없습니다." : sourceLog)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("요약")
                    .font(.title2)
                    .bold()

                ScrollView {
                    Text(generatedSummary.isEmpty ? "Mock 요약 생성 버튼을 눌러보세요." : generatedSummary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var latestTodaySummary: DailySummary? {
        summaries.first {
            Calendar.current.isDateInToday($0.date)
        }
    }

    private func buildLogPreview() {
        sourceLog = logBuilder.buildTodayLog(
            activities: activities,
            snapshots: snapshots,
            tasks: tasks,
            suggestions: suggestions
        )
    }

    private func generateMockSummary() {
        if sourceLog.isEmpty {
            buildLogPreview()
        }

        generatedSummary = logBuilder.buildMockSummary(from: sourceLog)
    }

    private func saveSummary() {
        let trimmedSummary = generatedSummary.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSummary.isEmpty else {
            return
        }

        if let existingSummary = latestTodaySummary {
            existingSummary.title = "오늘 요약"
            existingSummary.content = trimmedSummary
            existingSummary.sourceLog = sourceLog
            existingSummary.updatedAt = Date()
        } else {
            let summary = DailySummary(
                date: Date(),
                title: "오늘 요약",
                content: trimmedSummary,
                sourceLog: sourceLog
            )

            modelContext.insert(summary)
        }
    }
    
    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private func generateLLMSummary() async {
        if sourceLog.isEmpty {
            buildLogPreview()
        }

        guard let config = currentLLMConfig else {
            llmErrorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        isGeneratingLLMSummary = true
        llmErrorMessage = nil

        do {
            let result = try await llmService.generateDailySummary(
                log: sourceLog,
                config: config
            )

            generatedSummary = result
        } catch {
            llmErrorMessage = error.localizedDescription
        }

        isGeneratingLLMSummary = false
    }
}
