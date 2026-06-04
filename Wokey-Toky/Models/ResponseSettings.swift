//
//  ResponseSettings.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation
import SwiftData

@Model
final class ResponseSettings {
    var autoApplyNaturalResponses: Bool
    var autoApplyConfidenceThreshold: Double
    var reviewConfidenceThreshold: Double
    var askClarificationWhenUncertain: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        autoApplyNaturalResponses: Bool = true,
        autoApplyConfidenceThreshold: Double = 0.75,
        reviewConfidenceThreshold: Double = 0.45,
        askClarificationWhenUncertain: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.autoApplyNaturalResponses = autoApplyNaturalResponses
        self.autoApplyConfidenceThreshold = autoApplyConfidenceThreshold
        self.reviewConfidenceThreshold = reviewConfidenceThreshold
        self.askClarificationWhenUncertain = askClarificationWhenUncertain
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
