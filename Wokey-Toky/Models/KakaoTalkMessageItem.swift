//
//  KakaoTalkMessageItem.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation

struct KakaoTalkMessageItem: Identifiable {
    let id = UUID()
    let sender: String?
    let text: String
    let sentAt: String?
    let chatRoomName: String?

    init(
        sender: String?,
        text: String,
        sentAt: String?,
        chatRoomName: String? = nil
    ) {
        self.sender = sender
        self.text = text
        self.sentAt = sentAt
        self.chatRoomName = chatRoomName
    }

    func withChatRoomName(_ roomName: String) -> KakaoTalkMessageItem {
        KakaoTalkMessageItem(
            sender: sender,
            text: text,
            sentAt: sentAt,
            chatRoomName: roomName
        )
    }
}
