//
//  ContextCaptureManager.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ContextCaptureManager: ObservableObject {
    @Published var isCapturing: Bool = false
    @Published var latestWindows: [VisibleWindow] = []

    private let visibleWindowService = VisibleWindowService()
    private let activityCaptureService = ActivityCaptureService()

    private var timer: AnyCancellable?
    private var lastWindowSignature: String = ""
    private var lastActivitySignature: String = ""

    func start(modelContext: ModelContext) {
        if isCapturing {
            return
        }

        isCapturing = true

        captureIfChanged(modelContext: modelContext)

        timer = Timer.publish(
            every: 5,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            Task { @MainActor in
                self?.captureIfChanged(modelContext: modelContext)
            }
        }
    }

    func stop(modelContext: ModelContext? = nil) {
        if let modelContext {
            closeLatestActivity(modelContext: modelContext, endedAt: Date())
        }

        isCapturing = false
        timer?.cancel()
        timer = nil
        lastActivitySignature = ""
        lastWindowSignature = ""
    }

    func refreshOnly() {
        latestWindows = visibleWindowService.getVisibleWindows()
    }

    func saveCurrent(modelContext: ModelContext) {
        captureActivityManually(modelContext: modelContext)

        let currentWindows = visibleWindowService.getVisibleWindows()
        latestWindows = currentWindows
        lastWindowSignature = makeWindowSignature(from: currentWindows)
        saveWindows(currentWindows, modelContext: modelContext)
    }
    
    private func captureActivityManually(modelContext: ModelContext) {
        guard let captured = activityCaptureService.captureFrontmostApp() else {
            return
        }

        guard ActivityFilterSettings.allows(
            appName: captured.appName,
            bundleIdentifier: captured.bundleIdentifier,
            url: captured.url
        ) else {
            closeLatestActivity(modelContext: modelContext, endedAt: Date())
            lastActivitySignature = ""
            return
        }

        let now = Date()

        closeLatestActivity(modelContext: modelContext, endedAt: now)

        let event = ActivityEvent(
            appName: captured.appName,
            bundleIdentifier: captured.bundleIdentifier,
            windowTitle: captured.windowTitle,
            url: captured.url,
            startedAt: now,
            endedAt: nil
        )

        lastActivitySignature = "\(captured.appName)|\(captured.bundleIdentifier ?? "")|\(captured.windowTitle ?? "")|\(captured.url ?? "")"

        modelContext.insert(event)
    }

    private func captureIfChanged(modelContext: ModelContext) {
        captureActivityIfChanged(modelContext: modelContext)
        captureWindowsIfChanged(modelContext: modelContext)
    }
    
    private func captureActivityIfChanged(modelContext: ModelContext) {
        guard let captured = activityCaptureService.captureFrontmostApp() else {
            return
        }

        let now = Date()

        guard ActivityFilterSettings.allows(
            appName: captured.appName,
            bundleIdentifier: captured.bundleIdentifier,
            url: captured.url
        ) else {
            closeLatestActivity(modelContext: modelContext, endedAt: now)
            lastActivitySignature = ""
            return
        }

        let currentSignature = "\(captured.appName)|\(captured.bundleIdentifier ?? "")|\(captured.windowTitle ?? "")|\(captured.url ?? "")"

        if currentSignature == lastActivitySignature {
            updateLatestActivityEndTime(modelContext: modelContext, endedAt: now)
            return
        }

        closeLatestActivity(modelContext: modelContext, endedAt: now)

        lastActivitySignature = currentSignature

        let event = ActivityEvent(
            appName: captured.appName,
            bundleIdentifier: captured.bundleIdentifier,
            windowTitle: captured.windowTitle,
            url: captured.url,
            startedAt: now,
            endedAt: nil
        )

        modelContext.insert(event)
    }
    
    private func updateLatestActivityEndTime(
        modelContext: ModelContext,
        endedAt: Date
    ) {
        var descriptor = FetchDescriptor<ActivityEvent>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            let latestEvents = try modelContext.fetch(descriptor)

            if let latestEvent = latestEvents.first {
                latestEvent.endedAt = endedAt
            }
        } catch {
            print("Failed to update latest ActivityEvent endedAt: \(error)")
        }
    }

    private func closeLatestActivity(
        modelContext: ModelContext,
        endedAt: Date
    ) {
        var descriptor = FetchDescriptor<ActivityEvent>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            let latestEvents = try modelContext.fetch(descriptor)

            if let latestEvent = latestEvents.first {
                latestEvent.endedAt = endedAt
            }
        } catch {
            print("Failed to close latest ActivityEvent: \(error)")
        }
    }

    private func captureWindowsIfChanged(modelContext: ModelContext) {
        let currentWindows = visibleWindowService.getVisibleWindows()
        let currentSignature = makeWindowSignature(from: currentWindows)

        latestWindows = currentWindows

        if currentSignature == lastWindowSignature {
            return
        }

        lastWindowSignature = currentSignature
        saveWindows(currentWindows, modelContext: modelContext)
    }

    private func saveWindows(
        _ currentWindows: [VisibleWindow],
        modelContext: ModelContext
    ) {
        guard !currentWindows.isEmpty else {
            return
        }

        let primaryWindow = currentWindows.first {
            $0.classification == .primary
        }

        let snapshot = ScreenContextSnapshot(
            capturedAt: Date(),
            primaryAppName: primaryWindow?.appName,
            primaryWindowTitle: primaryWindow?.windowTitle
        )

        let records = currentWindows.map { window in
            VisibleWindowRecord(
                appName: window.appName,
                windowTitle: window.windowTitle,
                x: window.x,
                y: window.y,
                width: window.width,
                height: window.height,
                visibleRatio: window.visibleRatio,
                screenShare: window.screenShare,
                classification: window.classification.rawValue,
                snapshot: snapshot
            )
        }

        snapshot.windows = records

        modelContext.insert(snapshot)
    }

    private func makeWindowSignature(from windows: [VisibleWindow]) -> String {
        windows
            .map { window in
                let roundedX = Int(window.x / 20) * 20
                let roundedY = Int(window.y / 20) * 20
                let roundedWidth = Int(window.width / 20) * 20
                let roundedHeight = Int(window.height / 20) * 20

                return "\(window.appName)|\(window.windowTitle)|\(window.classification.rawValue)|\(roundedX),\(roundedY),\(roundedWidth),\(roundedHeight)"
            }
            .sorted()
            .joined(separator: "\n")
    }
}
