//
//  WindowRecordsView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

struct WindowRecordsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ScreenContextSnapshot.capturedAt, order: .reverse)
    private var snapshots: [ScreenContextSnapshot]

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("저장된 화면 기록")
                    .font(.largeTitle)
                    .bold()

                Spacer()

                Button("전체 삭제") {
                    deleteAllSnapshots()
                }
            }
            .padding(.bottom)

            if snapshots.isEmpty {
                ContentUnavailableView(
                    "저장된 화면 기록이 없습니다",
                    systemImage: "archivebox",
                    description: Text("화면 창 목록에서 현재 화면 저장 또는 자동 수집을 시작해보세요.")
                )
            } else {
                List(snapshots) { snapshot in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(snapshot.capturedAt.formatted(date: .abbreviated, time: .standard))
                                .font(.headline)

                            Spacer()

                            Text("\(snapshot.windows.count)개 창")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let primaryAppName = snapshot.primaryAppName {
                            Text("Primary: \(primaryAppName)")
                                .font(.subheadline)
                                .bold()
                        }

                        if let primaryWindowTitle = snapshot.primaryWindowTitle,
                           !primaryWindowTitle.isEmpty {
                            Text(primaryWindowTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        ForEach(sortedWindows(snapshot.windows)) { window in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(window.appName)
                                        .font(.subheadline)
                                        .bold()

                                    Spacer()

                                    Text(window.classification)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.quaternary)
                                        .clipShape(Capsule())
                                }

                                if !window.windowTitle.isEmpty {
                                    Text(window.windowTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text("screen: \(Int(window.screenShare * 100))%, visible: \(Int(window.visibleRatio * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
    }

    private func sortedWindows(_ windows: [VisibleWindowRecord]) -> [VisibleWindowRecord] {
        windows.sorted { first, second in
            if first.classification == "primary" {
                return true
            }

            if second.classification == "primary" {
                return false
            }

            return first.screenShare > second.screenShare
        }
    }

    private func deleteAllSnapshots() {
        for snapshot in snapshots {
            modelContext.delete(snapshot)
        }
    }
}
