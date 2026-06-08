//
//  AppleNotesService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//


import Foundation
import AppKit

struct AppleNotesFolderInfo: Identifiable, Hashable {
    let accountName: String
    let folderName: String
    let noteCount: Int

    var id: String {
        "\(accountName)::\(folderName)"
    }

    var displayText: String {
        if accountName.isEmpty {
            return folderName.isEmpty ? "폴더 정보 없음" : folderName
        }

        if folderName.isEmpty {
            return accountName
        }

        return "\(accountName) / \(folderName)"
    }
}

final class AppleNotesService {
    func fetchFolders() throws -> [AppleNotesFolderInfo] {
        let scriptSource = """
        tell application id "com.apple.Notes"
            delay 0.1

            set outputText to ""
            repeat with theAccount in accounts
                set accountName to name of theAccount as text
                repeat with theFolder in folders of theAccount
                    set folderName to name of theFolder as text
                    set folderNoteCount to count of notes of theFolder
                    set outputText to outputText & accountName & "<<<WOKEY_ACCOUNT_FOLDER>>>" & folderName & "<<<WOKEY_FOLDER_COUNT>>>" & folderNoteCount & "<<<WOKEY_FOLDER_END>>>"
                end repeat
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
        let chunks = rawText.components(separatedBy: "<<<WOKEY_FOLDER_END>>>")
        var seenIDs: Set<String> = []
        var folders: [AppleNotesFolderInfo] = []

        for chunk in chunks {
            let accountAndRest = chunk.components(separatedBy: "<<<WOKEY_ACCOUNT_FOLDER>>>")

            guard accountAndRest.count >= 2 else {
                continue
            }

            let accountName = accountAndRest[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let folderAndCount = accountAndRest[1].components(separatedBy: "<<<WOKEY_FOLDER_COUNT>>>")

            guard folderAndCount.count >= 2 else {
                continue
            }

            let folderName = folderAndCount[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let noteCount = Int(folderAndCount[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            guard !accountName.isEmpty || !folderName.isEmpty else {
                continue
            }

            let folder = AppleNotesFolderInfo(
                accountName: accountName,
                folderName: folderName,
                noteCount: noteCount
            )

            guard !seenIDs.contains(folder.id) else {
                continue
            }

            seenIDs.insert(folder.id)
            folders.append(folder)
        }

        return folders.sorted {
            $0.displayText.localizedCaseInsensitiveCompare($1.displayText) == .orderedAscending
        }
    }

    func fetchNotes(in folderIDs: Set<String>) throws -> [AppleNoteItem] {
        guard !folderIDs.isEmpty else {
            return []
        }

        let allowedFolderKeys = folderIDs
            .sorted()
            .map { "<<<WOKEY_ALLOWED_KEY>>>\($0)<<<WOKEY_ALLOWED_KEY>>>" }
            .joined()
            .appleScriptEscaped()

        let scriptSource = """
        tell application id "com.apple.Notes"
            delay 0.1

            set allowedFolderKeys to "\(allowedFolderKeys)"
            set outputText to ""
            repeat with theAccount in accounts
                set accountName to name of theAccount as text
                repeat with theFolder in folders of theAccount
                    set folderName to name of theFolder as text
                    set folderKey to accountName & "::" & folderName
                    if allowedFolderKeys contains ("<<<WOKEY_ALLOWED_KEY>>>" & folderKey & "<<<WOKEY_ALLOWED_KEY>>>") then
                        repeat with n in notes of theFolder
                            set noteName to name of n as text
                            set noteModified to modification date of n as text
                            set noteBody to body of n as text
                            set outputText to outputText & accountName & "<<<WOKEY_ACCOUNT_FOLDER>>>" & folderName & "<<<WOKEY_FOLDER_TITLE>>>" & noteName & "<<<WOKEY_TITLE_BODY>>>" & noteBody & "<<<WOKEY_BODY_MODIFIED>>>" & noteModified & "<<<WOKEY_NOTE_END>>>"
                        end repeat
                    end if
                end repeat
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

    func fetchNotes() throws -> [AppleNoteItem] {
        let scriptSource = """
        tell application id "com.apple.Notes"
            delay 0.1

            set outputText to ""
            repeat with theAccount in accounts
                set accountName to name of theAccount as text
                repeat with theFolder in folders of theAccount
                    set folderName to name of theFolder as text
                    repeat with n in notes of theFolder
                        set noteName to name of n as text
                        set noteModified to modification date of n as text
                        set noteBody to body of n as text
                        set outputText to outputText & accountName & "<<<WOKEY_ACCOUNT_FOLDER>>>" & folderName & "<<<WOKEY_FOLDER_TITLE>>>" & noteName & "<<<WOKEY_TITLE_BODY>>>" & noteBody & "<<<WOKEY_BODY_MODIFIED>>>" & noteModified & "<<<WOKEY_NOTE_END>>>"
                    end repeat
                end repeat
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
            let accountAndRest = chunk.components(separatedBy: "<<<WOKEY_ACCOUNT_FOLDER>>>")

            guard accountAndRest.count >= 2 else {
                return nil
            }

            let accountName = accountAndRest[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let folderAndRest = accountAndRest[1].components(separatedBy: "<<<WOKEY_FOLDER_TITLE>>>")

            guard folderAndRest.count >= 2 else {
                return nil
            }

            let folderName = folderAndRest[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let parts = folderAndRest[1].components(separatedBy: "<<<WOKEY_TITLE_BODY>>>")

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
                modifiedAtText: modifiedAtText,
                accountName: accountName.isEmpty ? nil : accountName,
                folderName: folderName.isEmpty ? nil : folderName
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
    func appleScriptEscaped() -> String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

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
