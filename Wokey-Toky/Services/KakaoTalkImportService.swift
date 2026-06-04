//
//  KakaoTalkImportService.swift
//  Wokey-Toky
//

import AppKit
import Foundation

struct KakaoRoomCandidate: Identifiable, Hashable {
    let id: String
    let name: String
    let preview: String
    let messageCount: Int
}

struct KakaoScheduleCandidate: Identifiable {
    let id = UUID().uuidString
    let roomID: String
    let roomName: String
    let message: String
    let dueAt: Date
}

final class KakaoTalkImportService {
    func fetchRooms() throws -> [KakaoRoomCandidate] {
        guard let executableURL = executableURL() else {
            throw KakaoTalkImportError.kakaoCLIUnavailable
        }

        let data = try run(
            executableURL: executableURL,
            arguments: ["chats", "--json"]
        )

        let objects = try parseFlexibleJSONObjectArray(data)

        return objects.compactMap { object in
            let id = stringValue(
                object,
                keys: ["id", "chat_id", "room_id", "chatId"]
            )
            let name = stringValue(
                object,
                keys: ["name", "title", "chat_name", "room_name"]
            )

            guard let id,
                  let name,
                  !isPromotionalRoom(name) else {
                return nil
            }

            let preview = stringValue(
                object,
                keys: ["preview", "last_message", "message", "lastMessage"]
            ) ?? ""
            let count = intValue(
                object,
                keys: ["message_count", "count", "unread_count"]
            ) ?? 0

            return KakaoRoomCandidate(
                id: id,
                name: name,
                preview: preview,
                messageCount: count
            )
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func fetchCandidates(
        from rooms: [KakaoRoomCandidate]
    ) throws -> [KakaoScheduleCandidate] {
        guard let executableURL = executableURL() else {
            throw KakaoTalkImportError.kakaoCLIUnavailable
        }

        var candidates: [KakaoScheduleCandidate] = []

        for room in rooms {
            let data = try run(
                executableURL: executableURL,
                arguments: ["messages", "--chat", room.id, "--json"]
            )

            let objects = try parseFlexibleJSONObjectArray(data)

            for object in objects {
                let message = stringValue(
                    object,
                    keys: ["text", "message", "content", "body"]
                ) ?? ""

                guard looksLikeKakaoScheduleMessage(message),
                      !isPromotionalRoom(message) else {
                    continue
                }

                candidates.append(
                    KakaoScheduleCandidate(
                        roomID: room.id,
                        roomName: room.name,
                        message: message,
                        dueAt: inferredDueDate(from: message)
                    )
                )
            }
        }

        return candidates
    }

    static func openKakaoTalk() {
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/Applications/KakaoTalk.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    static func openFullDiskSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func executableURL() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/kakaocli",
            "/usr/local/bin/kakaocli",
            "/usr/bin/kakaocli"
        ]

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func run(
        executableURL: URL,
        arguments: [String]
    ) throws -> Data {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorOutput, encoding: .utf8) ?? "알 수 없는 오류"
            throw KakaoTalkImportError.commandFailed(message)
        }

        return output
    }

    private func parseFlexibleJSONObjectArray(_ data: Data) throws -> [[String: Any]] {
        let json = try JSONSerialization.jsonObject(with: data)

        if let array = json as? [[String: Any]] {
            return array
        }

        if let object = json as? [String: Any] {
            for key in ["chats", "rooms", "messages", "data", "items"] {
                if let array = object[key] as? [[String: Any]] {
                    return array
                }
            }
        }

        return []
    }

    private func stringValue(
        _ object: [String: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let value = object[key] as? String,
               !value.isEmpty {
                return value
            }

            if let value = object[key] {
                return "\(value)"
            }
        }

        return nil
    }

    private func intValue(
        _ object: [String: Any],
        keys: [String]
    ) -> Int? {
        for key in keys {
            if let value = object[key] as? Int {
                return value
            }

            if let value = object[key] as? String,
               let intValue = Int(value) {
                return intValue
            }
        }

        return nil
    }
}

enum KakaoTalkImportError: LocalizedError {
    case kakaoCLIUnavailable
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .kakaoCLIUnavailable:
            return "카카오톡 대화방을 읽으려면 kakaocli 연결이 필요합니다. KakaoTalk 설치와 macOS 전체 디스크 접근 권한을 확인해주세요."
        case .commandFailed(let message):
            return "카카오톡 데이터를 읽지 못했습니다. macOS 설정에서 KakaoTalk/Wokey-Toky 권한을 확인해주세요. \(message)"
        }
    }
}

private func isPromotionalRoom(_ text: String) -> Bool {
    let keywords = ["광고", "혜택", "쿠폰", "프로모션", "이벤트", "쇼핑", "마케팅"]
    return keywords.contains { text.localizedCaseInsensitiveContains($0) }
}

private func looksLikeKakaoScheduleMessage(_ message: String) -> Bool {
    let keywords = [
        "마감",
        "내일",
        "오늘",
        "해야",
        "해줘",
        "보내",
        "제출",
        "회의",
        "미팅",
        "예약",
        "과제",
        "수정",
        "확인"
    ]

    return keywords.contains { message.localizedCaseInsensitiveContains($0) }
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
