//
//  CalendarService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation
import EventKit
import Combine

@MainActor
final class CalendarService: ObservableObject {
    @Published var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var events: [CalendarEventItem] = []
    @Published var errorMessage: String?

    private let eventStore = EKEventStore()

    func refreshAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async {
        errorMessage = nil

        do {
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)

                if !granted {
                    errorMessage = "캘린더 접근 권한이 거부되었습니다."
                }
            } else {
                let granted: Bool = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }

                authorizationStatus = EKEventStore.authorizationStatus(for: .event)

                if !granted {
                    errorMessage = "캘린더 접근 권한이 거부되었습니다."
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchEventsForTodayAndTomorrow() {
        refreshAuthorizationStatus()
        errorMessage = nil

        guard isAuthorized else {
            errorMessage = "캘린더 접근 권한이 필요합니다."
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 2, to: start) ?? Date()

        fetchEvents(startDate: start, endDate: end)
    }

    func fetchEvents(startDate: Date, endDate: Date) {
        refreshAuthorizationStatus()
        errorMessage = nil

        guard isAuthorized else {
            errorMessage = "캘린더 접근 권한이 필요합니다."
            return
        }

        let calendars = eventStore.calendars(for: .event)

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        let ekEvents = eventStore.events(matching: predicate)

        events = ekEvents
            .map { event in
                CalendarEventItem(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "제목 없음",
                    notes: event.notes,
                    location: event.location,
                    url: event.url,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarTitle: event.calendar.title,
                    isAllDay: event.isAllDay
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized:
            return true
        case .fullAccess:
            return true
        default:
            return false
        }
    }

    var authorizationText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "권한 요청 전"
        case .restricted:
            return "제한됨"
        case .denied:
            return "거부됨"
        case .authorized:
            return "허용됨"
        case .fullAccess:
            return "전체 접근 허용됨"
        case .writeOnly:
            return "쓰기 전용 권한"
        @unknown default:
            return "알 수 없음"
        }
    }
}
