//
//  ActivityHubView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/26/26.
//

import SwiftUI

struct ActivityHubView: View {
    @State private var showActivityTimeline = false
    @State private var showVisibleWindows = false
    @State private var showWindowRecords = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 260), spacing: 16)
                        ],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        activityCard(
                            title: "오늘의 활동",
                            subtitle: "앱 전환, 창 제목, URL 등 오늘 쌓인 작업 흐름을 확인합니다.",
                            systemImage: "waveform.path.ecg",
                            buttonTitle: "활동 기록 보기"
                        ) {
                            showActivityTimeline = true
                        }

                        activityCard(
                            title: "현재 화면",
                            subtitle: "지금 화면에 떠 있는 앱과 창 구성을 확인합니다.",
                            systemImage: "macwindow",
                            buttonTitle: "현재 화면 보기"
                        ) {
                            showVisibleWindows = true
                        }

                        activityCard(
                            title: "저장된 화면 기록",
                            subtitle: "수집된 화면 맥락 스냅샷과 창 기록을 확인합니다.",
                            systemImage: "rectangle.stack",
                            buttonTitle: "화면 기록 보기"
                        ) {
                            showWindowRecords = true
                        }
                    }

                    guideSection
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Activity")

            if showActivityTimeline {
                activityModal {
                    showActivityTimeline = false
                } content: {
                    ActivityModalContainer(title: "오늘의 활동") {
                        showActivityTimeline = false
                    } content: {
                        ActivityTimelineView()
                    }
                    .frame(width: 860, height: 720)
                }
            }

            if showVisibleWindows {
                activityModal {
                    showVisibleWindows = false
                } content: {
                    ActivityModalContainer(title: "현재 화면") {
                        showVisibleWindows = false
                    } content: {
                        VisibleWindowsView()
                    }
                    .frame(width: 860, height: 720)
                }
            }

            if showWindowRecords {
                activityModal {
                    showWindowRecords = false
                } content: {
                    ActivityModalContainer(title: "저장된 화면 기록") {
                        showWindowRecords = false
                    } content: {
                        WindowRecordsView()
                    }
                    .frame(width: 900, height: 760)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.largeTitle)
                .bold()

            Text("오늘의 활동, 현재 화면, 저장된 화면 기록을 한 곳에서 확인합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func activityCard(
        title: String,
        subtitle: String,
        systemImage: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Spacer(minLength: 8)

            Button(buttonTitle) {
                action()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("사용 흐름")
                .font(.headline)

            Text("1. 자동 수집을 켜면 앱과 화면 흐름이 기록됩니다.")
            Text("2. 현재 화면에서는 지금 보이는 창 구성을 확인합니다.")
            Text("3. 저장된 화면 기록은 이후 브리핑과 Task 판단 근거로 활용됩니다.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func activityModal<Content: View>(
        dismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            content()
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.2), radius: 28, x: 0, y: 14)
                .onTapGesture { }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(10)
    }
}

private struct ActivityModalContainer<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("닫기")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.quaternary.opacity(0.6))

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}//
//  ActivityHubView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 6/6/26.
//

