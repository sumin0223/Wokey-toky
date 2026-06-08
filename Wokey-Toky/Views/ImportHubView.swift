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

    @StateObject private var calendarService = CalendarService()

    @State private var showCalendarImport = false
    @State private var showTextImport = false
    @State private var showAppleNotesImport = false
    @State private var showKakaoTalkImport = false

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

            if showTextImport {
                modalBackdrop {
                    showTextImport = false
                } content: {
                    ImportSheetContainer(title: "Text Import") {
                        showTextImport = false
                    } content: {
                        TextImportView()
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
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            Text("Calendar, Text, Apple Notes, KakaoTalk에서 일정과 Task 후보를 가져옵니다.")
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
                    title: "Text",
                    status: "직접 입력",
                    message: "복사한 텍스트나 메모 내용을 붙여넣어 Task 후보를 추출합니다.",
                    systemImage: "doc.text",
                    primaryActionTitle: "텍스트 가져오기",
                    secondaryActionTitle: nil,
                    primaryAction: { showTextImport = true },
                    secondaryAction: nil
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

                    Text("Calendar 후보와 이미 가져온 Text, Apple Notes, KakaoTalk Task를 출처와 함께 확인합니다.")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()
            }

            if importRows.isEmpty {
                ContentUnavailableView(
                    "아직 추출한 후보가 없습니다",
                    systemImage: "tray",
                    description: Text("위의 가져오기 기능을 실행해보세요.")
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
            ["appleCalendar", "appleNotes", "kakaoTalk", "text"].contains($0.source)
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
        case "text":
            return "Text"
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
