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
                VStack(alignment: .leading, spacing: WokeyDesign.sectionSpacing) {
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
                .padding(WokeyDesign.pagePadding)
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
                    .frame(width: 760, height: 680)
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
                    .frame(width: 760, height: 680)
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
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.16)) {
                        dismiss()
                    }
                }

            content()
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WokeyDesign.hairline, lineWidth: 1)
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
                .foregroundStyle(WokeyDesign.ink)

            Text("Calendar, Text, Apple Notes, KakaoTalk에서 일정과 Task 후보를 가져옵니다.")
                .font(.subheadline)
                .foregroundStyle(WokeyDesign.muted)
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
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(WokeyDesign.selection)
                        .frame(width: 42, height: 42)

                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WokeyDesign.ink)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(WokeyDesign.ink)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(WokeyDesign.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Spacer(minLength: 8)

            Button(primaryButtonTitle) {
                withAnimation(.easeOut(duration: 0.16)) {
                    action()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
    }

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("사용 흐름")
                .font(.headline)
                .foregroundStyle(WokeyDesign.ink)

            Text("1. 가져올 소스를 선택합니다.")
            Text("2. 상세 화면에서 필요한 항목만 선택합니다.")
            Text("3. Claude 분석을 실행하기 전에는 외부 API 요청이 발생하지 않습니다.")
            Text("4. 추출된 후보는 검토 후 Task로 가져옵니다.")
        }
        .font(.caption)
        .foregroundStyle(WokeyDesign.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wokeyPanel()
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
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WokeyDesign.ink)
                        .frame(width: 28, height: 28)
                        .background(WokeyDesign.quietFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("닫기")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(WokeyDesign.quietFill)

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
