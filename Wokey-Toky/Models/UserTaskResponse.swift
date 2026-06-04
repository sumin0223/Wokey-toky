//
//  UserTaskResponse.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation
import SwiftData

@Model
final class UserTaskResponse {
    var taskTitle: String
    var responseType: String
    var responseText: String?
    var interpretedStatus: String
    var deferredTo: Date?
    var createdAt: Date

    init(
        taskTitle: String,
        responseType: String,
        responseText: String? = nil,
        interpretedStatus: String,
        deferredTo: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.taskTitle = taskTitle
        self.responseType = responseType
        self.responseText = responseText
        self.interpretedStatus = interpretedStatus
        self.deferredTo = deferredTo
        self.createdAt = createdAt
    }
}
