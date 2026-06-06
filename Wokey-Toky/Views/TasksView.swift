//
//  TasksView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var tasks: [TaskItem]

    @State private var selectedType: ScheduleType = .task
    @State private var titleText = ""
    @State private var selectedDate = Date()
    @State private var hasTime = false

    @State private var editingTask: TaskItem?
    @State private var editingTitle = ""
    @State private var editingDetail = ""
    @State private var editingKeywords = ""
    @State private var editingDate = Date()
    @State private var editingHasDate = false
    @State private var editingType: ScheduleType = .task

    @State private var deletingTask: TaskItem?
    @State private var showDeleteConfirmation = false
    @State private var toastMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                headerSection
                addCard
                recentSection
            }
            .padding(WokeyDesign.pagePadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                InAppToastView(message: toastMessage)
            }
        }
        .sheet(item: $editingTask) { task in
            editSheet(task)
        }
        .confirmationDialog(
            "이 일정을 삭제할까요?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let deletingTask {
                    modelContext.delete(deletingTask)
                    showToast("일정을 삭제했습니다.")
                }
                deletingTask = nil
            }

            Button("취소", role: .cancel) {
                deletingTask = nil
            }
        } message: {
            Text("삭제한 일정은 되돌릴 수 없습니다.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(WokeyDesign.ink)

            Text("Task와 Event를 추가합니다. 진행 확인과 회고는 Today, Briefing, Summary에서 이어집니다.")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)
        }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text("새 일정")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text(selectedType == .task ? "Today · Briefing에서 점검" : "Summary에서 일정으로 기록")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(WokeyDesign.statusFill)
                    .clipShape(Capsule())
            }

            Picker("구분", selection: $selectedType) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                Text("제목")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)

                TextField(
                    selectedType == .task ? "예: 생산시스템관리 과제 제출" : "예: 교수님 미팅",
                    text: $titleText
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack(alignment: .top, spacing: 18) {
                DatePicker(
                    "날짜",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("시간 추가", isOn: $hasTime)

                    if hasTime {
                        DatePicker(
                            "시간",
                            selection: $selectedDate,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()

                Button("추가") {
                    addScheduleItem()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("최근 추가한 일정")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(WokeyDesign.ink)

                Spacer()

                Text("Event \(eventCount) · Task \(taskCount)")
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            if recentItems.isEmpty {
                ContentUnavailableView(
                    "등록된 일정이 없습니다",
                    systemImage: "calendar.badge.plus",
                    description: Text("새 Task나 Event를 추가해보세요.")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(recentItems) { task in
                        scheduleRow(task)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
    }

    private func scheduleRow(_ task: TaskItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: scheduleType(task) == .event ? "calendar" : "checkmark.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(scheduleType(task) == .event ? WokeyDesign.blue : WokeyDesign.mint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)
                        .lineLimit(1)

                    Text(scheduleType(task).displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WokeyDesign.statusFill)
                        .clipShape(Capsule())
                }

                Text(dateText(for: task))
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
            }

            Spacer()

            Button("수정") {
                startEditing(task)
            }
            .font(.caption)
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                deletingTask = task
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func editSheet(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("일정 수정")
                .font(.title2)
                .bold()

            Picker("구분", selection: $editingType) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField("제목", text: $editingTitle)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("상세")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $editingDetail)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            TextField("키워드", text: $editingKeywords)
                .textFieldStyle(.roundedBorder)

            Toggle("날짜 있음", isOn: $editingHasDate)

            if editingHasDate {
                DatePicker(
                    "날짜/시간",
                    selection: $editingDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            HStack {
                Button("저장") {
                    saveEditing(task)
                }
                .keyboardShortcut(.defaultAction)

                Button("취소") {
                    editingTask = nil
                }

                Spacer()
            }
        }
        .padding()
        .frame(width: 560, height: 500)
    }

    private var activeItems: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var recentItems: [TaskItem] {
        activeItems
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(10)
            .map { $0 }
    }

    private var eventCount: Int {
        activeItems.filter { scheduleType($0) == .event }.count
    }

    private var taskCount: Int {
        activeItems.filter { scheduleType($0) == .task }.count
    }

    private func addScheduleItem() {
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return
        }

        let task = TaskItem(
            title: trimmedTitle,
            detail: nil,
            source: "manual",
            status: TaskStatus.pending.rawValue,
            scheduleType: selectedType.rawValue,
            requiresPCWork: selectedType == .task,
            dueAt: normalizedSelectedDate(),
            relatedKeywords: nil
        )

        modelContext.insert(task)
        showToast("일정을 추가했습니다.")

        titleText = ""
        selectedDate = Date()
        hasTime = false
        selectedType = .task
    }

    private func normalizedSelectedDate() -> Date {
        if hasTime {
            return selectedDate
        }

        return Calendar.current.startOfDay(for: selectedDate)
    }

    private func startEditing(_ task: TaskItem) {
        editingTask = task
        editingTitle = task.title
        editingDetail = task.detail ?? ""
        editingKeywords = task.relatedKeywords ?? ""
        editingDate = task.dueAt ?? Date()
        editingHasDate = task.dueAt != nil
        editingType = scheduleType(task)
    }

    private func saveEditing(_ task: TaskItem) {
        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = editingDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKeywords = editingKeywords.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return
        }

        task.title = trimmedTitle
        task.detail = trimmedDetail.isEmpty ? nil : trimmedDetail
        task.relatedKeywords = trimmedKeywords.isEmpty ? nil : trimmedKeywords
        task.scheduleType = editingType.rawValue
        task.requiresPCWork = editingType == .task
        task.dueAt = editingHasDate ? editingDate : nil

        editingTask = nil
        showToast("일정을 수정했습니다.")
    }

    private func scheduleType(_ task: TaskItem) -> ScheduleType {
        ScheduleType(rawValue: task.scheduleType ?? "") ?? .task
    }

    private func dateText(for task: TaskItem) -> String {
        guard let dueAt = task.dueAt else {
            return "날짜 미정"
        }

        if scheduleType(task) == .event {
            return "일정 · \(dueAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "마감 · \(dueAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
