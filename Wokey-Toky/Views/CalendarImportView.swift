//
//  CalendarImportView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import SwiftUI
import SwiftData

struct CalendarImportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @StateObject private var calendarService = CalendarService()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            permissionSection

            eventListSection
        }
        .padding()
        .onAppear {
            calendarService.refreshAuthorizationStatus()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calendar Import")
                .font(.largeTitle)
                .bold()

            Text("macOS 캘린더 앱에 등록된 일정과 마감일을 Wokey-Toky Task로 가져옵니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(calendarService.isAuthorized ? .green : .orange)

                Text("캘린더 권한: \(calendarService.authorizationText)")
                    .font(.headline)

                Spacer()

                Button("권한 요청") {
                    Task {
                        await calendarService.requestAccess()
                    }
                }

                Button("오늘/내일 일정 불러오기") {
                    calendarService.fetchEventsForTodayAndTomorrow()
                }
                .disabled(!calendarService.isAuthorized)
            }

            if let errorMessage = calendarService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("Google Calendar는 macOS 캘린더 앱에 계정을 추가해두면 함께 읽을 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("캘린더 이벤트")
                .font(.title2)
                .bold()

            if calendarService.events.isEmpty {
                ContentUnavailableView(
                    "불러온 일정이 없습니다",
                    systemImage: "calendar",
                    description: Text("권한을 허용한 뒤 오늘/내일 일정 불러오기를 눌러보세요.")
                )
            } else {
                List(calendarService.events) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: CalendarEventItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.headline)

                Spacer()

                Text(event.calendarTitle)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            Text(eventTimeText(event))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let location = event.location,
               !location.isEmpty {
                Text("위치: \(location)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notes = event.notes,
               !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let url = event.url {
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }

            HStack {
                Button(isAlreadyImported(event) ? "이미 가져옴" : "Task로 가져오기") {
                    importEventAsTask(event)
                }
                .disabled(isAlreadyImported(event))

                Spacer()
            }
        }
        .padding(.vertical, 6)
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
            plannedStartAt: event.startDate,
            dueAt: event.endDate,
            externalIdentifier: event.id,
            relatedKeywords: buildKeywords(from: event)
        )

        modelContext.insert(task)
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
}
