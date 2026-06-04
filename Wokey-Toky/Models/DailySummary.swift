//
//  DailySummary.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import Foundation
import SwiftData

@Model
final class DailySummary {
    var date: Date
    var title: String
    var content: String
    var sourceLog: String
    var createdAt: Date
    var updatedAt: Date

    init(
        date: Date = Date(),
        title: String,
        content: String,
        sourceLog: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.date = date
        self.title = title
        self.content = content
        self.sourceLog = sourceLog
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
