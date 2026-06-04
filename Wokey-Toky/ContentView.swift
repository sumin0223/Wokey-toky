//
//  ContentView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var captureManager = ContextCaptureManager()
    @Query private var llmConfigs: [LLMConfig]
    @State private var showClaudeOnboarding = false
    @State private var showChat = false
    @State private var selectedSection: AppSection = .today
    
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
                .frame(minWidth: 720, minHeight: 620)
        }
        .sheet(isPresented: $showClaudeOnboarding) {
            ClaudeAPIKeyOnboardingView(
                config: llmConfigs.first,
                onComplete: {
                    showClaudeOnboarding = false
                }
            )
        }
        .onAppear {
            clearLegacyClaudeAPIKeys()
            showClaudeOnboardingIfNeeded()
        }
        .onChange(of: llmConfigs.count) { _, _ in
            clearLegacyClaudeAPIKeys()
            showClaudeOnboardingIfNeeded()
        }
    }

    @ViewBuilder
    private func selectedContent(for section: AppSection) -> some View {
        switch section {
        case .today:
            TodayView()
        case .activity:
            ActivityTimelineView()
        case .schedule:
            TasksView()
        case .importData:
            CalendarImportView()
        case .briefing:
            BriefingView()
        case .summary:
            SummaryView()
        case .settings:
            SettingsView()
        case .privacy:
            PrivacyView()
        }
    }

    private func showClaudeOnboardingIfNeeded() {
        guard !showClaudeOnboarding else {
            return
        }

        guard let config = llmConfigs.first else {
            showClaudeOnboarding = true
            return
        }

        let hasClaudeKey = !config.claudeAPIKeyResolved
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        if config.isClaudeEnabledResolved && !hasClaudeKey {
            showClaudeOnboarding = true
        }
    }

    private func clearLegacyClaudeAPIKeys() {
        var didChange = false

        for config in llmConfigs {
            if let legacyKey = config.claudeAPIKey,
               !legacyKey.isEmpty {
                config.claudeAPIKey = ""
                config.updatedAt = Date()
                didChange = true
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case today
    case activity
    case schedule
    case importData
    case briefing
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
            return "Activity"
        case .schedule:
            return "Schedule"
        case .importData:
            return "Import"
        case .briefing:
            return "Briefing"
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
        case .summary:
            return "chart.pie"
        case .settings:
            return "gearshape"
        case .privacy:
            return "lock.shield"
        }
    }

    static var primary: [AppSection] {
        [.today, .activity, .schedule, .importData, .briefing, .summary]
    }

    static var secondary: [AppSection] {
        [.settings, .privacy]
    }
}
