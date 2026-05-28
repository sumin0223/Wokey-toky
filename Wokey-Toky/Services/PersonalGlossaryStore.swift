//
//  PersonalGlossaryStore.swift
//  Wokey-Toky
//

import Foundation

enum PersonalGlossaryStore {
    private static let key = "personal_glossary_text"

    static let defaultGlossary = """
    스작설 = 스마트작업설계
    전종설 = 전공종합설계
    생관 = 생산관리
    품경 = 품질경영
    LMS = 학습관리시스템
    """

    static func readGlossaryText() -> String {
        let saved = UserDefaults.standard.string(forKey: key) ?? ""
        let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultGlossary : saved
    }

    static func saveGlossaryText(_ text: String) {
        UserDefaults.standard.set(text, forKey: key)
    }

    static func glossaryPromptBlock() -> String {
        let text = readGlossaryText().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return "[사용자 개인 용어 사전]\n없음"
        }

        return """
        [사용자 개인 용어 사전]
        아래 용어는 사용자가 실제로 쓰는 줄임말/과목명/프로젝트명입니다. Task title과 detail을 만들 때 가능하면 정식 표현으로 풀어 쓰세요. 단, 사전에 없는 내용은 억지로 추측하지 마세요.
        \(text)
        """
    }
}
