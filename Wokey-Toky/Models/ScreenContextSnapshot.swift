//
//  ScreenContextSnapshot.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import Foundation
import SwiftData

@Model
final class ScreenContextSnapshot {
    var capturedAt: Date
    var primaryAppName: String?
    var primaryWindowTitle: String?
    var summaryText: String?

    @Relationship(deleteRule: .cascade, inverse: \VisibleWindowRecord.snapshot)
    var windows: [VisibleWindowRecord]

    init(
        capturedAt: Date = Date(),
        primaryAppName: String? = nil,
        primaryWindowTitle: String? = nil,
        summaryText: String? = nil,
        windows: [VisibleWindowRecord] = []
    ) {
        self.capturedAt = capturedAt
        self.primaryAppName = primaryAppName
        self.primaryWindowTitle = primaryWindowTitle
        self.summaryText = summaryText
        self.windows = windows
    }
}
