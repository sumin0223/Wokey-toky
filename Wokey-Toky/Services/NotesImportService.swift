//
//  NotesImportService.swift
//  Wokey-Toky
//

import AppKit
import Foundation

struct NotesFolderCandidate: Identifiable, Hashable {
    let accountName: String
    let folderName: String

    var id: String {
        "\(accountName)::\(folderName)"
    }
}

struct NotesScheduleCandidate: Identifiable {
    let id = UUID().uuidString
    let title: String
    let body: String
    let folderName: String
    let dueAt: Date
}

final class NotesImportService {
    func fetchFolders() throws -> [NotesFolderCandidate] {
        let script = """
        tell application "Notes"
            set output to ""
            repeat with theAccount in accounts
                repeat with theFolder in folders of theAccount
                    set output to output & (name of theAccount) & "||" & (name of theFolder) & linefeed
                end repeat
            end repeat
            return output
        end tell
        """

        let output = try runAppleScript(script)

        return output
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "||", omittingEmptySubsequences: false)
                guard parts.count >= 2 else {
                    return nil
                }

                return NotesFolderCandidate(
                    accountName: String(parts[0]),
                    folderName: String(parts[1])
                )
            }
            .sorted {
                $0.folderName.localizedCaseInsensitiveCompare($1.folderName) == .orderedAscending
            }
    }

    func fetchCandidates(
        selectedFolders: Set<String>,
        includeAllFolders: Bool
    ) throws -> [NotesScheduleCandidate] {
        let script = """
        tell application "Notes"
            set output to ""
            repeat with theAccount in accounts
                repeat with theFolder in folders of theAccount
                    repeat with theNote in notes of theFolder
                        set noteTitle to name of theNote
                        set noteBody to plaintext of theNote
                        set output to output & (name of theAccount) & "||" & (name of theFolder) & "||" & noteTitle & "||" & noteBody & "<<<WOKEY_NOTE>>>"
                    end repeat
                end repeat
            end repeat
            return output
        end tell
        """

        let output = try runAppleScript(script)

        return output
            .components(separatedBy: "<<<WOKEY_NOTE>>>")
            .compactMap { block in
                let parts = block.components(separatedBy: "||")
                guard parts.count >= 4 else {
                    return nil
                }

                let folder = NotesFolderCandidate(
                    accountName: parts[0],
                    folderName: parts[1]
                )

                guard includeAllFolders || selectedFolders.contains(folder.id) else {
                    return nil
                }

                let title = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let body = parts.dropFirst(3).joined(separator: "||")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard looksLikeScheduleCandidate(title: title, body: body) else {
                    return nil
                }

                return NotesScheduleCandidate(
                    title: title.isEmpty ? firstLine(from: body) : title,
                    body: body,
                    folderName: folder.folderName,
                    dueAt: inferredDueDate(from: "\(title)\n\(body)")
                )
            }
    }

    static func openAutomationSettings() {
        openSettingsPane("Privacy_Automation")
    }

    private func runAppleScript(_ script: String) throws -> String {
        var errorInfo: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw NotesImportError.scriptCreationFailed
        }

        let descriptor = appleScript.executeAndReturnError(&errorInfo)

        if let errorInfo {
            throw NotesImportError.appleScriptFailed(errorInfo.description)
        }

        return descriptor.stringValue ?? ""
    }

    private static func openSettingsPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

enum NotesImportError: LocalizedError {
    case scriptCreationFailed
    case appleScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .scriptCreationFailed:
            return "Notes 접근 스크립트를 만들지 못했습니다."
        case .appleScriptFailed(let message):
            return "Notes 접근 권한이 필요합니다. macOS 설정에서 Wokey-Toky가 Notes를 제어하도록 허용해주세요. \(message)"
        }
    }
}

private func looksLikeScheduleCandidate(
    title: String,
    body: String
) -> Bool {
    let text = "\(title)\n\(body)"
    let keywords = [
        "마감",
        "제출",
        "해야",
        "할 일",
        "과제",
        "회의",
        "미팅",
        "예약",
        "보내기",
        "수정",
        "완료",
        "내일",
        "오늘"
    ]

    return keywords.contains { text.localizedCaseInsensitiveContains($0) }
}

private func firstLine(from body: String) -> String {
    body
        .split(separator: "\n")
        .first
        .map(String.init) ?? "메모 일정 후보"
}

private func inferredDueDate(from text: String) -> Date {
    let calendar = Calendar.current
    let now = Date()

    if text.contains("내일") {
        return calendar.date(byAdding: .day, value: 1, to: now) ?? now
    }

    if text.contains("오늘") {
        return now
    }

    return calendar.date(byAdding: .day, value: 1, to: now) ?? now
}
