//
//  TaskItem.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import Foundation
import SwiftData

@Model
final class TaskItem {
    var title: String
    var detail: String?

    // 출처: manual, appleCalendar, googleCalendar, llm, suggestion
    var source: String

    var projectName: String?

    // 상태: pending, inProgress, completed, uncertain, deferred
    var status: String

    var isCompleted: Bool
    
    // scheduleType: task / event
    var scheduleType: String?

    // PC 작업 여부. event는 보통 false, task는 사용자가 선택
    var requiresPCWork: Bool?

    // 캘린더 일정 시작 시간
    var plannedStartAt: Date?

    // 마감일 또는 일정 종료 시간
    var dueAt: Date?

    // 실제 활동 기록 기반 근거 요약
    var evidenceSummary: String?

    // 사용자에게 확인 질문이 필요한지
    var needsUserConfirmation: Bool

    // 내일 또는 특정 날짜로 넘긴 경우
    var deferredTo: Date?

    // 나중에 캘린더 이벤트 중복 방지용
    var externalIdentifier: String?

    // 관련 키워드. 예: "생산시스템관리,LMS,과제"
    var relatedKeywords: String?

    var createdAt: Date
    var completedAt: Date?

    init(
        title: String,
        detail: String? = nil,
        source: String = "manual",
        projectName: String? = nil,
        status: String = "pending",
        isCompleted: Bool = false,
        scheduleType: String = "task",
        requiresPCWork: Bool = true,
        plannedStartAt: Date? = nil,
        dueAt: Date? = nil,
        evidenceSummary: String? = nil,
        needsUserConfirmation: Bool = false,
        deferredTo: Date? = nil,
        externalIdentifier: String? = nil,
        relatedKeywords: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.title = title
        self.detail = detail
        self.source = source
        self.projectName = projectName
        self.status = status
        self.isCompleted = isCompleted
        self.scheduleType = scheduleType
        self.requiresPCWork = requiresPCWork
        self.plannedStartAt = plannedStartAt
        self.dueAt = dueAt
        self.evidenceSummary = evidenceSummary
        self.needsUserConfirmation = needsUserConfirmation
        self.deferredTo = deferredTo
        self.externalIdentifier = externalIdentifier
        self.relatedKeywords = relatedKeywords
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
