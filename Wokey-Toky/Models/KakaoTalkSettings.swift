//
//  KakaoTalkSettings.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation
import SwiftData

enum KakaoTalkAnalysisScope: String, CaseIterable, Identifiable {
    case selectedChats
    case keywordMessages
    case recentAllChats

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selectedChats:
            return "선택한 채팅방만"
        case .keywordMessages:
            return "키워드 포함 메시지만"
        case .recentAllChats:
            return "전체 채팅방 최근 메시지 분석 - 실험 기능"
        }
    }
}

enum KakaoTalkAnalysisInterval: String, CaseIterable, Identifiable {
    case manual
    case every30Minutes
    case hourly
    case nearRealtime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual:
            return "수동 실행"
        case .every30Minutes:
            return "30분마다"
        case .hourly:
            return "1시간마다"
        case .nearRealtime:
            return "앱 실행 중 실시간에 가깝게"
        }
    }
}

enum KakaoTalkStorageMode: String, CaseIterable, Identifiable {
    case noRawMessage
    case evidenceSnippetOnly
    case deleteRawAfterExtraction

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noRawMessage:
            return "원문 메시지 저장 안 함"
        case .evidenceSnippetOnly:
            return "Task 후보 근거 메시지 일부만 저장"
        case .deleteRawAfterExtraction:
            return "후보 생성 후 원문 즉시 삭제"
        }
    }
}

enum KakaoTalkLLMProcessingMode: String, CaseIterable, Identifiable {
    case localOnly
    case allowExternalAPI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .localOnly:
            return "로컬 Ollama만 사용"
        case .allowExternalAPI:
            return "외부 API 허용"
        }
    }
}

@Model
final class KakaoTalkSettings {
    var isEnabled: Bool
    var hasAcceptedPrivacyNotice: Bool

    var analysisScope: String
    var analysisInterval: String
    var storageMode: String
    var llmProcessingMode: String

    var keywordsText: String
    var selectedChatNamesText: String

    var createdAt: Date
    var updatedAt: Date
    
    var excludeBrandChats: Bool

    init(
        isEnabled: Bool = false,
        hasAcceptedPrivacyNotice: Bool = false,
        analysisScope: String = KakaoTalkAnalysisScope.selectedChats.rawValue,
        analysisInterval: String = KakaoTalkAnalysisInterval.manual.rawValue,
        storageMode: String = KakaoTalkStorageMode.evidenceSnippetOnly.rawValue,
        llmProcessingMode: String = KakaoTalkLLMProcessingMode.localOnly.rawValue,
        keywordsText: String = "과제,회의,마감,제출,보내줘,공유,내일,오늘,까지",
        selectedChatNamesText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        excludeBrandChats: Bool = true,
    ) {
        self.isEnabled = isEnabled
        self.hasAcceptedPrivacyNotice = hasAcceptedPrivacyNotice
        self.analysisScope = analysisScope
        self.analysisInterval = analysisInterval
        self.storageMode = storageMode
        self.llmProcessingMode = llmProcessingMode
        self.keywordsText = keywordsText
        self.selectedChatNamesText = selectedChatNamesText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.excludeBrandChats = excludeBrandChats
    }
}
