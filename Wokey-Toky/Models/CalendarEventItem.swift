//
//  CalendarEventItem.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation

struct CalendarEventItem: Identifiable {
    let id: String
    let title: String
    let notes: String?
    let location: String?
    let url: URL?
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let isAllDay: Bool
}
