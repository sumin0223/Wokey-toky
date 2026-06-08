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
    @State private var availableFolders: [AppleNotesFolderInfo] = []
    @State private var showExtractionScope = false
    @State private var selectedFolderKeys: Set<String> = []
    @State private var selectedNoteIDs: Set<AppleNoteItem.ID> = []
    @State private var noteSearchText = ""
    @State private var visibleNoteLimit = 8
    @State private var isLoadingNotes = false
    @State private var isLoadingFolders = false
    @State private var isExtracting = false
    @State private var errorMessage: String?
    @State private var candidatePendingDelete: TaskCandidate?
    @State private var showCandidateDeleteConfirmation = false
    @State private var editingCandidate: TaskCandidate?
    @State private var editingCandidateTitle = ""
    @State private var editingCandidateDetail = ""
    @State private var editingCandidateDueText = ""
    @State private var toastMessage: String?
    @State private var showSelectionDetailPanel = false

    private let notesService = AppleNotesService()
    private let llmService = LLMService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
                actionSection
                folderSection
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
        .overlay(alignment: .bottomTrailing) {
            if showExtractionScope || !selectedNoteIDs.isEmpty {
                VStack(alignment: .trailing, spacing: 12) {
                    if showSelectionDetailPanel {
                        selectionDetailPanel
                    }

                    selectionFloatingSummary
                }
                .padding(.trailing, 26)
                .padding(.bottom, 24)
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

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("메모 추출 범위")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text("토글을 켜면 Notes 폴더만 먼저 불러옵니다. 폴더를 선택하면 해당 폴더 안의 메모만 불러옵니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                if !availableFolders.isEmpty {
                    Text("선택됨: \(selectedFolderKeys.count)/\(availableFolders.count)")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }

            if !showExtractionScope {
                Text("상단의 메모 추출 범위 선택 토글을 켜면 Notes 폴더 목록을 불러옵니다.")
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
            } else if isLoadingFolders {
                Text("Notes 폴더를 불러오는 중입니다...")
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
            } else if availableFolders.isEmpty {
                Text("표시할 수 있는 폴더 정보가 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(availableFolderRows) { folder in
                        Toggle(
                            isOn: Binding(
                                get: { selectedFolderKeys.contains(folder.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedFolderKeys.insert(folder.id)
                                    } else {
                                        selectedFolderKeys.remove(folder.id)
                                    }

                                    selectedNoteIDs = []
                                    notes = []
                                    visibleNoteLimit = 8
                                }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(folder.title)
                                    .font(.subheadline)
                                    .foregroundStyle(WokeyDesign.ink)
                                    .lineLimit(1)

                                Text("\(folder.noteCount)개 메모")
                                    .font(.caption2)
                                    .foregroundStyle(WokeyDesign.muted)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .padding(12)
                        .background(WokeyDesign.quietFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(WokeyDesign.hairline, lineWidth: 1)
                        }
                    }
                }

                HStack {
                    Button("폴더 전체 선택") {
                        selectedFolderKeys = Set(availableFolderRows.map(\.id))
                        notes = []
                        selectedNoteIDs = []
                        visibleNoteLimit = 8
                    }
                    .font(.caption)

                    Button("폴더 전체 해제") {
                        selectedFolderKeys = []
                        notes = []
                        selectedNoteIDs = []
                        visibleNoteLimit = 8
                    }
                    .font(.caption)

                    Button(isLoadingNotes ? "메모 불러오는 중..." : "선택 폴더 메모 불러오기") {
                        loadNotesForSelectedFolders()
                    }
                    .font(.caption)
                    .disabled(selectedFolderKeys.isEmpty || isLoadingNotes)

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var actionSection: some View {
        HStack(spacing: 14) {
            Toggle(
                "메모 추출 범위 선택",
                isOn: Binding(
                    get: { showExtractionScope },
                    set: { isOn in
                        showExtractionScope = isOn

                        if isOn && availableFolders.isEmpty && !isLoadingFolders {
                            loadFolders()
                        }

                        if !isOn {
                            selectedFolderKeys = []
                            selectedNoteIDs = []
                            notes = []
                            noteSearchText = ""
                            visibleNoteLimit = 8
                        }
                    }
                )
            )
            .toggleStyle(.switch)
            .disabled(isLoadingNotes || isLoadingFolders)

            Text(showExtractionScope ? "ON · 후보 선택" : "OFF · 전체 불러오기")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(WokeyDesign.muted)

            if !showExtractionScope {
                Button(isLoadingNotes ? "불러오는 중..." : "전체 메모 불러오기") {
                    loadAllNotes()
                }
                .font(.caption)
                .disabled(isLoadingNotes)
            }

            if isLoadingFolders || isLoadingNotes {
                Text(isLoadingFolders ? "폴더 불러오는 중..." : "메모 불러오는 중...")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.active)
                    .lineLimit(1)
            }

            Spacer()
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

            if !showExtractionScope && notes.isEmpty {
                Text("전체 메모를 불러오려면 상단의 ‘전체 메모 불러오기’를 눌러주세요.")
                    .foregroundStyle(WokeyDesign.muted)
            } else if notes.isEmpty {
                Text(selectedFolderKeys.isEmpty ? "먼저 분석할 메모 폴더를 선택해주세요." : "선택한 폴더의 메모를 불러오려면 ‘선택 폴더 메모 불러오기’를 눌러주세요.")
                    .foregroundStyle(WokeyDesign.muted)
            } else if selectedFolderKeys.isEmpty {
                Text("먼저 분석할 메모 폴더를 선택해주세요.")
                    .foregroundStyle(WokeyDesign.muted)
            } else if notesInSelectedFolders.isEmpty {
                Text("선택한 폴더 안에 표시할 메모가 없습니다.")
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                let displayNotes = filteredNotes

                HStack {
                    Button("표시된 메모 전체 선택") {
                        selectedNoteIDs.formUnion(displayNotes.map(\.id))
                    }
                    .font(.caption)

                    Button("선택 폴더 메모 전체 선택") {
                        selectedNoteIDs.formUnion(filteredAllNotes.map(\.id))
                    }
                    .font(.caption)

                    Button("표시된 메모 선택 해제") {
                        selectedNoteIDs.subtract(displayNotes.map(\.id))
                    }
                    .font(.caption)

                    Spacer()

                    Text("표시: \(displayNotes.count)/\(filteredAllNotes.count)")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(displayNotes) { note in
                            noteCard(note)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if filteredAllNotes.count > displayNotes.count {
                    Button("더 보기") {
                        visibleNoteLimit += 8
                    }
                    .font(.caption)
                }

                HStack {
                    Spacer()

                    Button(isExtracting ? "추출 중..." : "선택한 메모에서 후보 추출") {
                        Task {
                            await extractCandidatesFromSelectedNotes()
                        }
                    }
                    .disabled(isExtracting || selectedNotes.isEmpty)
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

                Text(note.folderDisplayText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.muted)

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
        let baseNotes = notesForCurrentMode

        guard !search.isEmpty else {
            return baseNotes
        }

        return baseNotes.filter { note in
            note.title.localizedCaseInsensitiveContains(search) ||
            note.body.localizedCaseInsensitiveContains(search) ||
            note.folderDisplayText.localizedCaseInsensitiveContains(search)
        }
    }

    private var filteredNotes: [AppleNoteItem] {
        Array(filteredAllNotes.prefix(visibleNoteLimit))
    }

    private var selectedNotes: [AppleNoteItem] {
        notesForCurrentMode.filter { selectedNoteIDs.contains($0.id) }
    }

    private var notesForCurrentMode: [AppleNoteItem] {
        showExtractionScope ? notesInSelectedFolders : notes
    }
    private var notesInSelectedFolders: [AppleNoteItem] {
        notes.filter { selectedFolderKeys.contains(folderKey(for: $0)) }
    }

    private var availableFolderRows: [AppleNoteFolderRow] {
        availableFolders.map { folder in
            AppleNoteFolderRow(
                id: folder.id,
                title: folder.displayText,
                noteCount: folder.noteCount
            )
        }
    }

    private var selectionFloatingSummary: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                showSelectionDetailPanel.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.blue)

                    Text("현재 선택")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.ink)

                    Spacer()

                    Image(systemName: showSelectionDetailPanel ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Text(selectionSummaryText)
                    .font(.caption2)
                    .foregroundStyle(WokeyDesign.muted)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 250, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(WokeyDesign.hairline, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var selectionDetailPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("선택한 메모")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Button("비우기") {
                    selectedNoteIDs = []
                }
                .font(.caption2)
            }

            if selectedNotes.isEmpty {
                Text("아직 선택한 메모가 없습니다.")
                    .font(.caption2)
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(selectedNotes.prefix(20)) { note in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(WokeyDesign.ink)
                                    .lineLimit(1)

                                Text(note.folderDisplayText)
                                    .font(.caption2)
                                    .foregroundStyle(WokeyDesign.muted)
                                    .lineLimit(1)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(WokeyDesign.quietFill)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        if selectedNotes.count > 20 {
                            Text("외 \(selectedNotes.count - 20)개")
                                .font(.caption2)
                                .foregroundStyle(WokeyDesign.muted)
                        }
                    }
                }
                .frame(maxHeight: 260)

                Button(isExtracting ? "추출 중..." : "선택한 메모에서 후보 추출") {
                    Task {
                        await extractCandidatesFromSelectedNotes()
                    }
                }
                .disabled(isExtracting || selectedNotes.isEmpty)
                .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 20, x: 0, y: 10)
    }

    private var selectionSummaryText: String {
        let selectedFolders = availableFolders
            .filter { selectedFolderKeys.contains($0.id) }
            .map(\.displayText)

        let folderText = selectedFolders.isEmpty
            ? "선택한 폴더 없음"
            : selectedFolders.prefix(3).joined(separator: ", ") + (selectedFolders.count > 3 ? " 외 \(selectedFolders.count - 3)개" : "")

        return "폴더 \(selectedFolderKeys.count)개 · 메모 \(selectedNoteIDs.count)개\n\(folderText)"
    }

    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private func loadAllNotes() {
        isLoadingNotes = true
        errorMessage = nil
        showExtractionScope = false
        selectedFolderKeys = []
        selectedNoteIDs = []
        visibleNoteLimit = 8

        do {
            notes = try notesService.fetchNotes()
            showToast("전체 메모 \(notes.count)개를 불러왔습니다.")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingNotes = false
    }

    private func loadFolders() {
        isLoadingFolders = true
        errorMessage = nil

        do {
            availableFolders = try notesService.fetchFolders()
            selectedFolderKeys = []
            notes = []
            selectedNoteIDs = []
            visibleNoteLimit = 8
            showToast("Notes 폴더 \(availableFolders.count)개를 불러왔습니다.")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingFolders = false
    }

    private func loadNotesForSelectedFolders() {
        guard !selectedFolderKeys.isEmpty else {
            notes = []
            selectedNoteIDs = []
            return
        }

        isLoadingNotes = true
        errorMessage = nil

        do {
            notes = try notesService.fetchNotes(in: selectedFolderKeys)
            removeSelectedNotesOutsideSelectedFolders()
            showToast("선택한 폴더에서 메모 \(notes.count)개를 불러왔습니다.")
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingNotes = false
    }

    private func loadNotes() {
        loadFolders()
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
            폴더: \(note.folderDisplayText)
            제목: \(note.title)
            수정일: \(note.modifiedAtText ?? "알 수 없음")

            \(note.body)
            """

            let sourceImport = SourceImport(
                sourceType: "appleNotes",
                title: "\(note.folderDisplayText) · \(note.title)",
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
                    guard !isDuplicateCandidate(
                        title: item.title,
                        dueText: item.dueText,
                        sourceText: "\(note.folderDisplayText)\n\(rawText.prefix(1200))"
                    ) else {
                        continue
                    }

                    let candidate = TaskCandidate(
                        title: item.title,
                        detail: item.detail,
                        sourceType: "appleNotes",
                        sourceText: "\(note.folderDisplayText)\n\(rawText.prefix(1200))",
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

    private func isDuplicateCandidate(
        title: String,
        dueText: String?,
        sourceText: String
    ) -> Bool {
        let normalizedTitle = normalizeCandidateText(title)
        let normalizedDueText = normalizeCandidateText(dueText ?? "")
        let sourceFingerprint = normalizeCandidateText(String(sourceText.prefix(260)))

        return candidates.contains { candidate in
            guard candidate.sourceType == "appleNotes" else {
                return false
            }

            let candidateTitle = normalizeCandidateText(candidate.title)
            let candidateDueText = normalizeCandidateText(candidate.dueText ?? "")
            let candidateSourceFingerprint = normalizeCandidateText(String(candidate.sourceText.prefix(260)))

            return candidateTitle == normalizedTitle &&
            candidateDueText == normalizedDueText &&
            candidateSourceFingerprint == sourceFingerprint
        }
    }

    private func normalizeCandidateText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
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
    
    private func folderKey(for note: AppleNoteItem) -> String {
        "\(note.accountName ?? "")::\(note.folderName ?? "")"
    }

    private func removeSelectedNotesOutsideSelectedFolders() {
        let allowedNoteIDs = Set(notesInSelectedFolders.map(\.id))
        selectedNoteIDs = selectedNoteIDs.intersection(allowedNoteIDs)
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


private struct AppleNoteFolderRow: Identifiable, Hashable {
    let id: String
    let title: String
    let noteCount: Int
}
