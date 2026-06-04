//
//  ClarificationItem.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//
// 화면에서 잠깐 보여줄 역질문 데이터
import Foundation

enum ClarificationType {
    case selectTask
    case selectStatus
}

struct ClarificationItem: Identifiable {
    let id = UUID()
    let message: String
    let originalResponseText: String
    let suggestedStatus: TaskStatus?
    let candidateTasks: [TaskItem]
    let type: ClarificationType
}
