//
//  ContentView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var captureManager = ContextCaptureManager()
    
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("Today") {
                    TodayView()
                }
                
                NavigationLink("오늘의 활동") {
                    ActivityTimelineView()
                }
                
                NavigationLink("화면 창 목록") {
                    VisibleWindowsView()
                }
                
                NavigationLink("저장된 화면 기록") {
                    WindowRecordsView()
                }
                
                NavigationLink("Tasks") {
                    TasksView()
                }
                
                NavigationLink("Calendar Import") {
                    CalendarImportView()
                }
                
                NavigationLink("Text Import") {
                    TextImportView()
                }
                
                NavigationLink("Apple Notes Import") {
                    AppleNotesImportView()
                }
                
                NavigationLink("KakaoTalk Import") {
                    KakaoTalkImportView()
                }
                
                NavigationLink("Briefing") {
                    BriefingView()
                }
                
                NavigationLink("Chat") {
                    ChatView()
                }
                
                NavigationLink("Summary") {
                    SummaryView()
                }

                NavigationLink("Settings") {
                    SettingsView()
                }

                NavigationLink("Privacy") {
                    PrivacyView()
                }
            }
            .navigationTitle("Wokey-Toky")
        } detail: {
            TodayView()
        }
        .environmentObject(captureManager)
    }
}
