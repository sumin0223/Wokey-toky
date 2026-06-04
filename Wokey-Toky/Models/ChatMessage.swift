//
//  ChatMessage.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    var role: String
    var content: String
    var createdAt: Date

    init(
        role: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
