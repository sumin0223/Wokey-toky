//
//  ScheduleType.swift
//  Wokey-Toky
//
//  Created by Codex on 5/18/26.
//

import Foundation

enum ScheduleType: String, CaseIterable {
    case task
    case event

    var displayName: String {
        switch self {
        case .task:
            return "Task"
        case .event:
            return "Event"
        }
    }

    var description: String {
        switch self {
        case .task:
            return "진행성을 띄는 일"
        case .event:
            return "시간이 정해진 물리적 사건"
        }
    }
}
