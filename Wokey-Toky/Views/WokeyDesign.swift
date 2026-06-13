//
//  WokeyDesign.swift
//  Wokey-Toky
//

import SwiftUI

enum WokeyDesign {
    static let blue = Color(red: 0.20, green: 0.22, blue: 0.26)
    static let lavender = Color(red: 0.72, green: 0.72, blue: 0.76)
    static let mint = Color(red: 0.36, green: 0.38, blue: 0.42)
    static let softBlue = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let page = Color(red: 0.94, green: 0.94, blue: 0.95)
    static let panel = Color.white.opacity(0.78)
    static let ink = Color(red: 0.13, green: 0.15, blue: 0.20)
    static let muted = Color(red: 0.48, green: 0.52, blue: 0.61)
    static let hairline = Color.black.opacity(0.07)
    static let selection = Color.black.opacity(0.06)
    static let active = Color(red: 0.22, green: 0.24, blue: 0.28)
    static let quietFill = Color.black.opacity(0.035)
    static let statusFill = Color.black.opacity(0.055)
    static let warningFill = Color.black.opacity(0.075)

    static let panelRadius: CGFloat = 22
    static let pagePadding: CGFloat = 28
    static let sectionSpacing: CGFloat = 24
}

struct WokeyPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(.regularMaterial)
            .background(WokeyDesign.panel)
            .clipShape(RoundedRectangle(cornerRadius: WokeyDesign.panelRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WokeyDesign.panelRadius, style: .continuous)
                    .stroke(WokeyDesign.hairline, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.075), radius: 28, x: 0, y: 16)
    }
}

struct WokeyPageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.98, blue: 0.985),
                        Color(red: 0.93, green: 0.935, blue: 0.945)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
    }
}

extension View {
    func wokeyPanel() -> some View {
        modifier(WokeyPanel())
    }

    func wokeyPageBackground() -> some View {
        modifier(WokeyPageBackground())
    }
}

struct WokeyMonthCalendar: View {
    @Binding var selectedDate: Date
    let markedDays: Set<String>
    var cellSize: CGFloat = 34
    var cellSpacing: CGFloat = 8
    var showsMonthTitle = true

    @State private var visibleMonth: Date = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                if showsMonthTitle {
                    Text(monthTitle)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)
                }

                Spacer()

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(WokeyDesign.muted)

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(WokeyDesign.muted)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(WokeyDesign.muted)
                        .frame(width: cellSize, height: 18)
                }

                ForEach(calendarDays) { day in
                    Button {
                        selectedDate = day.date
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: day.date))")
                                .font(.caption)
                                .fontWeight(day.isSelected ? .bold : .medium)

                            Circle()
                                .fill(markedDays.contains(day.key) ? WokeyDesign.mint : .clear)
                                .frame(width: 4, height: 4)
                        }
                        .foregroundStyle(dayTextColor(day))
                        .frame(width: cellSize, height: cellSize)
                        .background(dayBackground(day))
                        .overlay {
                            if day.isToday && !day.isSelected {
                                Circle()
                                    .stroke(WokeyDesign.mint.opacity(0.55), lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .opacity(day.isInVisibleMonth ? 1 : 0.28)
                }
            }
        }
        .onAppear {
            visibleMonth = monthStart(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            visibleMonth = monthStart(for: newValue)
        }
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    private var calendarDays: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstWeek.start) else {
                return nil
            }

            return CalendarDay(
                date: date,
                isInVisibleMonth: calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                isToday: calendar.isDateInToday(date),
                key: Self.dayKey(for: date)
            )
        }
    }

    private func moveMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: visibleMonth) else {
            return
        }

        visibleMonth = monthStart(for: nextMonth)
        selectedDate = visibleMonth
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func dayTextColor(_ day: CalendarDay) -> Color {
        if day.isSelected {
            return .white
        }

        return day.isInVisibleMonth ? WokeyDesign.ink : WokeyDesign.muted
    }

    @ViewBuilder
    private func dayBackground(_ day: CalendarDay) -> some View {
        if day.isSelected {
            Circle().fill(WokeyDesign.blue.opacity(0.9))
        } else {
            Circle().fill(Color.clear)
        }
    }

    static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

private struct CalendarDay: Identifiable {
    let date: Date
    let isInVisibleMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let key: String

    var id: String {
        key
    }
}
