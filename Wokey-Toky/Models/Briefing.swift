//
//  Briefing.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation
import SwiftData

@Model
final class Briefing {
    var type: String
    var date: Date
    var title: String
    var content: String
    var questions: String
    var createdAt: Date

    init(
        type: String,
        date: Date = Date(),
        title: String,
        content: String,
        questions: String = "",
        createdAt: Date = Date()
    ) {
        self.type = type
        self.date = date
        self.title = title
        self.content = content
        self.questions = questions
        self.createdAt = createdAt
    }
}
