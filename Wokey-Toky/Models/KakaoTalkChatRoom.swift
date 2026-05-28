//
//  KakaoTalkChatRoom.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation

struct KakaoTalkChatRoom: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let rawDescription: String
    let lookupName: String

    init(
        name: String,
        rawDescription: String,
        lookupName: String? = nil
    ) {
        self.name = name
        self.rawDescription = rawDescription
        self.lookupName = lookupName ?? name
    }
}
