//
//  AppleNotesService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation
import AppKit

final class AppleNotesService {
    func fetchNotes() throws -> [AppleNoteItem] {
        let scriptSource = """
        tell application id "com.apple.Notes"
            activate
            delay 1

            set outputText to ""
            repeat with n in notes
                set noteName to name of n as text
                set noteModified to modification date of n as text
                set noteBody to body of n as text
                set outputText to outputText & noteName & "<<<WOKEY_TITLE_BODY>>>" & noteBody & "<<<WOKEY_BODY_MODIFIED>>>" & noteModified & "<<<WOKEY_NOTE_END>>>"
            end repeat

            return outputText
        end tell
        """

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else {
            throw AppleNotesServiceError.scriptCreationFailed
        }

        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            throw AppleNotesServiceError.scriptExecutionFailed(errorInfo.description)
        }

        let rawText = result.stringValue ?? ""

        return parseNotes(rawText)
    }

    private func parseNotes(_ rawText: String) -> [AppleNoteItem] {
        let noteChunks = rawText.components(separatedBy: "<<<WOKEY_NOTE_END>>>")

        return noteChunks.compactMap { chunk in
            let parts = chunk.components(separatedBy: "<<<WOKEY_TITLE_BODY>>>")

            guard parts.count >= 2 else {
                return nil
            }

            let title = parts[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let bodyAndModified = parts[1].components(separatedBy: "<<<WOKEY_BODY_MODIFIED>>>")
            let bodySource = bodyAndModified.first ?? ""
            let modifiedAtText = bodyAndModified.count > 1
                ? bodyAndModified[1].trimmingCharacters(in: .whitespacesAndNewlines)
                : nil

            let body = bodySource
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .htmlToPlainText()

            guard !title.isEmpty || !body.isEmpty else {
                return nil
            }

            return AppleNoteItem(
                title: title.isEmpty ? "제목 없는 메모" : title,
                body: body,
                modifiedAtText: modifiedAtText
            )
        }
    }
}

enum AppleNotesServiceError: LocalizedError {
    case scriptCreationFailed
    case scriptExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptCreationFailed:
            return "Apple Notes 스크립트를 생성하지 못했습니다."
        case .scriptExecutionFailed(let message):
            return "Apple Notes를 읽는 중 오류가 발생했습니다: \(message)"
        }
    }
}

private extension String {
    func htmlToPlainText() -> String {
        guard let data = self.data(using: .utf8) else {
            return self
        }

        if let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            return attributed.string
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return self
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
