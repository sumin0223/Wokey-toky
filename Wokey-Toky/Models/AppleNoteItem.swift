//
//  AppleNoteItem.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation

struct AppleNoteItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let body: String
    let modifiedAtText: String?

    var previewText: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "내용 미리보기 없음"
        }
        return String(trimmed.prefix(240))
    }
}
