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

    @Query(sort: \AppNotification.createdAt, order: .reverse)
    private var appNotifications: [AppNotification]

    @EnvironmentObject private var captureManager: ContextCaptureManager
    @State private var selectedSection: AppSection = .today
    @State private var showChat = false
    @State private var showNotifications = false
    @State private var showNotificationHistory = false
    @State private var isChatHovered = false
    @State private var isNotificationHovered = false
    @State private var notificationHistoryLimit = 30
    @State private var selectedNotificationFilter: NotificationHistoryFilter = .all

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
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                workStateMenu
                notificationButton
            }
        }

        .overlay {
            if showNotificationHistory {
                ZStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showNotificationHistory = false
                        }
                    } label: {
                        Rectangle()
                            .fill(Color.black.opacity(0.18))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea(.all)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    notificationHistorySheet
                        .padding(40)
                        .transition(
                            .opacity
                                .combined(with: .scale(scale: 0.97))
                        )
                }
                .zIndex(100)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !showChat {
                Button {
                    showChat = true
                } label: {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(WokeyDesign.ink)
                        .frame(width: 46, height: 46)
                        .background(
                            Circle()
                                .fill(isChatHovered ? WokeyDesign.selection : WokeyDesign.panel)
                        )
                        .overlay {
                            Circle()
                                .stroke(WokeyDesign.hairline, lineWidth: 1)
                        }
                        .shadow(
                            color: Color.black.opacity(isChatHovered ? 0.14 : 0.09),
                            radius: isChatHovered ? 14 : 10,
                            x: 0,
                            y: isChatHovered ? 7 : 5
                        )
                        .scaleEffect(isChatHovered ? 1.035 : 1)
                        .contentShape(Circle())
                        .accessibilityLabel("Chat 열기")
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    withAnimation(.easeOut(duration: 0.14)) {
                        isChatHovered = isHovered
                    }
                }
                .padding(22)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .overlay {
            if showChat {
                ZStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            showChat = false
                        }
                    } label: {
                        Rectangle()
                            .fill(Color.black.opacity(0.18))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea(.all)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    ZStack(alignment: .topTrailing) {
                        ChatView()
                            .environmentObject(captureManager)
                            .frame(width: 760, height: 640)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(WokeyDesign.hairline, lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.18), radius: 26, x: 0, y: 14)

                        Button {
                            withAnimation(.easeOut(duration: 0.16)) {
                                showChat = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(WokeyDesign.ink)
                                .frame(width: 28, height: 28)
                                .background(WokeyDesign.quietFill)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                        .help("Chat 닫기")
                        .padding(16)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                .zIndex(90)
            }
        }
    }
    private var workStateMenu: some View {
        Menu {
            ForEach(UserWorkState.allCases) { state in
                Button {
                    captureManager.setUserWorkState(
                        state,
                        modelContext: modelContext
                    )
                } label: {
                    Label {
                        Text(state.displayName)
                    } icon: {
                        if captureManager.userWorkState == state {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(workStateIndicatorColor)
                    .frame(width: 8, height: 8)

                Text(captureManager.userWorkState.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.ink)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WokeyDesign.muted)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(WokeyDesign.panel)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(WokeyDesign.hairline, lineWidth: 1)
            }
            .contentShape(Capsule())
            .accessibilityLabel("현재 사용자 상태")
            .accessibilityValue(captureManager.userWorkState.displayName)
        }
        .menuStyle(.borderlessButton)
        .help("사용자 상태 변경")
    }

    private var workStateIndicatorColor: Color {
        switch captureManager.userWorkState {
        case .working:
            return WokeyDesign.blue
        case .resting:
            return .orange
        case .away:
            return WokeyDesign.muted
        }
    }

    private var notificationButton: some View {
        Button {
            showNotifications.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(isNotificationHovered ? WokeyDesign.selection : WokeyDesign.panel)
                        .frame(width: 34, height: 34)
                        .overlay {
                            Circle()
                                .stroke(WokeyDesign.hairline, lineWidth: 1)
                        }

                    Image(systemName: unreadNotifications.isEmpty ? "bell" : "bell.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WokeyDesign.ink)
                }
                .frame(width: 34, height: 34)

                if !unreadNotifications.isEmpty {
                    Text(unreadBadgeText)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(WokeyDesign.active)
                        .clipShape(Capsule())
                        .offset(x: 5, y: -4)
                }
            }
            .frame(width: 34, height: 34)
            .contentShape(Circle())
            .accessibilityLabel("알림")
            .accessibilityValue("읽지 않은 알림 \(unreadNotifications.count)개")
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeOut(duration: 0.12)) {
                isNotificationHovered = isHovered
            }
        }
        .help("알림")
        .popover(isPresented: $showNotifications, arrowEdge: .top) {
            notificationPopover
        }
    }

    private var unreadNotifications: [AppNotification] {
        appNotifications.filter { !$0.isResolved }
    }

    private var unreadBadgeText: String {
        unreadNotifications.count > 99 ? "99+" : "\(unreadNotifications.count)"
    }

    private var recentResolvedNotifications: [AppNotification] {
        Array(appNotifications.filter(\.isResolved).prefix(3))
    }

    private var hiddenUnreadNotificationCount: Int {
        max(0, unreadNotifications.count - 10)
    }

    private var filteredHistoryNotifications: [AppNotification] {
        switch selectedNotificationFilter {
        case .all:
            return appNotifications
        case .unread:
            return unreadNotifications
        case .read:
            return appNotifications.filter(\.isResolved)
        }
    }

    private var notificationPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("알림")
                        .font(.title3)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text("읽지 않음 \(unreadNotifications.count)개")
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                Button("모두 읽음") {
                    markAllNotificationsResolved()
                }
                .disabled(unreadNotifications.isEmpty)
            }
            .padding(16)

            Divider()

            if unreadNotifications.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("새로운 알림이 없습니다.")
                        .font(.subheadline)
                        .foregroundStyle(WokeyDesign.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 18)

                    if !recentResolvedNotifications.isEmpty {
                        Text("최근 알림")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(WokeyDesign.muted)
                            .padding(.horizontal, 16)

                        ForEach(recentResolvedNotifications) { notification in
                            notificationRow(notification, isMuted: true)
                        }
                    }
                }
                .frame(width: 380)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(unreadNotifications.prefix(10)) { notification in
                            notificationRow(notification)

                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .frame(width: 380, height: min(360, CGFloat(unreadNotifications.prefix(10).count) * 92))

                if hiddenUnreadNotificationCount > 0 {
                    Button("읽지 않은 알림 \(hiddenUnreadNotificationCount)개 더 보기") {
                        openNotificationHistory(filter: .unread)
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(WokeyDesign.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                    Divider()
                }
            }

            Button {
                openNotificationHistory(filter: .all)
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("알림 히스토리 보기")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(WokeyDesign.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(WokeyDesign.panel)
    }

    private func notificationRow(
        _ notification: AppNotification,
        isMuted: Bool = false
    ) -> some View {
        Button {
            handleNotificationSelection(notification)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isMuted || notification.isResolved ? WokeyDesign.quietFill : WokeyDesign.selection)
                        .frame(width: 34, height: 34)

                    Image(systemName: notificationSystemImage(notification))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isMuted || notification.isResolved ? WokeyDesign.muted : WokeyDesign.ink)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundStyle(isMuted ? WokeyDesign.muted : WokeyDesign.ink)
                            .lineLimit(1)

                        Spacer()

                        Text(notification.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(WokeyDesign.muted)
                    }

                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundStyle(WokeyDesign.muted)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if let relatedTaskTitle = notification.relatedTaskTitle,
                       !relatedTaskTitle.isEmpty {
                        Text(relatedTaskTitle)
                            .font(.caption)
                            .foregroundStyle(WokeyDesign.blue)
                            .lineLimit(1)
                    }
                }

                if !isMuted && !notification.isResolved {
                    Circle()
                        .fill(WokeyDesign.active)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func notificationSystemImage(_ notification: AppNotification) -> String {
        switch notification.kind {
        case "taskChange":
            return "arrow.triangle.2.circlepath"
        case "taskCandidate":
            return "checklist"
        case "rollback":
            return "arrow.uturn.backward"
        case "kakaoTalk":
            return "message.fill"
        default:
            return "bell.fill"
        }
    }

    private func handleNotificationSelection(_ notification: AppNotification) {
        if !notification.isResolved {
            notification.isResolved = true
            notification.resolvedAt = Date()
            try? modelContext.save()
        }

        switch notification.kind {
        case "taskCandidate", "kakaoTalk":
            selectedSection = .importData
        case "taskChange", "rollback":
            selectedSection = .briefing
        default:
            selectedSection = .today
        }

        showNotificationHistory = false
        showNotifications = false
    }

    private func markAllNotificationsResolved() {
        let now = Date()

        for notification in unreadNotifications {
            notification.isResolved = true
            notification.resolvedAt = now
        }

        try? modelContext.save()
    }

    private var notificationHistorySheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("알림 히스토리")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(WokeyDesign.ink)

                    Text("읽은 알림과 읽지 않은 알림을 분류해 확인합니다.")
                        .font(.subheadline)
                        .foregroundStyle(WokeyDesign.muted)
                }

                Spacer()

                Button("모두 읽음") {
                    markAllNotificationsResolved()
                }
                .disabled(unreadNotifications.isEmpty)

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        showNotificationHistory = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WokeyDesign.ink)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(WokeyDesign.quietFill)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("알림 히스토리 닫기")
            }
            .padding(WokeyDesign.pagePadding)

            Picker("알림 필터", selection: $selectedNotificationFilter) {
                ForEach(NotificationHistoryFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, WokeyDesign.pagePadding)
            .padding(.bottom, 16)

            Divider()

            if filteredHistoryNotifications.isEmpty {
                ContentUnavailableView(
                    "표시할 알림이 없습니다",
                    systemImage: "bell.slash",
                    description: Text("선택한 조건에 맞는 알림이 없습니다.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredHistoryNotifications.prefix(notificationHistoryLimit)) { notification in
                            notificationRow(notification)

                            Divider()
                                .padding(.leading, 52)
                        }

                        if filteredHistoryNotifications.count > notificationHistoryLimit {
                            Button("더 보기") {
                                notificationHistoryLimit += 30
                            }
                            .buttonStyle(.bordered)
                            .padding(20)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(width: 680, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 12)
    }

    private func openNotificationHistory(filter: NotificationHistoryFilter) {
        selectedNotificationFilter = filter
        notificationHistoryLimit = 30
        showNotifications = false

        DispatchQueue.main.async {
            showNotificationHistory = true
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

        case .summary:
            SummaryView()

        case .settings:
            SettingsView()

        case .privacy:
            PrivacyView()
        }
    }

    private enum NotificationHistoryFilter: String, CaseIterable, Identifiable {
        case all
        case unread
        case read

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "전체"
            case .unread:
                return "읽지 않음"
            case .read:
                return "읽음"
            }
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
}
