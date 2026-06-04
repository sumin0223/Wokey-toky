//
//  ActivityFilterSettings.swift
//  Wokey-Toky
//

import AppKit
import Foundation

struct ActivityFilterApp: Identifiable, Hashable {
    let name: String
    let bundleIdentifier: String?
    let path: String

    var id: String {
        ActivityFilterSettings.key(
            appName: name,
            bundleIdentifier: bundleIdentifier
        )
    }
}

enum ActivityFilterSettings {
    private static let configuredKey = "activityFilter.isConfigured"
    private static let selectedAppKeysKey = "activityFilter.selectedAppKeys"
    private static let siteConfiguredKey = "activityFilter.isSiteConfigured"
    private static let selectedSiteHostsKey = "activityFilter.selectedSiteHosts"

    static var isConfigured: Bool {
        UserDefaults.standard.bool(forKey: configuredKey)
    }

    static var selectedAppKeys: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: selectedAppKeysKey) ?? [])
    }

    static var isSiteConfigured: Bool {
        UserDefaults.standard.bool(forKey: siteConfiguredKey)
    }

    static var selectedSiteHosts: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: selectedSiteHostsKey) ?? [])
    }

    static func saveSelectedAppKeys(_ keys: Set<String>) {
        UserDefaults.standard.set(true, forKey: configuredKey)
        UserDefaults.standard.set(Array(keys).sorted(), forKey: selectedAppKeysKey)
    }

    static func saveSelectedSiteHosts(_ hosts: Set<String>) {
        UserDefaults.standard.set(true, forKey: siteConfiguredKey)
        UserDefaults.standard.set(Array(hosts).sorted(), forKey: selectedSiteHostsKey)
    }

    static func key(
        appName: String,
        bundleIdentifier: String?
    ) -> String {
        if let bundleIdentifier,
           !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }

        return "name:\(appName)"
    }

    static func allows(
        appName: String,
        bundleIdentifier: String?,
        url: String? = nil
    ) -> Bool {
        let isAppAllowed: Bool

        let appKey = key(
            appName: appName,
            bundleIdentifier: bundleIdentifier
        )

        if isConfigured {
            isAppAllowed = selectedAppKeys.contains(appKey)
        } else {
            isAppAllowed = true
        }

        guard isAppAllowed else {
            return false
        }

        guard isSiteConfigured,
              let host = host(from: url) else {
            return true
        }

        guard !selectedSiteHosts.isEmpty else {
            return true
        }

        return selectedSiteHosts.contains(host)
    }

    static func host(from url: String?) -> String? {
        guard let url,
              !url.isEmpty else {
            return nil
        }

        if let host = URL(string: url)?.host {
            return normalizedHost(host)
        }

        if let host = URL(string: "https://\(url)")?.host {
            return normalizedHost(host)
        }

        return nil
    }

    private static func normalizedHost(_ host: String) -> String {
        host
            .lowercased()
            .replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }
}

enum ActivityAppCatalog {
    static func installedApplications() -> [ActivityFilterApp] {
        let fileManager = FileManager.default
        let roots = applicationSearchRoots(fileManager: fileManager)
        var appsByKey: [String: ActivityFilterApp] = [:]

        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else {
                    continue
                }

                let bundle = Bundle(url: url)
                let name = displayName(
                    for: bundle,
                    fallbackURL: url
                )
                let bundleIdentifier = bundle?.bundleIdentifier
                let app = ActivityFilterApp(
                    name: name,
                    bundleIdentifier: bundleIdentifier,
                    path: url.path
                )

                appsByKey[app.id] = app
            }
        }

        let runningApps = NSWorkspace.shared.runningApplications.compactMap { app -> ActivityFilterApp? in
            guard let name = app.localizedName else {
                return nil
            }

            return ActivityFilterApp(
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                path: app.bundleURL?.path ?? ""
            )
        }

        for app in runningApps {
            appsByKey[app.id] = app
        }

        return appsByKey.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func applicationSearchRoots(fileManager: FileManager) -> [URL] {
        var roots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications")
        ]

        roots.append(fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))

        return roots.filter { fileManager.fileExists(atPath: $0.path) }
    }

    private static func displayName(
        for bundle: Bundle?,
        fallbackURL: URL
    ) -> String {
        if let localizedName = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
            return localizedName
        }

        if let displayName = bundle?.infoDictionary?["CFBundleDisplayName"] as? String {
            return displayName
        }

        if let bundleName = bundle?.infoDictionary?["CFBundleName"] as? String {
            return bundleName
        }

        return fallbackURL.deletingPathExtension().lastPathComponent
    }
}
