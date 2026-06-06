//
//  ContentView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var captureManager = ContextCaptureManager()
    @State private var selectedSection: AppSection = .today
    @State private var showChat = false

    var body: some View {
        TabView(selection: $selectedSection) {
            ForEach(AppSection.allCases) { section in
                selectedContent(for: section)
                    .tabItem {
                        Label(section.title, systemImage: section.systemImage)
                    }
                    .tag(section)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(WokeyDesign.blue)
        .wokeyPageBackground()
        .environmentObject(captureManager)
        .toolbar {
            ToolbarItem {
                Button {
                    showChat = true
                } label: {
                    Label("Chat", systemImage: "bubble.left.and.text.bubble.right")
                }
            }
        }
        .sheet(isPresented: $showChat) {
            ChatView()
                .environmentObject(captureManager)
                .frame(minWidth: 720, minHeight: 620)
        }
    }

    @ViewBuilder
    private func selectedContent(for section: AppSection) -> some View {
        switch section {
        case .today:
            TodayView()

        case .activity:
            ActivityHubView()

        case .schedule:
            TasksView()

        case .importData:
            ImportHubView()

        case .briefing:
            BriefingView()

        case .chat:
            ChatView()

        case .summary:
            SummaryView()

        case .settings:
            SettingsView()

        case .privacy:
            PrivacyView()
        }
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case today
    case activity
    case schedule
    case importData
    case briefing
    case chat
    case summary
    case settings
    case privacy

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .activity:
            return "오늘의 활동"
        case .schedule:
            return "Schedule"
        case .importData:
            return "Import"
        case .briefing:
            return "Briefing"
        case .chat:
            return "Chat"
        case .summary:
            return "Summary"
        case .settings:
            return "Settings"
        case .privacy:
            return "Privacy"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            return "house"
        case .activity:
            return "waveform.path.ecg"
        case .schedule:
            return "calendar.badge.clock"
        case .importData:
            return "square.and.arrow.down"
        case .briefing:
            return "text.bubble"
        case .chat:
            return "bubble.left.and.text.bubble.right"
        case .summary:
            return "chart.pie"
        case .settings:
            return "gearshape"
        case .privacy:
            return "lock.shield"
        }
    }
}
