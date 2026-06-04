//
//  CalendarImportView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import SwiftUI
import SwiftData
import AppKit

struct CalendarImportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @StateObject private var calendarService = CalendarService()

    @State private var notesFolders: [NotesFolderCandidate] = []
    @State private var selectedNotesFolderIDs: Set<String> = []
    @State private var includeAllNotes = true
    @State private var noteStatus = "설정 필요"
    @State private var noteMessage = "Notes 앱 접근 권한을 허용한 뒤 폴더를 선택하세요."

    @State private var kakaoRooms: [KakaoRoomCandidate] = []
    @State private var selectedKakaoRoomIDs: Set<String> = []
    @State private var kakaoStatus = "설정 필요"
    @State private var kakaoMessage = "KakaoTalk과 대화 데이터 접근 권한을 확인하세요."
    @State private var showAppleNotesDetail = false
    @State private var showKakaoTalkDetail = false
    @State private var showTextImport = false

    private let notesService = NotesImportService()
    private let kakaoService = KakaoTalkImportService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                headerSection
                sourceSection

                if !notesFolders.isEmpty {
                    notesSelectionSection
                }

                if !kakaoRooms.isEmpty {
                    kakaoSelectionSection
                }

                extractedScheduleSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            calendarService.refreshAuthorizationStatus()
        }
        .sheet(isPresented: $showAppleNotesDetail) {
            AppleNotesImportView()
                .frame(minWidth: 760, minHeight: 680)
        }
        .sheet(isPresented: $showKakaoTalkDetail) {
            KakaoTalkImportView()
                .frame(minWidth: 820, minHeight: 720)
        }
        .sheet(isPresented: $showTextImport) {
            TextImportView()
                .frame(minWidth: 760, minHeight: 680)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            Text("Calendar, Notes, KakaoTalk에서 Schedule 후보를 가져오고 필요한 항목만 추가합니다.")
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

            HStack(alignment: .top, spacing: 18) {
                importSourceCard(
                    title: "Calendar",
                    status: calendarService.authorizationText,
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
                    detailActionTitle: "텍스트 가져오기",
                    detailAction: { showTextImport = true }
                )

                importSourceCard(
                    title: "Notes",
                    status: noteStatus,
                    message: noteMessage,
                    systemImage: "note.text",
                    primaryActionTitle: "폴더 확인",
                    secondaryActionTitle: "설정 열기",
                    primaryAction: loadNotesFolders,
                    secondaryAction: {
                        NotesImportService.openAutomationSettings()
                    },
                    detailActionTitle: "상세 가져오기",
                    detailAction: { showAppleNotesDetail = true }
                )

                importSourceCard(
                    title: "KakaoTalk",
                    status: kakaoStatus,
                    message: kakaoMessage,
                    systemImage: "bubble.left.and.bubble.right",
                    primaryActionTitle: "방 찾기",
                    secondaryActionTitle: "권한 설정",
                    primaryAction: scanKakaoRooms,
                    secondaryAction: {
                        KakaoTalkImportService.openFullDiskSettings()
                    },
                    detailActionTitle: "상세 가져오기",
                    detailAction: { showKakaoTalkDetail = true }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var notesSelectionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Notes 가져오기 범위")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text("모든 메모를 가져오거나, 선택한 폴더 안에서만 일정 후보를 찾습니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                Toggle("모든 메모", isOn: $includeAllNotes)
                    .toggleStyle(.switch)
            }

            if !includeAllNotes {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(notesFolders) { folder in
                        Toggle(
                            isOn: Binding(
                                get: { selectedNotesFolderIDs.contains(folder.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedNotesFolderIDs.insert(folder.id)
                                    } else {
                                        selectedNotesFolderIDs.remove(folder.id)
                                    }
                                }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(folder.folderName)
                                    .font(.subheadline)
                                    .foregroundStyle(WokeyDesign.ink)

                                Text(folder.accountName)
                                    .font(.caption2)
                                    .foregroundStyle(WokeyDesign.muted)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }

            HStack {
                Spacer()

                Button("선택한 메모에서 후보 추출") {
                    importNotes()
                }
                .disabled(!includeAllNotes && selectedNotesFolderIDs.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var kakaoSelectionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("KakaoTalk 방 선택")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text("광고성 방은 기본 제외하고, 체크한 방의 대화만 일정 후보로 분석합니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                Button("KakaoTalk 열기") {
                    KakaoTalkImportService.openKakaoTalk()
                }
            }

            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(kakaoRooms) { room in
                    Toggle(
                        isOn: Binding(
                            get: { selectedKakaoRoomIDs.contains(room.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedKakaoRoomIDs.insert(room.id)
                                } else {
                                    selectedKakaoRoomIDs.remove(room.id)
                                }
                            }
                        )
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(room.name)
                                    .font(.headline)
                                    .foregroundStyle(WokeyDesign.ink)

                                Text(room.preview.isEmpty ? "최근 메시지 없음" : room.preview)
                                    .font(.caption)
                                    .foregroundStyle(WokeyDesign.muted)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(room.messageCount)")
                                .font(.caption)
                                .foregroundStyle(WokeyDesign.muted)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(14)
                    .background(WokeyDesign.quietFill)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            HStack {
                Spacer()

                Button("선택한 방에서 후보 추출") {
                    importSelectedKakaoRooms()
                }
                .disabled(selectedKakaoRoomIDs.isEmpty)
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

                    Text("Calendar, Notes, KakaoTalk에서 가져온 후보를 날짜와 함께 확인합니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()
            }

            if importRows.isEmpty {
                ContentUnavailableView(
                    "아직 추출한 후보가 없습니다",
                    systemImage: "tray",
                    description: Text("위의 세 앱을 연결하고 가져오기를 실행해보세요.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(alignment: .leading, spacing: 14) {
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
        secondaryActionTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
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

                Button(secondaryActionTitle, action: secondaryAction)

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

    private func loadNotesFolders() {
        do {
            let folders = try notesService.fetchFolders()
            notesFolders = folders
            selectedNotesFolderIDs = Set(folders.map(\.id))
            noteStatus = folders.isEmpty ? "폴더 없음" : "폴더 선택 가능"
            noteMessage = folders.isEmpty
                ? "Notes에서 읽을 수 있는 폴더를 찾지 못했습니다."
                : "\(folders.count)개 폴더를 찾았습니다. 모든 메모 또는 폴더별로 선택하세요."
        } catch {
            noteStatus = "권한 필요"
            noteMessage = error.localizedDescription
        }
    }

    private func importNotes() {
        do {
            let candidates = try notesService.fetchCandidates(
                selectedFolders: selectedNotesFolderIDs,
                includeAllFolders: includeAllNotes
            )

            for candidate in candidates {
                guard !isAlreadyImported(
                    source: "appleNotes",
                    title: candidate.title,
                    dueAt: candidate.dueAt
                ) else {
                    continue
                }

                let task = TaskItem(
                    title: candidate.title,
                    detail: candidate.body,
                    source: "appleNotes",
                    status: TaskStatus.pending.rawValue,
                    scheduleType: ScheduleType.task.rawValue,
                    requiresPCWork: true,
                    dueAt: candidate.dueAt,
                    externalIdentifier: "notes-\(candidate.folderName)-\(candidate.title)",
                    relatedKeywords: "\(candidate.folderName),\(candidate.title)"
                )

                modelContext.insert(task)
            }

            noteStatus = "\(candidates.count)개 후보 추출"
            noteMessage = candidates.isEmpty
                ? "선택한 메모에서 일정 후보를 찾지 못했습니다."
                : "선택한 Notes 범위에서 후보를 추출했습니다."
        } catch {
            noteStatus = "권한 필요"
            noteMessage = error.localizedDescription
        }
    }

    private func scanKakaoRooms() {
        do {
            let rooms = try kakaoService.fetchRooms()
            kakaoRooms = rooms
            selectedKakaoRoomIDs = Set(rooms.map(\.id))
            kakaoStatus = rooms.isEmpty ? "방 없음" : "방 선택 가능"
            kakaoMessage = rooms.isEmpty
                ? "읽을 수 있는 카카오톡 방을 찾지 못했습니다."
                : "\(rooms.count)개 방을 찾았습니다. 가져올 방만 체크하세요."
        } catch {
            kakaoRooms = []
            selectedKakaoRoomIDs = []
            kakaoStatus = "권한 필요"
            kakaoMessage = error.localizedDescription
        }
    }

    private func importSelectedKakaoRooms() {
        do {
            let selectedRooms = kakaoRooms.filter {
                selectedKakaoRoomIDs.contains($0.id)
            }
            let candidates = try kakaoService.fetchCandidates(from: selectedRooms)

            for candidate in candidates {
                guard !isAlreadyImported(
                    source: "kakaoTalk",
                    title: candidate.message,
                    dueAt: candidate.dueAt
                ) else {
                    continue
                }

                let task = TaskItem(
                    title: candidate.message,
                    detail: "KakaoTalk · \(candidate.roomName)",
                    source: "kakaoTalk",
                    status: TaskStatus.pending.rawValue,
                    scheduleType: ScheduleType.task.rawValue,
                    requiresPCWork: true,
                    dueAt: candidate.dueAt,
                    externalIdentifier: "kakao-\(candidate.roomID)-\(candidate.id)",
                    relatedKeywords: "\(candidate.roomName),KakaoTalk"
                )

                modelContext.insert(task)
            }

            kakaoStatus = "\(candidates.count)개 후보 추출"
            kakaoMessage = candidates.isEmpty
                ? "선택한 방에서 일정 후보를 찾지 못했습니다."
                : "선택한 카카오톡 방에서 후보를 추출했습니다."
        } catch {
            kakaoStatus = "권한 필요"
            kakaoMessage = error.localizedDescription
        }
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
            ["appleCalendar", "appleNotes", "kakaoTalk"].contains($0.source)
        }
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
            return "Notes"
        case "kakaoTalk":
            return "KakaoTalk"
        default:
            return source
        }
    }

    private func isAlreadyImported(_ event: CalendarEventItem) -> Bool {
        tasks.contains {
            $0.externalIdentifier == event.id
        }
    }

    private func isAlreadyImported(
        source: String,
        title: String,
        dueAt: Date
    ) -> Bool {
        tasks.contains { task in
            task.source == source &&
            task.title == title &&
            task.dueAt.map { Calendar.current.isDate($0, inSameDayAs: dueAt) } == true
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
}

private struct ImportScheduleRow: Identifiable {
    let id = UUID().uuidString
    let sourceLabel: String
    let title: String
    let detail: String?
    let date: Date
    let importAction: (() -> Void)?
}
