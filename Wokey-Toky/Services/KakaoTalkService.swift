//
//  KakaoTalkService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation

final class KakaoTalkService {
    private let fileManager = FileManager.default

    private var helperPath: String? {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Desktop/k-skill/scripts/kakaotalk_mac.py",
            "\(home)/Documents/k-skill/scripts/kakaotalk_mac.py",
            "\(home)/Downloads/k-skill/scripts/kakaotalk_mac.py",
            "\(home)/Library/Application Support/Wokey-Toky/k-skill/scripts/kakaotalk_mac.py"
        ]

        return candidates.first { fileManager.fileExists(atPath: $0) }
    }

    private var pythonPath: String? {
        [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        .first { fileManager.isExecutableFile(atPath: $0) }
    }
    
    func checkAvailability() async -> Bool {
        helperPath != nil && pythonPath != nil
    }

    func fetchChatRooms(limit: Int = 30) async throws -> [KakaoTalkChatRoom] {
        let (pythonPath, helperPath) = try resolvedHelper()
        let command = "\(shellEscape(pythonPath)) \(shellEscape(helperPath)) chats --limit \(limit) --json"

        let output = try await runCommand(
            launchPath: "/bin/zsh",
            arguments: ["-lc", command]
        )

        let parsed = parseChatRooms(from: output)

        if parsed.isEmpty {
            throw KakaoTalkServiceError.noChatRoomsFound(output)
        }

        return parsed
    }

    func fetchMessages(
        chatName: String,
        since: String = "1d"
    ) async throws -> [KakaoTalkMessageItem] {
        let (pythonPath, helperPath) = try resolvedHelper()
        let escapedChatName = shellEscape(chatName)
        let escapedSince = shellEscape(since)

        let command = "\(shellEscape(pythonPath)) \(shellEscape(helperPath)) messages --chat \(escapedChatName) --since \(escapedSince) --json"

        let output = try await runCommand(
            launchPath: "/bin/zsh",
            arguments: ["-lc", command]
        )

        let parsed = parseMessages(from: output)

        if parsed.isEmpty {
            throw KakaoTalkServiceError.noMessagesFound(output)
        }

        return parsed
    }

    private func runCommand(
        launchPath: String,
        arguments: [String]
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = errorOutput.isEmpty ? output : errorOutput
                    continuation.resume(throwing: KakaoTalkServiceError.commandFailed(message))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseChatRooms(from output: String) -> [KakaoTalkChatRoom] {
        guard let data = output.data(using: .utf8) else {
            return []
        }

        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { item in
                let names = chatRoomNames(from: item)

                return KakaoTalkChatRoom(
                    name: names.displayName,
                    rawDescription: String(describing: item),
                    lookupName: names.lookupName
                )
            }
        }

        if let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let array =
            dictionary["chats"] as? [[String: Any]] ??
            dictionary["rooms"] as? [[String: Any]] ??
            dictionary["data"] as? [[String: Any]] {
            return array.compactMap { item in
                let names = chatRoomNames(from: item)

                return KakaoTalkChatRoom(
                    name: names.displayName,
                    rawDescription: String(describing: item),
                    lookupName: names.lookupName
                )
            }
        }

        return []
    }
    
    private func stringValue(
        from item: [String: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            if let value = item[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }

    private func chatRoomNames(from item: [String: Any]) -> (displayName: String, lookupName: String) {
        let directNameKeys = [
            "name", "title", "chat_name", "chatName", "room", "room_name", "roomName",
            "display_name", "displayName", "chat_title", "chatTitle", "room_title", "roomTitle"
        ]

        let directName = stringValue(from: item, keys: directNameKeys)
        let lookupName = directName ?? fallbackChatIdentifier(from: item) ?? "unknown"

        if let directName,
           directName.lowercased() != "unknown" {
            return (directName, lookupName)
        }

        let memberContainerKeys = ["members", "users", "participants"]

        for key in memberContainerKeys {
            if let members = item[key] as? [[String: Any]] {
                let names = members.compactMap { memberName(from: $0) }

                if !names.isEmpty {
                    return (names.joined(separator: ", "), lookupName)
                }
            }
        }

        if let identifier = fallbackChatIdentifier(from: item) {
            return ("이름 없는 채팅방 (ID: \(identifier))", lookupName)
        }

        return ("이름 없는 채팅방", lookupName)
    }

    private func fallbackChatIdentifier(from item: [String: Any]) -> String? {
        let idKeys = ["id", "chat_id", "chatId", "room_id", "roomId"]

        for key in idKeys {
            if let id = item[key] as? String {
                let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)

                if !trimmed.isEmpty {
                    return trimmed
                }
            }

            if let id = item[key] as? Int {
                return String(id)
            }
        }

        return nil
    }

    private func memberName(from item: [String: Any]) -> String? {
        let memberNameKeys = [
            "name", "nickname", "nickName", "display_name", "displayName",
            "chat_title", "chatTitle", "room_title", "roomTitle", "user_name", "userName"
        ]

        return stringValue(from: item, keys: memberNameKeys)
    }

    private func parseMessages(from output: String) -> [KakaoTalkMessageItem] {
        guard let data = output.data(using: .utf8) else {
            return []
        }

        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return parseMessageArray(array)
        }

        if let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let array =
            dictionary["messages"] as? [[String: Any]] ??
            dictionary["data"] as? [[String: Any]] ??
            dictionary["items"] as? [[String: Any]] {
            return parseMessageArray(array)
        }

        return []
    }

    private func parseMessageArray(_ array: [[String: Any]]) -> [KakaoTalkMessageItem] {
        array.compactMap { item in
            let text =
                item["text"] as? String ??
                item["message"] as? String ??
                item["body"] as? String ??
                item["content"] as? String

            guard let text,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            let sender =
                item["sender"] as? String ??
                item["user"] as? String ??
                item["author"] as? String ??
                item["sender_name"] as? String

            let sentAt =
                item["sent_at"] as? String ??
                item["created_at"] as? String ??
                item["date"] as? String ??
                item["time"] as? String ??
                item["timestamp"] as? String

            let roomName =
                item["chat_name"] as? String ??
                item["chatName"] as? String ??
                item["room_name"] as? String ??
                item["roomName"] as? String

            return KakaoTalkMessageItem(
                sender: sender,
                text: text,
                sentAt: sentAt,
                chatRoomName: roomName
            )
        }
    }

    private func shellEscape(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private func resolvedHelper() throws -> (pythonPath: String, helperPath: String) {
        guard let helperPath,
              let pythonPath else {
            throw KakaoTalkServiceError.helperUnavailable
        }

        return (pythonPath, helperPath)
    }
}

enum KakaoTalkServiceError: LocalizedError {
    case helperUnavailable
    case commandFailed(String)
    case noChatRoomsFound(String)
    case noMessagesFound(String)

    var errorDescription: String? {
        switch self {
        case .helperUnavailable:
            return "KakaoTalk helper를 찾지 못했습니다. k-skill 폴더를 Desktop, Documents, Downloads 또는 Wokey-Toky Application Support 폴더에 두세요."
        case .commandFailed(let message):
            return "KakaoTalk 명령 실행 실패: \(message)"
        case .noChatRoomsFound(let output):
            return "채팅방 목록을 파싱하지 못했습니다. 출력: \(output.prefix(300))"
        case .noMessagesFound(let output):
            return "메시지를 파싱하지 못했습니다. 출력: \(output.prefix(300))"
        }
    }
}
