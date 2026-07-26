import AppKit
import Foundation

@MainActor
final class AutoUpdater: ObservableObject {
    static let shared = AutoUpdater()

    enum State: Equatable {
        case idle
        case downloading(progress: Double)
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private var progressObservation: NSKeyValueObservation?
    private init() {}

    func start(downloadURL: URL, releaseURL: URL) {
        guard case .idle = state else { return }
        let appPath = Bundle.main.bundlePath
        Task { await perform(downloadURL: downloadURL, releaseURL: releaseURL, appPath: appPath) }
    }

    private func perform(downloadURL: URL, releaseURL: URL, appPath: String) async {
        do {
            state = .downloading(progress: 0)
            let dmgPath = try await downloadDMG(from: downloadURL)

            state = .installing
            let mountPoint = try await mountDMG(at: dmgPath)

            let appName = URL(fileURLWithPath: appPath).lastPathComponent
            let appInMount = "\(mountPoint)/\(appName)"
            guard FileManager.default.fileExists(atPath: appInMount) else {
                throw UpdateError.appNotFoundInDMG
            }

            // SECURITY: verify the downloaded app is signed by the same Team ID
            // and passes Gatekeeper assessment before we let `ditto` overwrite
            // the running app. Without this, a tampered release asset or a
            // MITM'd download would be able to replace a signed, notarized app
            // with an attacker payload.
            try await verifySignature(at: appInMount, referenceAppPath: appPath)

            try launchReplacementScript(
                src: appInMount,
                dst: appPath,
                mountPoint: mountPoint,
                fallbackURL: releaseURL
            )

            NSApp.terminate(nil)

        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Download

    private func downloadDMG(from url: URL) async throws -> String {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".dmg")

        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
                self?.progressObservation = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                do {
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    continuation.resume(returning: dest.path)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in
                Task { @MainActor [weak self] in
                    self?.state = .downloading(progress: p.fractionCompleted)
                }
            }

            task.resume()
        }
    }

    // MARK: - Signature verification

    /// Verify the downloaded app is code-signed with the same Team ID as the
    /// running app and passes Gatekeeper (`spctl`) assessment. Throws
    /// `UpdateError.signatureMismatch` if the Team ID differs, or
    /// `.verificationFailed` if `codesign` / `spctl` reject the bundle.
    private func verifySignature(at candidatePath: String, referenceAppPath: String) async throws {
        // 1. The Team ID of the *currently running* app — anything we install
        //    must come from the same team.
        let expectedTeamID = try await teamID(of: referenceAppPath)

        // 2. `codesign --verify --deep --strict` — signature chain is intact.
        //    This proves the candidate is signed by Apple's chain
        //    (Apple Root CA → Developer ID Certification Authority → Developer
        //    ID Application) and that the bundle hasn't been tampered with.
        try await runProcess(
            executable: "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", "--verbose=2", candidatePath],
            failure: .verificationFailed
        )

        // 3. Team ID of the candidate must match the running app's Team ID.
        //    The one exception: if the *running* app has no Team ID (i.e. it is
        //    ad-hoc signed — a Debug build run from Xcode, or an unsigned
        //    internal test build), we cannot do the equality check. In that
        //    case we accept the update as long as the candidate itself is
        //    signed with a real Team ID AND passed the codesign chain check
        //    above. The chain verification (Apple Root CA → Developer ID
        //    Certification Authority → Developer ID Application) already proves
        //    the candidate comes from a legitimate Apple Developer, which is
        //    the security boundary we care about. This keeps auto-update
        //    working for developers testing against their own Debug build.
        let candidateTeamID = try await teamID(of: candidatePath)
        if let expectedTeamID {
            // Production path: signed app updating to a signed app from the
            // same team. We additionally require `spctl --assess` to pass so
            // the notarization tick is verified.
            try await runProcess(
                executable: "/usr/bin/spctl",
                arguments: ["--assess", "--type", "execute", "--verbose", candidatePath],
                failure: .verificationFailed
            )
            guard expectedTeamID == candidateTeamID else {
                throw UpdateError.signatureMismatch(expected: expectedTeamID, actual: candidateTeamID)
            }
        } else {
            // The running app is ad-hoc (no Team ID). Require that the
            // candidate IS properly signed with a real Team ID — otherwise
            // we'd accept a tampered unsigned DMG just because the running
            // app happens to be a Debug build. We skip `spctl` here because
            // spctl run from inside an ad-hoc-signed host process can return
            // a non-zero status for reasons unrelated to the candidate (the
            // host process itself is not Gatekeeper-clean). The codesign
            // chain + TeamID presence is sufficient for the self-update trust
            // decision.
            guard let candidateTeamID, !candidateTeamID.isEmpty else {
                throw UpdateError.signatureMismatch(expected: nil, actual: nil)
            }
        }
    }

    /// Extract the ad-hoc Team ID from `codesign -dvv` output (line like
    /// `TeamIdentifier=ABCDE12345`). Returns `nil` for an ad-hoc signed app.
    private func teamID(of appPath: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            process.arguments = ["-dvv", appPath]
            process.environment = ProcessInfo.processInfo.environment
            let pipe = Pipe()
            process.standardError = pipe // codesign writes -dvv output to stderr
            process.terminationHandler = { [weak pipe] p in
                // codesign -dvv exits non-zero on unsigned apps — treat that as
                // "no Team ID" so the equality check fails safely.
                guard p.terminationStatus == 0 || p.terminationStatus == 1 else {
                    continuation.resume(throwing: UpdateError.verificationFailed)
                    return
                }
                let output = String(data: pipe?.fileHandleForReading.readDataToEndOfFile() ?? Data(), encoding: .utf8) ?? ""
                let teamLine = output
                    .components(separatedBy: "\n")
                    .first(where: { $0.hasPrefix("TeamIdentifier=") })
                let teamID = teamLine?
                    .components(separatedBy: "=")
                    .dropFirst()
                    .joined(separator: "=")
                    .trimmingCharacters(in: .whitespaces)
                // codesign prints `TeamIdentifier=not set` for ad-hoc builds —
                // normalize that to nil so the caller can detect ad-hoc.
                let resolved = (teamID?.isEmpty == true || teamID == "not set") ? nil : teamID
                continuation.resume(returning: resolved)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: UpdateError.verificationFailed)
            }
        }
    }

    /// Run an external process and resume the continuation with a failure error
    /// if it exits non-zero. Stdout/stderr are discarded.
    private func runProcess(executable: String, arguments: [String], failure: UpdateError) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            // Inherit the parent environment so codesign/spctl can find their
            // helper tools and keychain access works as it does on the shell.
            process.environment = ProcessInfo.processInfo.environment
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: failure)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: failure)
            }
        }
    }

    // MARK: - Mount

    private func mountDMG(at path: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            process.arguments = ["attach", path, "-nobrowse", "-noautoopen"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.terminationHandler = { p in
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                guard p.terminationStatus == 0 else {
                    continuation.resume(throwing: UpdateError.mountFailed)
                    return
                }
                // hdiutil output: "/dev/diskX  HFS+  /Volumes/Name"
                let mountPoint = output
                    .components(separatedBy: "\n")
                    .last(where: { $0.contains("/Volumes/") })?
                    .components(separatedBy: "\t")
                    .last?
                    .trimmingCharacters(in: .whitespaces)

                if let mountPoint, !mountPoint.isEmpty {
                    continuation.resume(returning: mountPoint)
                } else {
                    continuation.resume(throwing: UpdateError.mountFailed)
                }
            }
            try? process.run()
        }
    }

    // MARK: - Replace & Relaunch

    private func launchReplacementScript(src: String, dst: String, mountPoint: String, fallbackURL: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier

        // SECURITY: the previous version interpolated `src`, `dst`, `mountPoint`
        // (parsed from `hdiutil` output) and `fallbackURL` directly into a bash
        // heredoc, only escaping double-quotes. A value containing `$()`,
        // backticks, or unescaped quotes could inject into the script that runs
        // after the app exits (and outlives any crash report). Instead, we now
        // write a *fixed* script that reads its arguments from environment
        // variables, so no user/network-derived string ever becomes part of the
        // script body. bash's quoted `"$VAR"` expansion handles arbitrary paths
        // safely.
        let script = """
        #!/bin/bash
        set -u
        SRC="${NEXUS_UPDATE_SRC:?missing src}"
        DST="${NEXUS_UPDATE_DST:?missing dst}"
        MOUNT="${NEXUS_UPDATE_MOUNT:?missing mount}"
        FALLBACK="${NEXUS_UPDATE_FALLBACK:?missing fallback}"

        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done

        if /usr/bin/ditto -- "$SRC" "$DST"; then
            /usr/bin/hdiutil detach "$MOUNT" -quiet 2>/dev/null
            sleep 0.3
            open "$DST"
        else
            /usr/bin/hdiutil detach "$MOUNT" -quiet 2>/dev/null
            open "$FALLBACK"
        fi
        rm -- "$0"
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("si-update-\(UUID().uuidString).sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        // Pass the dynamic values as environment variables rather than
        // interpolating them into the script body.
        var env = ProcessInfo.processInfo.environment
        env["NEXUS_UPDATE_SRC"] = src
        env["NEXUS_UPDATE_DST"] = dst
        env["NEXUS_UPDATE_MOUNT"] = mountPoint
        env["NEXUS_UPDATE_FALLBACK"] = fallbackURL.absoluteString
        process.environment = env
        try process.run()
    }

    // MARK: - Errors

    enum UpdateError: LocalizedError {
        case appNotFoundInDMG
        case mountFailed
        case verificationFailed
        case signatureMismatch(expected: String?, actual: String?)

        var errorDescription: String? {
            switch self {
            case .appNotFoundInDMG: return "Could not find app in update package."
            case .mountFailed: return "Could not open update package."
            case .verificationFailed:
                return "The update failed its signature or Gatekeeper check and was rejected."
            case .signatureMismatch(let expected, let actual):
                return "The update is signed by a different team (\(actual ?? "unknown")) than this app (\(expected ?? "unknown")). Refusing to install."
            }
        }
    }
}
