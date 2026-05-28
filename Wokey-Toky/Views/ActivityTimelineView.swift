//
//  ActivityTimelineView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

struct ActivityTimelineView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var events: [ActivityEvent]

    private let captureService = ActivityCaptureService()

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("오늘의 활동")
                    .font(.largeTitle)
                    .bold()

                Spacer()
                
                Button("전체 삭제") {
                        deleteAllEvents()
                    }

                Button("현재 앱 기록") {
                    captureCurrentApp()
                }
            }
            .padding(.bottom)

            if events.isEmpty {
                ContentUnavailableView(
                    "아직 기록이 없습니다",
                    systemImage: "clock",
                    description: Text("오른쪽 위의 현재 앱 기록 버튼을 눌러보세요.")
                )
            } else {
                List(events) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.appName)
                            .font(.headline)

                        if let windowTitle = event.windowTitle,
                           !windowTitle.isEmpty {
                            Text(windowTitle)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        } else {
                            Text("창 제목 없음")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let url = event.url,
                           !url.isEmpty {
                            Text(url)
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                        }

                        if let bundleIdentifier = event.bundleIdentifier {
                            Text(bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(activityTimeRangeText(event))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }
    
    private func activityTimeRangeText(_ event: ActivityEvent) -> String {
        let start = event.startedAt.formatted(date: .omitted, time: .shortened)

        if let endedAt = event.endedAt {
            let end = endedAt.formatted(date: .omitted, time: .shortened)
            return "\(start) - \(end)"
        } else {
            return "\(start) - 현재"
        }
    }

    private func captureCurrentApp() {
        guard let captured = captureService.captureFrontmostApp() else {
            return
        }

        if let latest = events.first,
           latest.appName == captured.appName,
           latest.bundleIdentifier == captured.bundleIdentifier {
            return
        }

        let event = ActivityEvent(
            appName: captured.appName,
            bundleIdentifier: captured.bundleIdentifier
        )

        modelContext.insert(event)
    }
    
    private func deleteAllEvents() {
        for event in events {
            modelContext.delete(event)
        }
    }
}
