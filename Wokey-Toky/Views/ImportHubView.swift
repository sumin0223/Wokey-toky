//
//  ImportHubView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/26/26.
//

import SwiftUI
import SwiftData
import AppKit

struct ImportHubView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @Query(sort: \TaskCandidate.createdAt, order: .reverse)
    private var candidates: [TaskCandidate]

    @StateObject private var calendarService = CalendarService()

    @State private var showCalendarImport = false
    @State private var showAppleNotesImport = false
    @State private var showKakaoTalkImport = false
    @State private var showEmailImport = false

    @State private var candidatePendingDelete: TaskCandidate?
    @State private var showCandidateDeleteConfirmation = false
    @State private var toastMessage: String?
    @State private var editingCandidate: TaskCandidate?
    @State private var editingCandidateTitle = ""
    @State private var editingCandidateDetail = ""
    @State private var editingCandidateDueText = ""
    @State private var recentlyImportedTask: TaskItem?
    @State private var recentlyImportedCandidate: TaskCandidate?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    headerSection
                    sourceSection
                    extractedScheduleSection
                }
                .padding(WokeyDesign.pagePadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Import")
            .onAppear {
                calendarService.refreshAuthorizationStatus()
            }
            .overlay(alignment: .top) {
                if let toastMessage {
                    InAppToastView(message: toastMessage)
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
                        saveContext()
                        showToast("후보를 삭제했습니다.")
                    }
                    candidatePendingDelete = nil
                }

                Button("취소", role: .cancel) {
                    candidatePendingDelete = nil
                }
            } message: {
                Text("삭제한 후보는 Task로 가져올 수 없습니다. 같은 원본을 다시 분석하면 다시 생성될 수 있습니다.")
            }

            if let candidate = editingCandidate {
                modalBackdrop {
                    editingCandidate = nil
                } content: {
                    candidateEditPanel(candidate)
                        .frame(width: 540, height: 380)
                }
            }

            if showCalendarImport {
                modalBackdrop {
                    showCalendarImport = false
                } content: {
                    ImportSheetContainer(title: "Calendar Import") {
                        showCalendarImport = false
                    } content: {
                        CalendarImportView()
                    }
                    .frame(width: 760, height: 680)
                }
            }

            if showAppleNotesImport {
                modalBackdrop {
                    showAppleNotesImport = false
                } content: {
                    ImportSheetContainer(title: "Apple Notes Import") {
                        showAppleNotesImport = false
                    } content: {
                        AppleNotesImportView()
                    }
                    .frame(width: 760, height: 680)
                }
            }

            if showKakaoTalkImport {
                modalBackdrop {
                    showKakaoTalkImport = false
                } content: {
                    ImportSheetContainer(title: "KakaoTalk Import") {
                        showKakaoTalkImport = false
                    } content: {
                        KakaoTalkImportView()
                    }
                    .frame(width: 820, height: 720)
                }
            }

            if showEmailImport {
                modalBackdrop {
                    showEmailImport = false
                } content: {
                    ImportSheetContainer(title: "Email Import") {
                        showEmailImport = false
                    } content: {
                        EmailImportView()
                    }
                    .frame(width: 880, height: 740)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            Text("Calendar, Apple Notes, KakaoTalk, Email에서 일정과 Task 후보를 가져옵니다.")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("연결")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 230), spacing: 18)],
                alignment: .leading,
                spacing: 18
            ) {
                importSourceCard(
                    title: "Calendar",
                    status: calendarAuthorizationText,
                    message: calendarSourceMessage,
                    systemImage: "calendar",
                    primaryActionTitle: calendarService.isAuthorized ? "오늘/내일 불러오기" : "권한 요청",
                    secondaryActionTitle: "설정 열기",
                    primaryAction: {
                        if calendarService.isAuthorized {
                            calendarService.fetchEventsForTodayAndTomorrow()
                        } else {
                            Task {
                                await calendarService.requestAccess()
                            }
                        }
                    },
                    secondaryAction: {
                        openPrivacySettings("Privacy_Calendars")
                    },
                    detailActionTitle: "상세 가져오기",
                    detailAction: { showCalendarImport = true }
                )

                importSourceCard(
                    title: "Apple Notes",
                    status: "상세 가져오기 사용",
                    message: "Apple Notes에서 필요한 메모를 선택해 할 일 후보를 추출합니다.",
                    systemImage: "note.text",
                    primaryActionTitle: "상세 가져오기",
                    secondaryActionTitle: "설정 열기",
                    primaryAction: { showAppleNotesImport = true },
                    secondaryAction: {
                        openPrivacySettings("Privacy_Automation")
                    }
                )

                importSourceCard(
                    title: "KakaoTalk",
                    status: "상세 가져오기 사용",
                    message: "선택한 카카오톡 대화에서 할 일 후보를 추출합니다.",
                    systemImage: "bubble.left.and.bubble.right",
                    primaryActionTitle: "상세 가져오기",
                    secondaryActionTitle: "권한 설정",
                    primaryAction: { showKakaoTalkImport = true },
                    secondaryAction: {
                        openPrivacySettings("Privacy_AllFiles")
                    }
                )

                importSourceCard(
                    title: "Email",
                    status: "Naver Mail · Gmail",
                    message: "지정한 발신자 범위 안에서 받은 메일을 읽고 할 일 후보를 추출합니다.",
                    systemImage: "envelope.badge",
                    primaryActionTitle: "이메일 가져오기",
                    secondaryActionTitle: nil,
                    primaryAction: { showEmailImport = true },
                    secondaryAction: nil
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var extractedScheduleSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("추출한 할일 목록")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text("Calendar 후보와 이미 가져온 Apple Notes, KakaoTalk, Email Task를 출처와 함께 확인합니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()
            }

            if let recentlyImportedTask {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("방금 Task로 가져왔습니다")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(WokeyDesign.muted)

                        Text(recentlyImportedTask.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(WokeyDesign.ink)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button("되돌리기") {
                        undoRecentImport()
                    }
                    .font(.caption)
                }
                .padding(14)
                .background(WokeyDesign.selection)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(WokeyDesign.hairline, lineWidth: 1)
                }
            }

            if importRows.isEmpty && pendingCandidates.isEmpty {
                ContentUnavailableView(
                    "아직 추출한 후보가 없습니다",
                    systemImage: "tray",
                    description: Text("위의 가져오기 기능을 실행해보세요.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(pendingCandidates) { candidate in
                        candidateRowView(candidate)
                    }

                    ForEach(importRows) { row in
                        importRowView(row)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func importSourceCard(
        title: String,
        status: String,
        message: String,
        systemImage: String,
        primaryActionTitle: String,
        secondaryActionTitle: String?,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)?,
        detailActionTitle: String? = nil,
        detailAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(WokeyDesign.blue)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Text(status)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(WokeyDesign.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(WokeyDesign.statusFill)
                .clipShape(Capsule())

            HStack {
                Button(primaryActionTitle, action: primaryAction)

                if let secondaryActionTitle,
                   let secondaryAction {
                    Button(secondaryActionTitle, action: secondaryAction)
                }

                if let detailActionTitle,
                   let detailAction {
                    Button(detailActionTitle, action: detailAction)
                }

                Spacer()
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
        .padding(18)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func candidateRowView(_ candidate: TaskCandidate) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(sourceLabel(for: candidate.sourceType))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(WokeyDesign.statusFill)
                        .clipShape(Capsule())

                    Text("후보")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(WokeyDesign.selection)
                        .clipShape(Capsule())

                    Text("신뢰도 \(candidate.confidence, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Text(candidate.title)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                if let detail = candidate.detail,
                   !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                        .lineLimit(2)
                }

                if let dueText = candidate.dueText,
                   !dueText.isEmpty {
                    Text("추정 시간/마감: \(dueText)")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("수정") {
                    startEditingCandidate(candidate)
                }

                Button("가져오기") {
                    importCandidateAsTask(candidate)
                }
                .disabled(candidate.isImported)

                Button("삭제") {
                    candidatePendingDelete = candidate
                    showCandidateDeleteConfirmation = true
                }
            }
            .font(.caption)
        }
        .padding(16)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
    }

    private func importRowView(_ row: ImportScheduleRow) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(row.sourceLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(WokeyDesign.statusFill)
                        .clipShape(Capsule())

                    Text(row.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                if let detail = row.detail,
                   !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let action = row.importAction {
                Button("가져오기", action: action)
            } else {
                Text("가져옴")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }
        }
        .padding(16)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func startEditingCandidate(_ candidate: TaskCandidate) {
        editingCandidate = candidate
        editingCandidateTitle = candidate.title
        editingCandidateDetail = candidate.detail ?? ""
        editingCandidateDueText = candidate.dueText ?? ""
    }

    private func candidateEditPanel(_ candidate: TaskCandidate) -> some View {
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            TextField("추정 시간/마감", text: $editingCandidateDueText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("저장") {
                    candidate.title = editingCandidateTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    candidate.detail = editingCandidateDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingCandidateDetail
                    candidate.dueText = editingCandidateDueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editingCandidateDueText
                    saveContext()
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
        .background(Color(nsColor: .windowBackgroundColor))
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

        detailParts.append("원본 출처: \(sourceLabel(for: candidate.sourceType))")

        let task = TaskItem(
            title: candidate.title,
            detail: detailParts.joined(separator: "\n"),
            source: candidate.sourceType,
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
            reason: "Import 후보를 Task로 가져왔습니다.",
            source: candidate.sourceType,
            confidence: candidate.confidence
        )
        modelContext.insert(log)

        let notification = AppNotification(
            title: "새 Task가 추가되었습니다",
            message: "\(task.title) · 출처: \(sourceLabel(for: candidate.sourceType))",
            kind: "taskCandidate",
            source: candidate.sourceType,
            relatedTaskTitle: task.title,
            confidence: candidate.confidence
        )
        modelContext.insert(notification)

        recentlyImportedTask = task
        recentlyImportedCandidate = candidate

        saveContext()
        showToast("Task로 추가했습니다: \(task.title)")
    }

    private func undoRecentImport() {
        guard let task = recentlyImportedTask else {
            return
        }

        modelContext.delete(task)
        recentlyImportedCandidate?.isImported = false
        recentlyImportedTask = nil
        recentlyImportedCandidate = nil
        saveContext()
        showToast("가져오기를 되돌렸습니다.")
    }

    private func importEventAsTask(_ event: CalendarEventItem) {
        let detailParts = [
            event.notes,
            event.location.map { "위치: \($0)" },
            event.url?.absoluteString,
            "캘린더: \(event.calendarTitle)"
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        let task = TaskItem(
            title: event.title,
            detail: detailParts.isEmpty ? nil : detailParts.joined(separator: "\n"),
            source: "appleCalendar",
            status: TaskStatus.pending.rawValue,
            scheduleType: ScheduleType.event.rawValue,
            requiresPCWork: false,
            plannedStartAt: event.startDate,
            dueAt: event.endDate,
            externalIdentifier: event.id,
            relatedKeywords: buildKeywords(from: event)
        )

        modelContext.insert(task)
        saveContext()
    }

    private var pendingCandidates: [TaskCandidate] {
        candidates.filter { candidate in
            !candidate.isImported &&
            ["appleNotes", "kakaoTalk", "naverMail", "gmail"].contains(candidate.sourceType)
        }
    }

    private var importRows: [ImportScheduleRow] {
        var rows: [ImportScheduleRow] = []

        for event in calendarService.events where !isAlreadyImported(event) {
            rows.append(
                ImportScheduleRow(
                    sourceLabel: "Calendar",
                    title: event.title,
                    detail: eventTimeText(event),
                    date: event.startDate,
                    importAction: {
                        importEventAsTask(event)
                    }
                )
            )
        }

        for task in importedTasks {
            rows.append(
                ImportScheduleRow(
                    sourceLabel: sourceLabel(for: task.source),
                    title: task.title,
                    detail: task.detail,
                    date: task.dueAt ?? task.plannedStartAt ?? task.createdAt,
                    importAction: nil
                )
            )
        }

        return rows.sorted { first, second in
            first.date < second.date
        }
    }

    private var importedTasks: [TaskItem] {
        tasks.filter {
            ["appleCalendar", "appleNotes", "kakaoTalk", "naverMail", "gmail"].contains($0.source)
        }
    }

    private var calendarAuthorizationText: String {
        calendarService.isAuthorized ? "권한 허용됨" : "권한 필요"
    }

    private var calendarSourceMessage: String {
        if let errorMessage = calendarService.errorMessage {
            return errorMessage
        }

        return calendarService.isAuthorized
            ? "\(calendarService.events.count)개 일정 후보를 읽었습니다."
            : "macOS Calendar 접근 권한이 필요합니다."
    }

    private func sourceLabel(for source: String) -> String {
        switch source {
        case "appleCalendar":
            return "Calendar"
        case "appleNotes":
            return "Apple Notes"
        case "kakaoTalk":
            return "KakaoTalk"
        case "naverMail":
            return "Naver Mail"
        case "gmail":
            return "Gmail"
        default:
            return source
        }
    }

    private func isAlreadyImported(_ event: CalendarEventItem) -> Bool {
        tasks.contains {
            $0.externalIdentifier == event.id
        }
    }

    private func buildKeywords(from event: CalendarEventItem) -> String {
        var keywords: [String] = []

        keywords.append(event.title)

        if let notes = event.notes {
            keywords.append(notes)
        }

        if let location = event.location {
            keywords.append(location)
        }

        if let url = event.url?.absoluteString {
            keywords.append(url)
        }

        keywords.append(event.calendarTitle)

        return keywords
            .joined(separator: ",")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func eventTimeText(_ event: CalendarEventItem) -> String {
        if event.isAllDay {
            return "종일 일정 · \(event.startDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return "\(event.startDate.formatted(date: .abbreviated, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))"
    }

    private func openPrivacySettings(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func saveContext() {
        try? modelContext.save()
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func modalBackdrop<Content: View>(
        dismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.16)) {
                        dismiss()
                    }
                }

            content()
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WokeyDesign.hairline, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 28, x: 0, y: 14)
                .onTapGesture { }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(10)
    }
}

private struct ImportScheduleRow: Identifiable {
    let id = UUID().uuidString
    let sourceLabel: String
    let title: String
    let detail: String?
    let date: Date
    let importAction: (() -> Void)?
}

private struct ImportSheetContainer<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Button {
                    onClose()
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
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(WokeyDesign.quietFill)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
