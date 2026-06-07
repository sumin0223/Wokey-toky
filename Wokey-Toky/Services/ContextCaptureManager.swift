//
//  ContextCaptureManager.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//


import Foundation
import SwiftData
import Combine

enum UserWorkState: String, CaseIterable, Identifiable {
    case working
    case resting
    case away

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .working:
            return "작업 중"
        case .resting:
            return "쉬는 중"
        case .away:
            return "자리 비움"
        }
    }
}

@Model
final class UserWorkStateSession {
    var state: String
    var startedAt: Date
    var endedAt: Date?
    var createdAt: Date

    init(
        state: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.state = state
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.createdAt = createdAt
    }
}

@MainActor
final class ContextCaptureManager: ObservableObject {
    private static let userWorkStateDefaultsKey = "ContextCaptureManager.userWorkState"
    @Published var isCapturing: Bool = false
    @Published private(set) var userWorkState: UserWorkState = .working
    @Published var latestWindows: [VisibleWindow] = []

    private let visibleWindowService = VisibleWindowService()
    private let activityCaptureService = ActivityCaptureService()

    private var timer: AnyCancellable?
    private var lastWindowSignature: String = ""
    private var lastActivitySignature: String = ""
    private var shouldResumeCaptureAfterUserPause = false

    init() {
        restoreUserWorkState()
    }

    func start(modelContext: ModelContext) {
        setUserWorkStateValue(.working)
        shouldResumeCaptureAfterUserPause = false

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

    func setUserWorkState(
        _ state: UserWorkState,
        modelContext: ModelContext
    ) {
        guard userWorkState != state else {
            return
        }

        recordUserWorkStateTransition(
            to: state,
            modelContext: modelContext
        )

        switch state {
        case .working:
            setUserWorkStateValue(.working)

            if shouldResumeCaptureAfterUserPause {
                shouldResumeCaptureAfterUserPause = false
                start(modelContext: modelContext)
            }

        case .resting, .away:
            setUserWorkStateValue(state)

            if isCapturing {
                shouldResumeCaptureAfterUserPause = true
                stop(modelContext: modelContext)
            }
        }
    }

    private func recordUserWorkStateTransition(
        to state: UserWorkState,
        modelContext: ModelContext
    ) {
        let now = Date()

        closeLatestUserWorkStateSession(
            modelContext: modelContext,
            endedAt: now
        )

        let session = UserWorkStateSession(
            state: state.rawValue,
            startedAt: now
        )

        modelContext.insert(session)
    }

    private func closeLatestUserWorkStateSession(
        modelContext: ModelContext,
        endedAt: Date
    ) {
        var descriptor = FetchDescriptor<UserWorkStateSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            let latestSessions = try modelContext.fetch(descriptor)

            if let latestSession = latestSessions.first,
               latestSession.endedAt == nil {
                latestSession.endedAt = endedAt
            }
        } catch {
            print("Failed to close latest UserWorkStateSession: \(error)")
        }
    }

    private func restoreUserWorkState() {
        let rawValue = UserDefaults.standard.string(
            forKey: Self.userWorkStateDefaultsKey
        )

        guard let rawValue,
              let savedState = UserWorkState(rawValue: rawValue) else {
            userWorkState = .working
            return
        }

        userWorkState = savedState
        shouldResumeCaptureAfterUserPause = false
    }

    private func setUserWorkStateValue(_ state: UserWorkState) {
        userWorkState = state
        UserDefaults.standard.set(
            state.rawValue,
            forKey: Self.userWorkStateDefaultsKey
        )
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
