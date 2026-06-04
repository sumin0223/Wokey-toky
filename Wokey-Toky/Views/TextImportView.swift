//
//  TextImportView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import SwiftUI
import SwiftData

struct TextImportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskCandidate.createdAt, order: .reverse)
    private var candidates: [TaskCandidate]

    @Query private var llmConfigs: [LLMConfig]

    @State private var sourceTitle = "붙여넣은 텍스트"
    @State private var sourceText = ""
    @State private var isExtracting = false
    @State private var errorMessage: String?
    @State private var candidatePendingDelete: TaskCandidate?
    @State private var showCandidateDeleteConfirmation = false
    @State private var editingCandidate: TaskCandidate?
    @State private var editingCandidateTitle = ""
    @State private var editingCandidateDetail = ""
    @State private var editingCandidateDueText = ""
    @State private var toastMessage: String?

    private let llmService = LLMService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                inputSection
                candidateSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                InAppToastView(message: toastMessage)
            }
        }
        .sheet(item: $editingCandidate) { candidate in
            candidateEditSheet(candidate)
        }
        .confirmationDialog(
            "이 후보를 삭제할까요?",
            isPresented: $showCandidateDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("후보 삭제", role: .destructive) {
                if let candidate = candidatePendingDelete {
                    modelContext.delete(candidate)
                    showToast("후보를 삭제했습니다.")
                }
                candidatePendingDelete = nil
            }

            Button("취소", role: .cancel) {
                candidatePendingDelete = nil
            }
        } message: {
            Text("삭제한 후보는 Task로 가져올 수 없습니다. 원문을 다시 불러오면 새로 추출할 수 있습니다.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Text Import")
                .font(.largeTitle)
                .bold()

            Text("메모나 대화 내용을 붙여넣으면 Wokey-Toky가 할 일 후보를 추출합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("원본 텍스트")
                .font(.title2)
                .bold()

            TextField("출처 제목", text: $sourceTitle)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $sourceText)
                .frame(minHeight: 180)
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Button(isExtracting ? "추출 중..." : "할 일 후보 추출") {
                    Task {
                        await extractCandidates()
                    }
                }
                .disabled(
                    isExtracting ||
                    sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Button("입력 초기화") {
                    sourceText = ""
                    errorMessage = nil
                    showToast("입력을 초기화했습니다.")
                }

                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("Apple Notes와 KakaoTalk 연동 전 단계입니다. 먼저 텍스트 붙여넣기 기반으로 Task 추출 흐름을 안정화합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("추출된 할 일 후보")
                .font(.title2)
                .bold()

            if candidates.isEmpty {
                Text("아직 추출된 후보가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(candidates) { candidate in
                    candidateCard(candidate)
                }
            }
        }
    }

    private func candidateCard(_ candidate: TaskCandidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(candidate.title)
                    .font(.headline)

                Spacer()

                Text("신뢰도 \(candidate.confidence, specifier: "%.2f")")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            if let detail = candidate.detail,
               !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let dueText = candidate.dueText,
               !dueText.isEmpty {
                Text("추정 시간/마감: \(dueText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("출처: \(candidate.sourceType)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(candidate.sourceText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .textSelection(.enabled)

            HStack {
                Button("수정") {
                    startEditingCandidate(candidate)
                }

                Button(candidate.isImported ? "이미 Task로 가져옴" : "Task로 가져오기") {
                    importCandidateAsTask(candidate)
                }
                .disabled(candidate.isImported)

                Button("후보 삭제") {
                    candidatePendingDelete = candidate
                    showCandidateDeleteConfirmation = true
                }

                Spacer()
            }
            .font(.caption)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private func extractCandidates() async {
        guard let config = currentLLMConfig else {
            errorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        isExtracting = true
        errorMessage = nil

        let trimmedText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)

        let sourceImport = SourceImport(
            sourceType: "pasteText",
            title: sourceTitle,
            rawText: trimmedText
        )
        modelContext.insert(sourceImport)

        do {
            let extracted = try await llmService.extractTaskCandidates(
                sourceText: trimmedText,
                sourceType: "pasteText",
                config: config
            )

            if extracted.isEmpty {
                errorMessage = "추출된 할 일 후보가 없습니다."
                showToast("추출된 후보가 없습니다.")
            } else {
                for item in extracted {
                    let candidate = TaskCandidate(
                        title: item.title,
                        detail: item.detail,
                        sourceType: "pasteText",
                        sourceText: trimmedText,
                        suggestedDueAt: nil,
                        dueText: item.dueText,
                        confidence: item.confidence ?? 0.5
                    )

                    modelContext.insert(candidate)
                }

                sourceText = ""
                showToast("\(extracted.count)개의 후보를 추출했습니다.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isExtracting = false
    }

    private func importCandidateAsTask(_ candidate: TaskCandidate) {
        var detailParts: [String] = []

        if let detail = candidate.detail,
           !detail.isEmpty {
            detailParts.append(detail)
        }

        if let dueText = candidate.dueText,
           !dueText.isEmpty {
            detailParts.append("추정 시간/마감: \(dueText)")
        }

        detailParts.append("원본 출처: \(candidate.sourceType)")

        let task = TaskItem(
            title: candidate.title,
            detail: detailParts.joined(separator: "\n"),
            source: candidate.sourceType,
            status: TaskStatus.pending.rawValue,
            dueAt: candidate.suggestedDueAt,
            relatedKeywords: candidate.title
        )

        modelContext.insert(task)
        candidate.isImported = true

        let log = TaskChangeLog(
            taskTitle: task.title,
            changeType: "taskCreated",
            previousStatus: nil,
            newStatus: task.status,
            previousIsCompleted: false,
            newIsCompleted: task.isCompleted,
            previousDueAt: nil,
            newDueAt: task.dueAt,
            previousTitle: nil,
            newTitle: task.title,
            reason: "붙여넣기 텍스트 후보를 Task로 가져왔습니다.",
            source: "pasteText",
            confidence: candidate.confidence
        )
        modelContext.insert(log)

        let notification = AppNotification(
            title: "새 Task가 추가되었습니다",
            message: "\(task.title) · 출처: 붙여넣기 텍스트",
            kind: "taskCandidate",
            source: "pasteText",
            relatedTaskTitle: task.title,
            confidence: candidate.confidence
        )
        modelContext.insert(notification)
        showToast("Task로 추가했습니다: \(task.title)")
    }

    private func startEditingCandidate(_ candidate: TaskCandidate) {
        editingCandidate = candidate
        editingCandidateTitle = candidate.title
        editingCandidateDetail = candidate.detail ?? ""
        editingCandidateDueText = candidate.dueText ?? ""
    }

    private func candidateEditSheet(_ candidate: TaskCandidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("할 일 후보 수정")
                .font(.title2)
                .bold()

            TextField("제목", text: $editingCandidateTitle)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("상세 설명")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $editingCandidateDetail)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            TextField("추정 시간/마감", text: $editingCandidateDueText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("저장") {
                    candidate.title = editingCandidateTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    candidate.detail = editingCandidateDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingCandidateDetail
                    candidate.dueText = editingCandidateDueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingCandidateDueText
                    editingCandidate = nil
                    showToast("후보를 수정했습니다.")
                }
                .disabled(editingCandidateTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("취소") {
                    editingCandidate = nil
                }

                Spacer()
            }
        }
        .padding()
        .frame(width: 540, height: 380)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
