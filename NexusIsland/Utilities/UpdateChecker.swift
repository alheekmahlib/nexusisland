import Foundation

/// Checks for app updates by fetching a small `manifest.json` hosted on
/// Cloudflare R2 (behind a custom domain). We moved off the GitHub Releases
/// API because GitHub is blocked in some regions where users need updates;
/// R2 has global edge availability and free egress.
///
/// The manifest is a flat JSON file at the bucket root. Shape:
///
/// ```json
/// {
///   "version": "1.2.0",
///   "downloadURL": "https://releases.example.com/NexusIsland-1.2.0.dmg",
///   "releaseNotes": ["...", "..."],
///   "minimumOSVersion": "14.0",
///   "publishedAt": "2026-07-26T12:00:00Z"
/// }
/// ```
///
/// Security does NOT depend on R2 being trusted — `AutoUpdater` verifies the
/// downloaded DMG's codesign + spctl + TeamID before installing, regardless
/// of where the bytes came from. See `SECURITY.md` for the threat model.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    /// EDIT THIS when you change the hosting domain. Must point at the
    /// `manifest.json` file on your R2 custom domain.
    private static let manifestURL = URL(string: "https://releases.vexaltech.dev/manifest.json")!

    private static let lastCheckedKey = "updateChecker.lastCheckedAt"
    private static let dailyInterval: TimeInterval = 86400

    enum CheckState {
        case idle
        case checking
        case upToDate
        case updateAvailable(latestVersion: String, releaseNotes: [String], downloadURL: URL)
        case failed(String)
    }

    @Published var checkState: CheckState = .idle

    private init() {}

    var lastCheckedAt: Date? {
        let ts = UserDefaults.standard.double(forKey: Self.lastCheckedKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    /// Called on app launch — only fires if 24 h have elapsed since the last check.
    func checkIfDue() {
        if let last = lastCheckedAt, Date().timeIntervalSince(last) < Self.dailyInterval {
            return
        }
        Task { await performCheck() }
    }

    /// Manual "Check for Updates" button tap.
    func checkNow() {
        Task { await performCheck() }
    }

    private func performCheck() async {
        if case .checking = checkState { return }
        checkState = .checking

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckedKey)

        do {
            // Bust edge cache so a just-published manifest is visible within
            // the 24h check window. Cloudflare caches R2 responses, so without
            // this a newly uploaded manifest could be invisible for up to the
            // TTL set on the bucket.
            var request = URLRequest(url: Self.manifestURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                // Diagnostic: log the status + body so a 401/403 from R2 or
                // Cloudflare WAF can be diagnosed. Remove once stable.
                let bodySnippet = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                let dbgLine = "[UpdateChecker] HTTP \(http.statusCode) | url=\(Self.manifestURL.absoluteString) | body=\(bodySnippet)\n"
                if let dbgData = dbgLine.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: "/tmp/update-checker.log"),
                       let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/tmp/update-checker.log")) {
                        _ = try? h.seekToEnd(); try? h.write(contentsOf: dbgData); try? h.close()
                    } else {
                        try? dbgData.write(to: URL(fileURLWithPath: "/tmp/update-checker.log"))
                    }
                }
                if !(200...299).contains(http.statusCode) {
                    checkState = .failed("Update server returned \(http.statusCode).")
                    return
                }
            }

            guard let manifest = try? JSONDecoder().decode(UpdateManifest.self, from: data) else {
                checkState = .failed("Could not read update manifest.")
                return
            }

            guard let downloadURL = URL(string: manifest.downloadURL) else {
                checkState = .failed("Update manifest has an invalid download URL.")
                return
            }

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

            if isNewer(manifest.version, than: currentVersion) {
                checkState = .updateAvailable(
                    latestVersion: manifest.version,
                    releaseNotes: manifest.releaseNotes,
                    downloadURL: downloadURL
                )
            } else {
                checkState = .upToDate
            }
        } catch {
            checkState = .failed("Could not reach the update server.")
        }
    }

    private func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").compactMap { Int($0) }
        let b = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }
}

/// On-disk shape of `manifest.json` on the R2 bucket.
private struct UpdateManifest: Decodable {
    let version: String
    let downloadURL: String
    let releaseNotes: [String]
    /// Optional: if present and the running OS is older than this, the update
    /// is offered anyway but the user is warned. Reserved for future use.
    let minimumOSVersion: String?
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case version
        case downloadURL
        case releaseNotes
        case minimumOSVersion
        case publishedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        downloadURL = try c.decode(String.self, forKey: .downloadURL)
        // releaseNotes is optional in the manifest; default to empty.
        releaseNotes = (try? c.decode([String].self, forKey: .releaseNotes)) ?? []
        minimumOSVersion = try? c.decode(String.self, forKey: .minimumOSVersion)
        publishedAt = try? c.decode(String.self, forKey: .publishedAt)
    }
}
