//
//  SourceImport.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

// 소스타입 예정: 복붙, 메모장, 카톡, 슬랙, 지라

import Foundation
import SwiftData

@Model
final class SourceImport {
    var sourceType: String
    var title: String
    var rawText: String
    var importedAt: Date

    init(
        sourceType: String,
        title: String,
        rawText: String,
        importedAt: Date = Date()
    ) {
        self.sourceType = sourceType
        self.title = title
        self.rawText = rawText
        self.importedAt = importedAt
    }
}
