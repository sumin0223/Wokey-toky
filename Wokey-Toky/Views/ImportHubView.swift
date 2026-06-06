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
        .sheet(isPresented: $showCalendarImport) {
            CalendarImportView()
                .frame(minWidth: 760, minHeight: 680)
        }
        .sheet(isPresented: $showTextImport) {
            TextImportView()
                .frame(minWidth: 760, minHeight: 680)
        }
        .sheet(isPresented: $showAppleNotesImport) {
            AppleNotesImportView()
                .frame(minWidth: 820, minHeight: 720)
        }
        .sheet(isPresented: $showKakaoTalkImport) {
            KakaoTalkImportView()
                .frame(minWidth: 900, minHeight: 760)
        }
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
