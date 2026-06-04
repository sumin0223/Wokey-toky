//
//  BriefingType.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/10/26.
//

import Foundation

enum BriefingType: String, CaseIterable {
    case morning
    case lunch
    case evening

    var displayName: String {
        switch self {
        case .morning:
            return "아침 브리핑"
        case .lunch:
            return "점심 점검"
        case .evening:
            return "저녁 회고"
        }
    }
}
