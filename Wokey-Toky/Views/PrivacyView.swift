//
//  PrivacyView.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/8/26.
//

import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection

                localFirstSection

                notCollectedSection

                screenCaptureSection

                userControlSection
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
        }
        .navigationTitle("Privacy")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Privacy")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(WokeyDesign.ink)

            Text("Wokey-Toky는 개인 작업 맥락을 다루기 때문에, 수집 범위와 저장 원칙을 명확히 해야 합니다.")
                .font(.caption)
                .foregroundStyle(WokeyDesign.muted)
        }
    }

    private var localFirstSection: some View {
        privacyCard(
            title: "로컬 우선 저장",
            systemImage: "lock.laptopcomputer",
            bodyText: "현재 기록 데이터는 사용자의 Mac 안에 저장됩니다. 서버 전송 기능은 아직 없으며, 나중에 LLM을 연결할 때도 사용자가 선택한 방식으로만 처리할 예정입니다."
        )
    }

    private var notCollectedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("수집하지 않는 정보")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(WokeyDesign.ink)

            privacyBullet("키 입력 원문은 수집하지 않습니다.")
            privacyBullet("클립보드 내용은 읽지 않습니다.")
            privacyBullet("비밀번호 필드 내용을 직접 수집하지 않습니다.")
            privacyBullet("원본 스크린샷을 장기 저장하지 않는 방향으로 설계합니다.")
        }
        .padding(22)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private var screenCaptureSection: some View {
        privacyCard(
            title: "화면 캡처 원칙",
            systemImage: "rectangle.dashed",
            bodyText: "나중에 ScreenCaptureKit을 붙일 때 화면 이미지는 순간적으로 분석하고, 원본 이미지는 저장하지 않는 구조로 구현합니다. 저장 대상은 앱 이름, 창 제목, 화면 맥락 요약 같은 메타데이터입니다."
        )
    }

    private var userControlSection: some View {
        privacyCard(
            title: "사용자 제어",
            systemImage: "slider.horizontal.3",
            bodyText: "자동 수집은 언제든지 시작하거나 중지할 수 있어야 하며, 사용자는 전체 기록을 삭제할 수 있어야 합니다. 민감한 앱은 기본 제외 목록에 넣는 방향으로 진행합니다."
        )
    }

    private func privacyCard(
        title: String,
        systemImage: String,
        bodyText: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(WokeyDesign.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(WokeyDesign.ink)

                Text(bodyText)
                    .font(.caption)
                    .foregroundStyle(WokeyDesign.muted)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(22)
        .background(WokeyDesign.quietFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WokeyDesign.hairline, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(WokeyDesign.blue)
                .padding(.top, 3)

            Text(text)
                .font(.caption)
                .foregroundStyle(WokeyDesign.ink)

            Spacer()
        }
    }
}
