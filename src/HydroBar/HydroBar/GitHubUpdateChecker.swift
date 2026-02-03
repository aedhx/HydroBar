//
//  GitHubUpdateChecker.swift
//  HydroBar
//
//  Checks for new releases via GitHub Releases API and compares with current app version.
//

import Foundation
import AppKit

// MARK: - Configuration

private enum Config {
    static let owner = "aedhx"
    static let repo = "HydroBar"
    static var releasesURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    }
    static var releasesPageURL: URL {
        URL(string: "https://github.com/\(owner)/\(repo)/releases")!
    }
}

// MARK: - API Response

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String
    let name: String?
    let body: String?
    let assets: [Asset]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case name
        case body
        case assets
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadUrl: String?
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }
}

// MARK: - Result

enum UpdateCheckResult: Equatable {
    case upToDate
    case updateAvailable(version: String, url: URL)
    case error(message: String)
}

// MARK: - Version Comparison

private func normalizeVersion(_ tag: String) -> String {
    tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
}

private func versionComponents(_ version: String) -> [Int] {
    normalizeVersion(version)
        .split(separator: ".")
        .compactMap { Int($0) }
}

/// Compare two semantic versions (e.g. "1.0.0" and "1.1.0").
/// Returns true if `latest` is strictly greater than `current`.
private func isVersionNewer(current: String, latest: String) -> Bool {
    let cur = versionComponents(current)
    let lat = versionComponents(latest)
    let maxCount = max(cur.count, lat.count)
    for i in 0..<maxCount {
        let c = i < cur.count ? cur[i] : 0
        let l = i < lat.count ? lat[i] : 0
        if l > c { return true }
        if l < c { return false }
    }
    return false
}

// MARK: - Checker

final class GitHubUpdateChecker: ObservableObject {
    @Published private(set) var result: UpdateCheckResult?
    @Published private(set) var isChecking = false

    var currentAppVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        result = nil

        let currentVersion = currentAppVersion
        let url = Config.releasesURL

        Task { @MainActor in
            defer { isChecking = false }
            do {
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    result = .error(message: "Invalid response")
                    return
                }
                if http.statusCode == 404 {
                    result = .upToDate
                    return
                }
                guard http.statusCode == 200 else {
                    result = .error(message: "Server returned \(http.statusCode)")
                    return
                }

                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = normalizeVersion(release.tagName)
                guard let releaseURL = URL(string: release.htmlUrl) else {
                    result = .error(message: "Invalid release URL")
                    return
                }

                if isVersionNewer(current: currentVersion, latest: latestVersion) {
                    result = .updateAvailable(version: latestVersion, url: releaseURL)
                } else {
                    result = .upToDate
                }
            } catch {
                result = .error(message: error.localizedDescription)
            }
        }
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(Config.releasesPageURL)
    }

    func openUpdateURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func clearResult() {
        result = nil
    }
}
