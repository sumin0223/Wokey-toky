//
//  VisibleWindowRecord.swift
//  Wokey-Toky
//
//  Created by 조수민 on 5/7/26.
//

import Foundation
import SwiftData

@Model
final class VisibleWindowRecord {
    var appName: String
    var windowTitle: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var visibleRatio: Double
    var screenShare: Double
    var classification: String

    var snapshot: ScreenContextSnapshot?

    init(
        appName: String,
        windowTitle: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        visibleRatio: Double,
        screenShare: Double,
        classification: String,
        snapshot: ScreenContextSnapshot? = nil
    ) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.visibleRatio = visibleRatio
        self.screenShare = screenShare
        self.classification = classification
        self.snapshot = snapshot
    }
}
