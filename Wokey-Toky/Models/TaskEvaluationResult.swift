//
//  Untitled.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation

struct TaskEvaluationResult {
    let task: TaskItem
    let status: TaskStatus
    let evidenceSummary: String
    let needsUserConfirmation: Bool
    let relatedActivityMinutes: Int
}
