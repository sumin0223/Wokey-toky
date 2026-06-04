//
//  SummaryView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import SwiftUI
import SwiftData
import AppKit

struct SummaryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ActivityEvent.startedAt, order: .reverse)
    private var activities: [ActivityEvent]

    @Query(sort: \ScreenContextSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ScreenContextSnapshot]

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @Query(sort: \Suggestion.createdAt, order: .reverse)
    private var suggestions: [Suggestion]

    @Query(sort: \DailySummary.createdAt, order: .reverse)
    private var summaries: [DailySummary]

    @Query(sort: \Briefing.createdAt, order: .reverse)
    private var briefings: [Briefing]
    
    @Query private var llmConfigs: [LLMConfig]

    @State private var sourceLog: String = ""
    @State private var generatedSummary: String = ""
    @State private var isGeneratingLLMSummary = false
    @State private var llmErrorMessage: String?
    @State private var selectedDate = Date()

    private let logBuilder = DailyLogBuilder()
    private let llmService = LLMService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
                headerSection

                plannerSummaryCard

                actionSection
                
                errorSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear {
            buildLogPreview()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Summary")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Text("캘린더에서 날짜를 선택해 과거 기록, 활동 비율, 하루 요약을 확인합니다.")
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
            }

            Spacer()
        }
    }

    private var plannerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 24) {
                calendarPanel
                    .frame(width: 460, alignment: .topLeading)

                eventSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()

            HStack(alignment: .top, spacing: 24) {
                kakaoMessageSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                taskStatusSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            dailySummaryTextSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your events")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(WokeyDesign.selection)
                    .clipShape(Capsule())
            }

            if selectedPhysicalEvents.isEmpty {
                inlineEmptyState("해당 날짜의 물리적 약속이 없습니다.")
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(selectedPhysicalEvents.prefix(5)) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: TaskItem) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(eventDayText(event))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(WokeyDesign.ink)

                Text(eventWeekdayText(event))
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }
            .frame(width: 54)

            Divider()
                .frame(height: 46)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)
                        .lineLimit(1)

                    if shouldShowInProgress(event) {
                        Text("진행 중")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 10) {
                    Label(eventTimeRange(event), systemImage: "calendar")

                    if let detail = event.detail,
                       !detail.isEmpty {
                        Label(detail.components(separatedBy: "\n").first ?? detail, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
    }

    private var kakaoMessageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Messages and notices")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text("Kakao")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(WokeyDesign.selection)
                    .clipShape(Capsule())
            }

            if kakaoMessageTasks.isEmpty {
                inlineEmptyState("카카오톡에서 Task로 분류된 메시지가 없습니다.")
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(kakaoMessageTasks.prefix(5)) { task in
                        kakaoMessageRow(task)
                    }
                }
            }
        }
    }

    private func kakaoMessageRow(_ task: TaskItem) -> some View {
        Button {
            openKakaoTalk()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 36, height: 36)

                    Text(kakaoInitial(for: task))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(WokeyDesign.ink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(kakaoSenderName(for: task))
                            .font(.headline)
                            .foregroundStyle(WokeyDesign.ink)

                        Text(task.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(WokeyDesign.muted)
                    }

                    Text(task.detail ?? task.title)
                        .font(.subheadline)
                        .foregroundStyle(WokeyDesign.ink)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.54))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var taskStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Task")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text("\(selectedTaskItems.count) items")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            taskGroup(title: "완료한 것", tasks: completedTaskItems, symbol: "checkmark.circle.fill")
            taskGroup(title: "진행중인 것", tasks: inProgressTaskItems, symbol: "play.circle.fill")
            taskGroup(title: "미완료", tasks: pendingTaskItems, symbol: "circle")
        }
    }

    private func taskGroup(title: String, tasks: [TaskItem], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(WokeyDesign.ink)

            if tasks.isEmpty {
                Text("없음")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ForEach(tasks.prefix(3)) { task in
                    HStack(spacing: 10) {
                        Image(systemName: symbol)
                            .foregroundStyle(WokeyDesign.blue)
                            .frame(width: 18)

                        Text(task.title)
                            .font(.subheadline)
                            .foregroundStyle(WokeyDesign.ink)
                            .lineLimit(1)

                        Spacer()

                        if let dueAt = task.dueAt {
                            Text(dueAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(WokeyDesign.muted)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132, alignment: .topLeading)
        .padding(14)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dailySummaryTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily summary")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                if let latestTodaySummary {
                    Text(latestTodaySummary.updatedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                }
            }

            Text(summaryTextForSelectedDate)
                .font(.body)
                .foregroundStyle(WokeyDesign.ink)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .padding(16)
                .background(Color.white.opacity(0.54))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .textSelection(.enabled)
        }
    }

    private var calendarPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calendar")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(WokeyDesign.ink)

            WokeyMonthCalendar(
                selectedDate: $selectedDate,
                markedDays: markedDayKeys
            )
        }
        .onChange(of: selectedDate) { _, _ in
            buildLogPreview()
        }
    }

    private var dateRecordCard: some View {
        VStack(alignment: .leading, spacing: 28) {
            calendarPanel

            Divider()

            selectedDayOverview

            HStack(alignment: .top, spacing: WokeyDesign.sectionSpacing) {
                activityBreakdownSection
                    .frame(maxWidth: .infinity)

                dayTimelineSection
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var selectedDayOverview: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate.formatted(.dateTime.day().weekday(.wide)))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(WokeyDesign.ink)

                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.muted)
            }

            Spacer()

            miniMetric(title: "Activity", value: "\(selectedActivities.count)", subtitle: "records")
            miniMetric(title: "Schedule", value: "\(selectedTasks.count)", subtitle: "items")
            miniMetric(title: "Briefing", value: "\(selectedBriefings.count)", subtitle: "reports")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func miniMetric(
        title: String,
        value: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(WokeyDesign.blue)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(WokeyDesign.muted)
        }
        .frame(width: 86, alignment: .leading)
    }

    private var actionSection: some View {
        HStack {
            Button("기록 새로고침") {
                buildLogPreview()
            }

            Button("규칙 요약 생성") {
                generateMockSummary()
            }
            
            Button(isGeneratingLLMSummary ? "AI 요약 생성 중..." : "AI 요약 생성") {
                Task {
                    await generateLLMSummary()
                }
            }
            .disabled(isGeneratingLLMSummary)

            Button("요약 저장") {
                saveSummary()
            }
            .disabled(generatedSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()

            if let latest = latestTodaySummary {
                Text("마지막 저장: \(latest.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }
        }
        .wokeyPanel()
    }
    
    private var errorSection: some View {
        Group {
            if let llmErrorMessage {
                Text(llmErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var activityBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("활동 비율")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            if appUsageRows.isEmpty {
                compactEmptyState(
                    systemImage: "chart.pie",
                    title: "활동 기록 없음",
                    subtitle: "기록이 생기면 앱 사용 비율이 표시됩니다."
                )
            } else {
                HStack(alignment: .center, spacing: 24) {
                    ZStack {
                        ForEach(Array(appUsageRows.enumerated()), id: \.element.appName) { index, row in
                            PieSlice(
                                startAngle: angleStart(for: index),
                                endAngle: angleEnd(for: index)
                            )
                            .fill(pieColors[index % pieColors.count])
                        }
                    }
                    .frame(width: 180, height: 180)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(appUsageRows.enumerated()), id: \.element.appName) { index, row in
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(pieColors[index % pieColors.count])
                                    .frame(width: 12, height: 12)

                                Text(row.appName)
                                    .font(.subheadline)

                                Spacer()

                                Text("\(row.minutes)분 · \(Int(row.ratio * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(WokeyDesign.muted)
                            }
                        }
                    }
                }
            }
        }
    }

    private var dayTimelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("선택한 날짜의 기록")
                .font(.title2)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            if selectedTasks.isEmpty && selectedActivities.isEmpty && selectedBriefings.isEmpty {
                compactEmptyState(
                    systemImage: "tray",
                    title: "기록 없음",
                    subtitle: "캘린더에서 점이 있는 날짜를 선택하면 기록을 볼 수 있습니다."
                )
            } else {
                ForEach(selectedTasks.prefix(8)) { task in
                    timelineRow(
                        icon: scheduleType(task) == .event ? "calendar" : "checkmark.circle",
                        title: task.title,
                        caption: scheduleCaption(task),
                        tint: scheduleType(task) == .event ? WokeyDesign.blue : WokeyDesign.mint
                    )
                }

                ForEach(selectedActivities.prefix(8)) { activity in
                    timelineRow(
                        icon: "macwindow",
                        title: activity.appName,
                        caption: activity.windowTitle?.isEmpty == false ? activity.windowTitle ?? "" : activityTimeRangeText(activity),
                        tint: WokeyDesign.muted
                    )
                }

                ForEach(selectedBriefings.prefix(3)) { briefing in
                    timelineRow(
                        icon: "text.bubble",
                        title: briefing.title,
                        caption: briefing.createdAt.formatted(date: .omitted, time: .shortened),
                        tint: WokeyDesign.blue
                    )
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("기록 설명")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                ScrollView {
                    Text(sourceLog.isEmpty ? "아직 생성된 기록이 없습니다." : sourceLog)
                        .font(.system(.callout, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WokeyDesign.hairline, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text("요약")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                ScrollView {
                    Text(generatedSummary.isEmpty ? "요약 생성 버튼을 눌러보세요." : generatedSummary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WokeyDesign.hairline, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var savedSummaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Note")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(WokeyDesign.ink)

            if let latest = latestTodaySummary {
                Text(latest.content)
                    .font(.body)
                    .foregroundStyle(WokeyDesign.ink)
                    .lineLimit(10)

                Text("업데이트 \(latest.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            } else {
                Text("선택한 날짜에 저장된 요약이 없습니다.")
                    .font(.body)
                    .foregroundStyle(WokeyDesign.muted)
            }
        }
        .wokeyPanel()
    }

    private func timelineRow(
        icon: String,
        title: String,
        caption: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private func compactEmptyState(
        systemImage: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(WokeyDesign.muted)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WokeyDesign.ink)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(WokeyDesign.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func inlineEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(WokeyDesign.muted)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
            .padding(14)
            .background(Color.white.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var selectedPhysicalEvents: [TaskItem] {
        tasks
            .filter { scheduleType($0) == .event && taskOccurs($0, on: selectedDate) }
            .sorted { eventSortDate($0) < eventSortDate($1) }
    }

    private var selectedTaskItems: [TaskItem] {
        selectedTasks
            .filter { scheduleType($0) == .task }
            .sorted { eventSortDate($0) < eventSortDate($1) }
    }

    private var completedTaskItems: [TaskItem] {
        selectedTaskItems.filter { $0.isCompleted || $0.status == TaskStatus.completed.rawValue }
    }

    private var inProgressTaskItems: [TaskItem] {
        selectedTaskItems.filter {
            !$0.isCompleted &&
            ($0.status == TaskStatus.inProgress.rawValue || $0.status == TaskStatus.uncertain.rawValue)
        }
    }

    private var pendingTaskItems: [TaskItem] {
        selectedTaskItems.filter {
            !$0.isCompleted &&
            $0.status != TaskStatus.inProgress.rawValue &&
            $0.status != TaskStatus.uncertain.rawValue &&
            $0.status != TaskStatus.completed.rawValue
        }
    }

    private var kakaoMessageTasks: [TaskItem] {
        selectedTaskItems.filter { $0.source == "kakaoTalk" || $0.source == "kakaoMessage" }
    }

    private var summaryTextForSelectedDate: String {
        if let latestTodaySummary {
            return latestTodaySummary.content
        }

        if !generatedSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           Calendar.current.isDateInToday(selectedDate) {
            return generatedSummary
        }

        return "선택한 날짜에 저장된 요약이 없습니다. 아래 버튼으로 요약을 생성하면 이 영역에서 날짜별 요약을 확인할 수 있습니다."
    }

    private func taskOccurs(_ task: TaskItem, on date: Date) -> Bool {
        let calendar = Calendar.current

        if let start = task.plannedStartAt,
           let end = task.dueAt {
            let dayStart = calendar.startOfDay(for: date)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            return start < nextDay && end >= dayStart
        }

        if let dueAt = task.dueAt,
           calendar.isDate(dueAt, inSameDayAs: date) {
            return true
        }

        if let plannedStartAt = task.plannedStartAt,
           calendar.isDate(plannedStartAt, inSameDayAs: date) {
            return true
        }

        return calendar.isDate(task.createdAt, inSameDayAs: date)
    }

    private func eventSortDate(_ task: TaskItem) -> Date {
        task.plannedStartAt ?? task.dueAt ?? task.createdAt
    }

    private func shouldShowInProgress(_ event: TaskItem) -> Bool {
        guard let start = event.plannedStartAt,
              let end = event.dueAt else {
            return false
        }

        return !Calendar.current.isDate(start, inSameDayAs: end) &&
            taskOccurs(event, on: selectedDate)
    }

    private func eventDayText(_ event: TaskItem) -> String {
        "\(Calendar.current.component(.day, from: eventSortDate(event)))"
    }

    private func eventWeekdayText(_ event: TaskItem) -> String {
        eventSortDate(event).formatted(.dateTime.weekday(.abbreviated)).uppercased()
    }

    private func eventTimeRange(_ event: TaskItem) -> String {
        if let start = event.plannedStartAt,
           let end = event.dueAt {
            if Calendar.current.isDate(start, inSameDayAs: end) {
                return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
            }

            return "\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))"
        }

        if let dueAt = event.dueAt {
            return dueAt.formatted(date: .abbreviated, time: .shortened)
        }

        return "시간 미정"
    }

    private func kakaoSenderName(for task: TaskItem) -> String {
        task.relatedKeywords?
            .split(separator: ",")
            .first
            .map(String.init) ?? "KakaoTalk"
    }

    private func kakaoInitial(for task: TaskItem) -> String {
        String(kakaoSenderName(for: task).prefix(1))
    }

    private func openKakaoTalk() {
        if let kakaoURL = URL(string: "kakaotalk://") {
            NSWorkspace.shared.open(kakaoURL)
        }
    }

    private var latestTodaySummary: DailySummary? {
        summaries.first {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }

    private func buildLogPreview() {
        sourceLog = logBuilder.buildTodayLog(
            activities: selectedActivities,
            snapshots: selectedSnapshots,
            tasks: selectedTasks,
            suggestions: suggestions
        )
    }

    private func generateMockSummary() {
        if sourceLog.isEmpty {
            buildLogPreview()
        }

        generatedSummary = logBuilder.buildMockSummary(from: sourceLog)
    }

    private func saveSummary() {
        let trimmedSummary = generatedSummary.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSummary.isEmpty else {
            return
        }

        if let existingSummary = latestTodaySummary {
            existingSummary.title = "오늘 요약"
            existingSummary.content = trimmedSummary
            existingSummary.sourceLog = sourceLog
            existingSummary.updatedAt = Date()
        } else {
            let summary = DailySummary(
            date: selectedDate,
            title: "오늘 요약",
            content: trimmedSummary,
            sourceLog: sourceLog
            )

            modelContext.insert(summary)
        }
    }
    
    private var currentLLMConfig: LLMConfig? {
        llmConfigs.first
    }

    private func generateLLMSummary() async {
        if sourceLog.isEmpty {
            buildLogPreview()
        }

        guard let config = currentLLMConfig else {
            llmErrorMessage = "Settings에서 LLM 설정을 먼저 저장해주세요."
            return
        }

        isGeneratingLLMSummary = true
        llmErrorMessage = nil

        do {
            let result = try await llmService.generateDailySummary(
                log: sourceLog,
                config: config
            )

            generatedSummary = result
        } catch {
            llmErrorMessage = error.localizedDescription
        }

        isGeneratingLLMSummary = false
    }

    private var selectedActivities: [ActivityEvent] {
        activities.filter {
            Calendar.current.isDate($0.startedAt, inSameDayAs: selectedDate)
        }
    }

    private var selectedBriefings: [Briefing] {
        briefings.filter {
            Calendar.current.isDate($0.createdAt, inSameDayAs: selectedDate)
        }
    }

    private var selectedSnapshots: [ScreenContextSnapshot] {
        snapshots.filter {
            Calendar.current.isDate($0.capturedAt, inSameDayAs: selectedDate)
        }
    }

    private var selectedTasks: [TaskItem] {
        tasks.filter { task in
            Calendar.current.isDate(task.createdAt, inSameDayAs: selectedDate) ||
            task.dueAt.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } == true ||
            task.plannedStartAt.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } == true
        }
    }

    private var appUsageRows: [(appName: String, minutes: Int, ratio: Double)] {
        let grouped = Dictionary(grouping: selectedActivities, by: \.appName)
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
            .prefix(8)
            .map { row in
                (
                    appName: row.appName,
                    minutes: max(1, Int(row.seconds / 60)),
                    ratio: row.seconds / total
                )
            }
    }

    private var markedDayKeys: Set<String> {
        let activityKeys = activities.map { WokeyMonthCalendar.dayKey(for: $0.startedAt) }
        let taskKeys = tasks.flatMap { task -> [String] in
            [
                WokeyMonthCalendar.dayKey(for: task.createdAt),
                task.dueAt.map { WokeyMonthCalendar.dayKey(for: $0) },
                task.plannedStartAt.map { WokeyMonthCalendar.dayKey(for: $0) }
            ].compactMap { $0 }
        }
        let summaryKeys = summaries.map { WokeyMonthCalendar.dayKey(for: $0.date) }
        let briefingKeys = briefings.map { WokeyMonthCalendar.dayKey(for: $0.createdAt) }

        return Set(activityKeys + taskKeys + summaryKeys + briefingKeys)
    }

    private func scheduleType(_ task: TaskItem) -> ScheduleType {
        ScheduleType(rawValue: task.scheduleType ?? "") ?? .task
    }

    private func scheduleCaption(_ task: TaskItem) -> String {
        let type = scheduleType(task).displayName

        if let plannedStartAt = task.plannedStartAt {
            return "\(type) · \(plannedStartAt.formatted(date: .omitted, time: .shortened))"
        }

        if let dueAt = task.dueAt {
            return "\(type) · \(dueAt.formatted(date: .omitted, time: .shortened))"
        }

        return type
    }

    private func activityTimeRangeText(_ event: ActivityEvent) -> String {
        let start = event.startedAt.formatted(date: .omitted, time: .shortened)

        if let endedAt = event.endedAt {
            return "\(start) - \(endedAt.formatted(date: .omitted, time: .shortened))"
        }

        return "\(start) - 현재"
    }

    private var pieColors: [Color] {
        [
            WokeyDesign.blue,
            WokeyDesign.mint,
            WokeyDesign.muted,
            WokeyDesign.lavender,
            Color.black.opacity(0.22),
            Color.black.opacity(0.14),
            Color.black.opacity(0.10),
            Color.black.opacity(0.06)
        ]
    }

    private func angleStart(for index: Int) -> Angle {
        let ratio = appUsageRows.prefix(index).reduce(0.0) { $0 + $1.ratio }
        return .degrees(ratio * 360 - 90)
    }

    private func angleEnd(for index: Int) -> Angle {
        let ratio = appUsageRows.prefix(index + 1).reduce(0.0) { $0 + $1.ratio }
        return .degrees(ratio * 360 - 90)
    }
}

private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}
