//
//  Untitled.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import Foundation
import SwiftData

@Model
final class Suggestion {
    var title: String
    var message: String
    var type: String
    var source: String
    var isDismissed: Bool
    var isConvertedToTask: Bool
    var createdAt: Date

    init(
        title: String,
        message: String,
        // summary / resume / focus / task / break / general
        type: String = "general",
        // rule / llm
        source: String = "rule",
        isDismissed: Bool = false, // 사용자가 숨김 처리했는지
        isConvertedToTask: Bool = false, // 할 일로 전환했는지
        createdAt: Date = Date()
    ) {
        self.title = title
        self.message = message
        self.type = type
        self.source = source
        self.isDismissed = isDismissed
        self.isConvertedToTask = isConvertedToTask
        self.createdAt = createdAt
    }
}
