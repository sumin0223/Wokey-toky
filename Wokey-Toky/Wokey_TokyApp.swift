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
    @StateObject private var captureManager = ContextCaptureManager()
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
            UserWorkStateSession.self,
        ])

        let modelConfiguration = ModelConfiguration(
            "WokeyTokyStoreV3",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            print("ModelContainer Error:", error)
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(captureManager)
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra("🐰", systemImage: "hare.fill") {
            MenuBarView()
                .environmentObject(captureManager)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)
    }
}
