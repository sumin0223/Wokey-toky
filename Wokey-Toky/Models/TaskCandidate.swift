//
//  TaskCandidate.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation
import SwiftData

@Model
final class TaskCandidate {
    var title: String
    var detail: String?
    var sourceType: String
    var sourceText: String
    var suggestedDueAt: Date?
    var dueText: String?
    var confidence: Double
    var isImported: Bool
    var createdAt: Date

    init(
        title: String,
        detail: String? = nil,
        sourceType: String,
        sourceText: String,
        suggestedDueAt: Date? = nil, // 실제 Date 변환 결과, 지금은 nil 가능
        // LLM이 내일 오전, 금요일까지, 오늘 18:00 같은 표현은 잘 뽑을 수 잇, but 이걸 정확한 Date로 변환하는 건 나중에 따로 처리하는 게 좋겟지
        dueText: String? = nil, // 지금은 '질문에서 추출한 시간 표현
        confidence: Double = 0.5,
        isImported: Bool = false,
        createdAt: Date = Date()
    ) {
        self.title = title
        self.detail = detail
        self.sourceType = sourceType
        self.sourceText = sourceText
        self.suggestedDueAt = suggestedDueAt
        self.dueText = dueText
        self.confidence = confidence
        self.isImported = isImported
        self.createdAt = createdAt
    }
}
