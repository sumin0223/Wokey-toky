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
        ScrollView {
            VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
                permissionSection
                eventListSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            calendarService.refreshAuthorizationStatus()
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "캘린더 권한: \(calendarService.authorizationText)",
                    systemImage: calendarService.isAuthorized
                        ? "checkmark.circle.fill"
                        : "exclamationmark.circle"
                )
                .font(.headline)
                .foregroundStyle(calendarService.isAuthorized ? WokeyDesign.blue : WokeyDesign.muted)

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
                    .foregroundStyle(WokeyDesign.active)
            }

            Text("Google Calendar는 macOS 캘린더 앱에 계정을 추가해두면 함께 읽을 수 있습니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
        }
        .wokeyPanel()
    }

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("캘린더 이벤트")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                if !calendarService.events.isEmpty {
                    Text("\(calendarService.events.count)개")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }

            if calendarService.events.isEmpty {
                ContentUnavailableView(
                    "불러온 일정이 없습니다",
                    systemImage: "calendar",
                    description: Text("권한을 허용한 뒤 오늘/내일 일정 불러오기를 눌러보세요.")
                )
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(calendarService.events) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func eventRow(_ event: CalendarEventItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text(event.calendarTitle)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WokeyDesign.statusFill)
                    .clipShape(Capsule())
            }

            Text(eventTimeText(event))
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)

            if let location = event.location,
               !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if let notes = event.notes,
               !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .lineLimit(2)
            }

            if let url = event.url {
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.blue)
                    .lineLimit(1)
            }

            HStack {
                Button(isAlreadyImported(event) ? "이미 가져옴" : "일정으로 가져오기") {
                    importEventAsTask(event)
                }
                .disabled(isAlreadyImported(event))

                Spacer()
            }
        }
        .padding(14)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
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
            plannedStartAt: event.startDate,
            dueAt: event.endDate,
            externalIdentifier: event.id,
            relatedKeywords: buildKeywords(from: event)
        )
        task.scheduleType = ScheduleType.event.rawValue

        modelContext.insert(task)

        let log = TaskChangeLog(
            taskTitle: task.title,
            changeType: "eventCreated",
            previousStatus: nil,
            newStatus: task.status,
            previousIsCompleted: false,
            newIsCompleted: task.isCompleted,
            previousDueAt: nil,
            newDueAt: task.dueAt,
            previousTitle: nil,
            newTitle: task.title,
            reason: "Calendar 일정을 Schedule로 가져왔습니다.",
            source: "appleCalendar",
            confidence: nil
        )
        modelContext.insert(log)

        let notification = AppNotification(
            title: "새 일정이 추가되었습니다",
            message: "\(task.title) · 출처: Calendar",
            kind: "taskCandidate",
            source: "appleCalendar",
            relatedTaskTitle: task.title
        )
        modelContext.insert(notification)

        try? modelContext.save()
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
