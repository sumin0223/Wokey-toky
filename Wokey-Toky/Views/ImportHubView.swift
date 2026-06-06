//
//  ImportHubView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/26/26.
//

import SwiftUI

struct ImportHubView: View {
    @State private var showCalendarImport = false
    @State private var showTextImport = false
    @State private var showAppleNotesImport = false
    @State private var showKakaoTalkImport = false

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
                        importCard(
                            title: "Calendar",
                            subtitle: "macOS 캘린더 일정과 마감일을 가져옵니다.",
                            systemImage: "calendar",
                            primaryButtonTitle: "Calendar 가져오기"
                        ) {
                            showCalendarImport = true
                        }

                        importCard(
                            title: "Text",
                            subtitle: "복사한 텍스트나 메모 내용을 붙여넣어 Task 후보를 추출합니다.",
                            systemImage: "doc.text",
                            primaryButtonTitle: "Text 가져오기"
                        ) {
                            showTextImport = true
                        }

                        importCard(
                            title: "Apple Notes",
                            subtitle: "Apple Notes에서 선택한 메모를 분석해 Task 후보를 추출합니다.",
                            systemImage: "note.text",
                            primaryButtonTitle: "Notes 가져오기"
                        ) {
                            showAppleNotesImport = true
                        }

                        importCard(
                            title: "KakaoTalk",
                            subtitle: "선택한 카카오톡 채팅방 메시지에서 할 일 후보를 추출합니다.",
                            systemImage: "bubble.left.and.bubble.right",
                            primaryButtonTitle: "KakaoTalk 가져오기"
                        ) {
                            showKakaoTalkImport = true
                        }
                    }

                    guideSection
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Import")

            if showCalendarImport {
                modalBackdrop {
                    showCalendarImport = false
                } content: {
                    ImportSheetContainer(title: "Calendar Import") {
                        showCalendarImport = false
                    } content: {
                        CalendarImportView()
                    }
                    .frame(width: 760, height: 680)
                }
            }

            if showTextImport {
                modalBackdrop {
                    showTextImport = false
                } content: {
                    ImportSheetContainer(title: "Text Import") {
                        showTextImport = false
                    } content: {
                        TextImportView()
                    }
                    .frame(width: 760, height: 680)
                }
            }

            if showAppleNotesImport {
                modalBackdrop {
                    showAppleNotesImport = false
                } content: {
                    ImportSheetContainer(title: "Apple Notes Import") {
                        showAppleNotesImport = false
                    } content: {
                        AppleNotesImportView()
                    }
                    .frame(width: 820, height: 720)
                }
            }

            if showKakaoTalkImport {
                modalBackdrop {
                    showKakaoTalkImport = false
                } content: {
                    ImportSheetContainer(title: "KakaoTalk Import") {
                        showKakaoTalkImport = false
                    } content: {
                        KakaoTalkImportView()
                    }
                    .frame(width: 900, height: 760)
                }
            }
        }
    }

    private func modalBackdrop<Content: View>(
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import")
                .font(.largeTitle)
                .bold()

            Text("Calendar, Text, Apple Notes, KakaoTalk에서 Task 후보를 가져옵니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func importCard(
        title: String,
        subtitle: String,
        systemImage: String,
        primaryButtonTitle: String,
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

            Button(primaryButtonTitle) {
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

            Text("1. 가져올 소스를 선택합니다.")
            Text("2. 상세 화면에서 필요한 항목만 선택합니다.")
            Text("3. LLM 분석 전에는 토큰이 사용되지 않습니다.")
            Text("4. 추출된 후보는 검토 후 Task로 가져옵니다.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

}

private struct ImportSheetContainer<Content: View>: View {
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
}
