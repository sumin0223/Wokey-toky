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
    @EnvironmentObject private var captureManager: ContextCaptureManager

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var events: [ActivityEvent]

    @State private var showFilterSettings = false

    private let captureService = ActivityCaptureService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                headerSection

                appUsageSection

                currentScreenSection

                eventHistorySection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            captureManager.refreshOnly()
        }
        .sheet(isPresented: $showFilterSettings) {
            ActivityFilterSettingsView(
                recentSiteHosts: recentSiteHosts
            )
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Activity")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Text("오늘 사용한 앱과 현재 화면 흐름을 가볍게 확인합니다.")
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
            }

            Spacer()

            HStack(spacing: 10) {
                Button("전체 삭제") {
                    deleteAllEvents()
                }
                .buttonStyle(.bordered)

                Button("새로고침") {
                    captureManager.refreshOnly()
                }
                .buttonStyle(.bordered)

                Button {
                    showFilterSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 30)
                }
                .buttonStyle(.bordered)
                .help("활동 기록 설정")
            }
        }
    }

    private var appUsageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("오늘 앱 사용 비율")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            if appUsageRows.isEmpty {
                Text("아직 오늘 기록이 부족합니다.")
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                ForEach(appUsageRows.prefix(8), id: \.appName) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(row.appName)
                                .font(.subheadline)
                                .bold()

                            Spacer()

                            Text("\(row.minutes)분 · \(Int(row.ratio * 100))%")
                                .font(.caption)
                                .foregroundStyle(WokeyDesign.muted)
                        }

                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(WokeyDesign.blue.opacity(0.12))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [WokeyDesign.blue.opacity(0.72), WokeyDesign.mint.opacity(0.72)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(4, geometry.size.width * row.ratio))
                                }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var currentScreenSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("현재 화면")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            if captureManager.latestWindows.isEmpty {
                Text("현재 화면 정보를 불러오지 못했습니다.")
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                ForEach(captureManager.latestWindows.prefix(6)) { window in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(WokeyDesign.active)
                            .frame(width: 8, height: 8)
                            .shadow(color: WokeyDesign.active.opacity(0.35), radius: 6, x: 0, y: 0)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(window.appName)
                                .font(.headline)

                            Text(window.windowTitle.isEmpty ? "창 제목 없음" : window.windowTitle)
                                .font(.caption)
                                .foregroundStyle(WokeyDesign.muted)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(windowLabel(window))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(windowClassificationColor(window))
                            .frame(width: 92, height: 28)
                            .background(windowClassificationColor(window).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var eventHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("활동 기록")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            if events.isEmpty {
                ContentUnavailableView(
                    "아직 기록이 없습니다",
                    systemImage: "clock",
                    description: Text("Today에서 수집을 켜면 선택한 앱만 기록됩니다.")
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(events.prefix(40)) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func eventRow(_ event: ActivityEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.appName)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text(activityTimeRangeText(event))
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            Text((event.windowTitle?.isEmpty == false ? event.windowTitle : "창 제목 없음") ?? "창 제목 없음")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)

            if let url = event.url,
               !url.isEmpty {
                Text(url)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.blue)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
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

        guard ActivityFilterSettings.allows(
            appName: captured.appName,
            bundleIdentifier: captured.bundleIdentifier,
            url: captured.url
        ) else {
            return
        }

        if let latest = events.first,
           latest.appName == captured.appName,
           latest.bundleIdentifier == captured.bundleIdentifier {
            return
        }

        let event = ActivityEvent(
            appName: captured.appName,
            bundleIdentifier: captured.bundleIdentifier,
            windowTitle: captured.windowTitle,
            url: captured.url
        )

        modelContext.insert(event)
    }
    
    private func deleteAllEvents() {
        for event in events {
            modelContext.delete(event)
        }
    }

    private var todayEvents: [ActivityEvent] {
        events.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    private var recentSiteHosts: [String] {
        let hosts = events.compactMap {
            ActivityFilterSettings.host(from: $0.url)
        }

        return Array(Set(hosts)).sorted()
    }

    private var appUsageRows: [(appName: String, minutes: Int, ratio: Double)] {
        let grouped = Dictionary(grouping: todayEvents, by: \.appName)
        let rows = grouped.map { appName, events in
            let seconds = events.reduce(0.0) { result, event in
                let end = event.endedAt ?? Date()
                return result + max(0, end.timeIntervalSince(event.startedAt))
            }

            return (appName: appName, seconds: seconds)
        }
        .filter { $0.seconds > 0 }

        let total = rows.reduce(0.0) { $0 + $1.seconds }

        guard total > 0 else {
            return []
        }

        return rows
            .sorted { $0.seconds > $1.seconds }
            .map { row in
                (
                    appName: row.appName,
                    minutes: max(1, Int(row.seconds / 60)),
                    ratio: row.seconds / total
                )
            }
    }

    private func windowLabel(_ window: VisibleWindow) -> String {
        switch window.classification {
        case .primary:
            return "집중 창"
        case .mainVisible:
            return "함께 보는 창"
        case .peripheral:
            return "보조 창"
        case .stageManagerCandidate:
            return "스테이지 후보"
        case .systemWindow:
            return "시스템"
        }
    }

    private func windowClassificationColor(_ window: VisibleWindow) -> Color {
        switch window.classification {
        case .primary:
            return WokeyDesign.blue
        case .mainVisible:
            return WokeyDesign.mint
        case .peripheral:
            return WokeyDesign.muted
        case .stageManagerCandidate:
            return WokeyDesign.muted
        case .systemWindow:
            return WokeyDesign.muted
        }
    }
}

private struct ActivityFilterSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let recentSiteHosts: [String]

    @State private var installedApps: [ActivityFilterApp] = []
    @State private var selectedAppKeys: Set<String> = []
    @State private var selectedSiteHosts: Set<String> = []
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            headerSection

            TextField("앱 검색", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    appFilterSection

                    if !recentSiteHosts.isEmpty {
                        siteFilterSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("전체 선택") {
                    selectedAppKeys = Set(installedApps.map(\.id))
                    selectedSiteHosts = Set(recentSiteHosts)
                    persist()
                }

                Button("전체 해제") {
                    selectedAppKeys = []
                    selectedSiteHosts = []
                    persist()
                }

                Spacer()

                Button("완료") {
                    persist()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 620, height: 680)
        .onAppear {
            loadFilters()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("활동 기록 설정")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            Text("체크한 앱과 사이트만 Activity 기록에 쌓입니다.")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)
        }
    }

    private var appFilterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("앱")
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text("\(selectedAppKeys.count)/\(installedApps.count)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(filteredApps) { app in
                    Toggle(
                        isOn: Binding(
                            get: { selectedAppKeys.contains(app.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedAppKeys.insert(app.id)
                                } else {
                                    selectedAppKeys.remove(app.id)
                                }

                                persist()
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.subheadline)
                                .foregroundStyle(WokeyDesign.ink)

                            if let bundleIdentifier = app.bundleIdentifier {
                                Text(bundleIdentifier)
                                    .font(.caption2)
                                    .foregroundStyle(WokeyDesign.muted)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private var siteFilterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("사이트")
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text("\(selectedSiteHosts.count)/\(recentSiteHosts.count)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(recentSiteHosts, id: \.self) { host in
                    Toggle(
                        host,
                        isOn: Binding(
                            get: { selectedSiteHosts.contains(host) },
                            set: { isSelected in
                                if isSelected {
                                    selectedSiteHosts.insert(host)
                                } else {
                                    selectedSiteHosts.remove(host)
                                }

                                persist()
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.ink)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var filteredApps: [ActivityFilterApp] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return installedApps
        }

        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func loadFilters() {
        installedApps = ActivityAppCatalog.installedApplications()

        if ActivityFilterSettings.isConfigured {
            selectedAppKeys = ActivityFilterSettings.selectedAppKeys
        } else {
            selectedAppKeys = Set(installedApps.map(\.id))
        }

        if ActivityFilterSettings.isSiteConfigured {
            selectedSiteHosts = ActivityFilterSettings.selectedSiteHosts
        } else {
            selectedSiteHosts = Set(recentSiteHosts)
        }
    }

    private func persist() {
        ActivityFilterSettings.saveSelectedAppKeys(selectedAppKeys)
        ActivityFilterSettings.saveSelectedSiteHosts(selectedSiteHosts)
    }
}
