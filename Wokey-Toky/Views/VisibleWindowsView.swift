//
//  VisibleWindowsView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import SwiftUI
import SwiftData

struct VisibleWindowsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var captureManager: ContextCaptureManager

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("화면 창 목록")
                    .font(.largeTitle)
                    .bold()

                Spacer()

                Button("새로고침") {
                    captureManager.refreshOnly()
                }

                Button("현재 화면 저장") {
                    captureManager.saveCurrent(modelContext: modelContext)
                }

                Button(captureManager.isCapturing ? "자동 수집 중지" : "자동 수집 시작") {
                    if captureManager.isCapturing {
                        captureManager.stop()
                    } else {
                        captureManager.start(modelContext: modelContext)
                    }
                }
            }
            .padding(.bottom)

            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(captureManager.isCapturing ? .green : .gray)

                Text(captureManager.isCapturing ? "자동 수집 중" : "자동 수집 꺼짐")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            if captureManager.latestWindows.isEmpty {
                ContentUnavailableView(
                    "창 정보를 찾지 못했습니다",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("새로고침을 누르거나 다른 앱 창을 열어보세요.")
                )
            } else {
                List(captureManager.latestWindows) { window in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(window.appName)
                                .font(.headline)

                            Spacer()

                            Text(window.classification.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }

                        if !window.windowTitle.isEmpty {
                            Text(window.windowTitle)
                                .font(.subheadline)
                        } else {
                            Text("제목 없음")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text("x: \(Int(window.x)), y: \(Int(window.y)), w: \(Int(window.width)), h: \(Int(window.height))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("visible: \(Int(window.visibleRatio * 100))%, screen: \(Int(window.screenShare * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .onAppear {
            captureManager.refreshOnly()
        }
    }
}
