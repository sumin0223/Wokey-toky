//
//  AppleNotesImportView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import SwiftUI
import SwiftData

struct AppleNotesImportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskCandidate.createdAt, order: .reverse)
    private var candidates: [TaskCandidate]

    @Query private var llmConfigs: [LLMConfig]

    @State private var notes: [AppleNoteItem] = []
    @State private var selectedNoteIDs: Set<AppleNoteItem.ID> = []
    @State private var noteSearchText = ""
    @State private var visibleNoteLimit = 30
    @State private var isLoadingNotes = false
    @State private var isExtracting = false
    @State private var errorMessage: String?
    @State private var candidatePendingDelete: TaskCandidate?
    @State private var showCandidateDeleteConfirmation = false
    @State private var editingCandidate: TaskCandidate?
    @State private var editingCandidateTitle = ""
    @State private var editingCandidateDetail = ""
    @State private var editingCandidateDueText = ""
    @State private var toastMessage: String?

    private let notesService = AppleNotesService()
    private let llmService = LLMService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
                actionSection
                notesSection
                candidateSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                InAppToastView(message: toastMessage)
            }
        }
        .overlay {
            if let candidate = editingCandidate {
                ZStack {
                    Button {
                        editingCandidate = nil
                    } label: {
                        Rectangle()
                            .fill(Color.black.opacity(0.18))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    candidateEditSheet(candidate)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                .zIndex(20)
            }
        }
        .confirmationDialog(
            "이 후보를 삭제할까요?",
            isPresented: $showCandidateDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("후보 삭제", role: .destructive) {
                if let candidate = candidatePendingDelete {
                    modelContext.delete(candidate)
                    try? modelContext.save()
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


    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(isLoadingNotes ? "불러오는 중..." : "메모 불러오기") {
                    loadNotes()
                }
                .disabled(isLoadingNotes)

                Button(isExtracting ? "추출 중..." : "선택한 메모에서 할 일 후보 추출") {
                    Task {
                        await extractCandidatesFromSelectedNotes()
                    }
                }
                .disabled(isExtracting || selectedNotes.isEmpty)

                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.active)
            }

            Text("메모 목록을 불러오는 단계에서는 Claude를 호출하지 않습니다. Claude API는 사용자가 선택한 메모에서 후보 추출을 누를 때만 사용됩니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)

            Text("기본 화면에는 최근/상위 30개만 보여주고, 검색으로 필요한 메모를 좁혀 선택할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
        }
        .wokeyPanel()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("메모 목록")
                    .font(.title2)
                    .bold()

                Spacer()

                if !selectedNoteIDs.isEmpty {
                    Text("선택됨: \(selectedNoteIDs.count)개")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }

            TextField("메모 제목/본문 검색", text: $noteSearchText)
                .textFieldStyle(.roundedBorder)

            if notes.isEmpty {
                Text("아직 불러온 메모가 없습니다.")
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                let displayNotes = filteredNotes

                ForEach(displayNotes) { note in
                    noteCard(note)
                }

                if filteredAllNotes.count > displayNotes.count {
                    Button("더 보기") {
                        visibleNoteLimit += 30
                    }
                    .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func noteCard(_ note: AppleNoteItem) -> some View {
        let isSelected = selectedNoteIDs.contains(note.id)

        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                if selectedNoteIDs.contains(note.id) {
                    selectedNoteIDs.remove(note.id)
                } else {
                    selectedNoteIDs.insert(note.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.title)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)

                    Spacer()

                    if isSelected {
                        Label("선택됨", systemImage: "checkmark")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(WokeyDesign.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(WokeyDesign.selection)
                            .clipShape(Capsule())
                    }
                }

                if let modifiedAtText = note.modifiedAtText,
                   !modifiedAtText.isEmpty {
                    Text("수정일: \(modifiedAtText)")
                        .font(.caption2)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Text(note.previewText)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? WokeyDesign.selection : WokeyDesign.quietFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? WokeyDesign.blue.opacity(0.35) : WokeyDesign.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 추출 후보")
                .font(.title2)
                .bold()

            let noteCandidates = candidates.filter {
                $0.sourceType == "appleNotes"
            }

            if noteCandidates.isEmpty {
                Text("Apple Notes에서 추출된 후보가 없습니다.")
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                ForEach(noteCandidates) { candidate in
                    candidateCard(candidate)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
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
                    .background(WokeyDesign.statusFill)
                    .clipShape(Capsule())
            }

            if let detail = candidate.detail,
               !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if let dueText = candidate.dueText,
               !dueText.isEmpty {
                Text("추정 시간/마감: \(dueText)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

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
        .padding(16)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
    }

    private var filteredAllNotes: [AppleNoteItem] {
        let search = noteSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !search.isEmpty else {
            return notes
        }

        return notes.filter { note in
            note.title.localizedCaseInsensitiveContains(search) ||
            note.body.localizedCaseInsensitiveContains(search)
        }
    }

    private var filteredNotes: [AppleNoteItem] {
        Array(filteredAllNotes.prefix(visibleNoteLimit))
    }

    private var selectedNotes: [AppleNoteItem] {
        notes.filter { selectedNoteIDs.contains($0.id) }
    }

    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private func loadNotes() {
        isLoadingNotes = true
        errorMessage = nil

        do {
            notes = try notesService.fetchNotes()
            selectedNoteIDs = []
            visibleNoteLimit = 30
            showToast("메모 \(notes.count)개를 불러왔습니다. 분석에는 아직 토큰을 사용하지 않았습니다.")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingNotes = false
    }

    private func extractCandidatesFromSelectedNotes() async {
        let selected = selectedNotes

        guard !selected.isEmpty else {
            errorMessage = "먼저 메모를 선택해주세요."
            return
        }

        guard let config = currentLLMConfig else {
            errorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        isExtracting = true
        errorMessage = nil

        var totalExtracted = 0

        for note in selected {
            let rawText = """
            제목: \(note.title)
            수정일: \(note.modifiedAtText ?? "알 수 없음")

            \(note.body)
            """

            let sourceImport = SourceImport(
                sourceType: "appleNotes",
                title: note.title,
                rawText: rawText
            )
            modelContext.insert(sourceImport)

            do {
                let extracted = try await llmService.extractTaskCandidates(
                    sourceText: rawText,
                    sourceType: "appleNotes",
                    config: config
                )

                for item in extracted {
                    let candidate = TaskCandidate(
                        title: item.title,
                        detail: item.detail,
                        sourceType: "appleNotes",
                        sourceText: rawText.prefix(1200).description,
                        suggestedDueAt: nil,
                        dueText: item.dueText,
                        confidence: item.confidence ?? 0.5
                    )

                    modelContext.insert(candidate)
                    totalExtracted += 1
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        if totalExtracted == 0, errorMessage == nil {
            errorMessage = "추출된 할 일 후보가 없습니다."
            showToast("추출된 후보가 없습니다.")
        } else if totalExtracted > 0 {
            showToast("\(totalExtracted)개의 후보를 추출했습니다.")
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

        detailParts.append("원본 출처: Apple Notes")

        let task = TaskItem(
            title: candidate.title,
            detail: detailParts.joined(separator: "\n"),
            source: "appleNotes",
            status: TaskStatus.pending.rawValue,
            dueAt: candidate.suggestedDueAt,
            relatedKeywords: candidate.title
        )
        task.scheduleType = ScheduleType.task.rawValue

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
            reason: "Apple Notes 후보를 Task로 가져왔습니다.",
            source: "appleNotes",
            confidence: candidate.confidence
        )
        modelContext.insert(log)

        let notification = AppNotification(
            title: "새 Task가 추가되었습니다",
            message: "\(task.title) · 출처: Apple Notes",
            kind: "taskCandidate",
            source: "appleNotes",
            relatedTaskTitle: task.title,
            confidence: candidate.confidence
        )
        modelContext.insert(notification)
        try? modelContext.save()
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
            HStack {
                Text("할 일 후보 수정")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Button {
                    editingCandidate = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WokeyDesign.ink)
                        .frame(width: 28, height: 28)
                        .background(WokeyDesign.quietFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("닫기")
            }

            TextField("제목", text: $editingCandidateTitle)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("상세 설명")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                TextEditor(text: $editingCandidateDetail)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(WokeyDesign.quietFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            TextField("추정 시간/마감", text: $editingCandidateDueText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("저장") {
                    candidate.title = editingCandidateTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    candidate.detail = editingCandidateDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingCandidateDetail
                    candidate.dueText = editingCandidateDueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingCandidateDueText
                    try? modelContext.save()
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
        .padding(24)
        .frame(width: 520, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
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
