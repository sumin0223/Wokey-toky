//
//  NotificationService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/12/26.
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Notification authorization error: \(error.localizedDescription)")
            return false
        }
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🐰 Wokey-Toky"
        content.body = "알림이 정상적으로 동작합니다."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 3,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "wokey_test_notification_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("Failed to add test notification: \(error.localizedDescription)")
                } else {
                    print("Test notification scheduled")
                }
            }
    }

    func scheduleBriefingNotification(
        type: BriefingType,
        hour: Int,
        minute: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = "🐰 \(type.displayName)"
        content.body = notificationBody(for: type)
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "wokey_briefing_\(type.rawValue)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleTaskConfirmationNotification(
        taskCount: Int
    ) {
        guard taskCount > 0 else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "🐰 확인이 필요한 할 일이 있어요"
        content.body = "\(taskCount)개의 할 일이 완료 여부 확인을 기다리고 있어요."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 5,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "wokey_task_confirmation_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func removeAllScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func notificationBody(for type: BriefingType) -> String {
        switch type {
        case .morning:
            return "오늘 해야 할 일을 정리할 시간이에요."
        case .lunch:
            return "오전 업무 진행 상황을 점검해볼까요?"
        case .evening:
            return "오늘 완료한 일과 내일로 넘길 일을 정리해요."
        }
    }
}
