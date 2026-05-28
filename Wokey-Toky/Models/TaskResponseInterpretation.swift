//
//  TaskResponseInterpretation.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation

struct TaskResponseInterpretation: Identifiable {
    let id = UUID()

    let taskTitle: String
    let status: TaskStatus
    let responseText: String
    let deferredTo: Date?

    let confidence: Double
    let needsClarification: Bool
    let clarificationQuestion: String?
}
