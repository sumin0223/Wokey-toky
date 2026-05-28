//
//  TaskStatus.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/9/26.
//

import Foundation

enum TaskStatus: String, CaseIterable {
    case pending
    case inProgress
    case completed
    case uncertain
    case deferred

    var displayName: String {
        switch self {
        case .pending:
            return "대기"
        case .inProgress:
            return "진행 중"
        case .completed:
            return "완료"
        case .uncertain:
            return "확인 필요"
        case .deferred:
            return "연기됨"
        }
    }
}
