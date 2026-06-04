//
//  VisibleWindowService.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import Foundation
import CoreGraphics
import AppKit

enum VisibleWindowClassification: String {
    case primary
    case mainVisible
    case peripheral
    case stageManagerCandidate
    case systemWindow
}

struct VisibleWindow: Identifiable {
    let id = UUID()
    let appName: String
    let windowTitle: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let layer: Int
    let visibleRatio: Double
    let screenShare: Double
    let classification: VisibleWindowClassification
}

final class VisibleWindowService {
    func getVisibleWindows() -> [VisibleWindow] {
        guard let screenFrame = NSScreen.main?.frame else {
            return []
        }

        let frontmostAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""

        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        let screenArea = screenFrame.width * screenFrame.height

        let windows: [VisibleWindow] = windowInfoList.compactMap { info in
            guard let appName = info[kCGWindowOwnerName as String] as? String else {
                return nil
            }

            let windowTitle = info[kCGWindowName as String] as? String ?? ""

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? Double,
                  let y = boundsDict["Y"] as? Double,
                  let width = boundsDict["Width"] as? Double,
                  let height = boundsDict["Height"] as? Double else {
                return nil
            }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0

            // 일반 앱 창이 아닌 시스템 레이어 제외
            if layer != 0 {
                return nil
            }

            // 너무 극단적으로 작은 창만 제외
            if width < 40 || height < 40 {
                return nil
            }

            let windowRect = CGRect(
                x: x,
                y: y,
                width: width,
                height: height
            )

            let intersection = windowRect.intersection(screenFrame)

            // 현재 화면과 아예 겹치지 않으면 제외
            if intersection.isNull || intersection.isEmpty {
                return nil
            }

            let windowArea = width * height
            let visibleArea = intersection.width * intersection.height

            let visibleRatio = visibleArea / windowArea
            let screenShare = visibleArea / screenArea

            let classification = classifyWindow(
                appName: appName,
                frontmostAppName: frontmostAppName,
                x: x,
                y: y,
                width: width,
                height: height,
                screenFrame: screenFrame,
                screenShare: screenShare
            )

            return VisibleWindow(
                appName: appName,
                windowTitle: windowTitle,
                x: x,
                y: y,
                width: width,
                height: height,
                layer: layer,
                visibleRatio: visibleRatio,
                screenShare: screenShare,
                classification: classification
            )
        }

        return windows
            .filter { $0.classification != .systemWindow }
            .filter { $0.classification != .stageManagerCandidate }
            .sorted { $0.screenShare > $1.screenShare }
    }

    private func classifyWindow(
        appName: String,
        frontmostAppName: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        screenFrame: CGRect,
        screenShare: Double
    ) -> VisibleWindowClassification {
        // macOS 내부 창은 작업 맥락에서 제외 후보
        if appName == "Window Manager" {
            return .systemWindow
        }

        if appName == "Dock" || appName == "SystemUIServer" {
            return .systemWindow
        }

        // 현재 focus된 앱
        if appName == frontmostAppName {
            return .primary
        }

        let screenMinX = screenFrame.minX
        let screenMaxX = screenFrame.maxX

        let nearLeftEdge = x <= screenMinX + 80
        let nearRightEdge = x + width >= screenMaxX - 80

        let smallThumbnailLikeWindow =
            width <= 360 &&
            height <= 260 &&
            screenShare < 0.08

        // Stage Manager는 화면 가장자리 근처의 작은 미리보기 창처럼 잡히는 경우가 많음
        if smallThumbnailLikeWindow && (nearLeftEdge || nearRightEdge) {
            return .stageManagerCandidate
        }

        // 화면에서 차지하는 비율이 크면 주요 창
        if screenShare >= 0.15 {
            return .mainVisible
        }

        // 나머지는 실제 작은 창일 수 있으므로 peripheral
        return .peripheral
    }
}
