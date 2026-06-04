//
//  Wokey_TokyApp.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct Wokey_TokyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ActivityEvent.self,
            ScreenContextSnapshot.self,
            VisibleWindowRecord.self,
            TaskItem.self,
            Suggestion.self,
            DailySummary.self,
            LLMConfig.self,
            Briefing.self,
            UserTaskResponse.self,
            ResponseSettings.self,
            ChatMessage.self,
            TaskCandidate.self,
            SourceImport.self,
            KakaoTalkSettings.self,
            AppNotification.self,
            TaskChangeLog.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra("Wokey-Toky", systemImage: "bubble.left.and.text.bubble.right.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)
    }
}
