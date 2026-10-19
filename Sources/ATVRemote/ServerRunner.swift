import Foundation

/// Port of app/server_runner.js — writes the bundled python helper + launch
/// script into the support folder, generates a per-launch auth token, spawns
/// start_server.sh, and watches its stdout for the "server listening on" line.
final class ServerRunner {
    static let shared = ServerRunner()

    private(set) var wsToken: String = {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }()

    private var process: Process?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private(set) var isServerRunning = false
    private var announcePending = false

    var onStarted: (() -> Void)?
    var onStopped: ((Int32) -> Void)?

    static var workingPath: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ATV Remote", isDirectory: true)
    }

    func testPythonExists(completion: @escaping (Result<String, Error>) -> Void) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["python3", "-V"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
        } catch {
            completion(.failure(error))
            return
        }
        DispatchQueue.global().async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            if p.terminationStatus == 0 {
                let txt = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                DispatchQueue.main.async { completion(.success(txt)) }
            } else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "python", code: Int(p.terminationStatus)))) }
            }
        }
    }

    private func bundledResourceText(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: nil)
            ?? Bundle.module.url(forResource: name, withExtension: nil) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func writeSupportFiles() {
        let wpath = ServerRunner.workingPath
        try? FileManager.default.createDirectory(at: wpath, withIntermediateDirectories: true)
        let files = ["wsserver.py", "requirements.txt", "start_server.sh"]
        for fn in files {
            guard let txt = bundledResourceText(fn) else { continue }
            let out = wpath.appendingPathComponent(fn)
            try? txt.write(to: out, atomically: true, encoding: .utf8)
            if fn == "start_server.sh" {
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: out.path)
            }
        }
    }

    private func writeTokenFile() {
        let wpath = ServerRunner.workingPath
        try? FileManager.default.createDirectory(at: wpath, withIntermediateDirectories: true)
        let tokenPath = wpath.appendingPathComponent("wstoken")
        try? wsToken.write(to: tokenPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenPath.path)
    }

    private func stopServerFileSync() {
        let stopPath = ServerRunner.workingPath.appendingPathComponent("stopserver")
        try? "stop".write(to: stopPath, atomically: true, encoding: .utf8)
    }

    private func parseLine(_ line: String) {
        guard !isServerRunning, line.contains("server listening on"), !announcePending else { return }
        announcePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.announcePending = false
            self.isServerRunning = true
            self.onStarted?()
        }
    }

    private func watch(_ handle: FileHandle, isStdout: Bool) {
        var buffer = Data()
        handle.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty else { return }
            buffer.append(data)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[buffer.startIndex..<nl]
                buffer.removeSubrange(buffer.startIndex...nl)
                if let line = String(data: lineData, encoding: .utf8) {
                    if isStdout { print(line) }
                    DispatchQueue.main.async { self?.parseLine(line) }
                }
            }
        }
    }

    func startServer() {
        let noWriteFlag = ServerRunner.workingPath.appendingPathComponent("skip_file_write")
        if !FileManager.default.fileExists(atPath: noWriteFlag.path) { writeSupportFiles() }
        writeTokenFile()
        stopServer()

        let shPath = ServerRunner.workingPath.appendingPathComponent("start_server.sh")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [shPath.path]
        var env = ProcessInfo.processInfo.environment
        env["ATV_WS_TOKEN"] = wsToken
        p.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        p.terminationHandler = { [weak self] proc in
            self?.isServerRunning = false
            self?.onStopped?(proc.terminationStatus)
        }

        do {
            try p.run()
            process = p
            watch(outPipe.fileHandleForReading, isStdout: true)
            watch(errPipe.fileHandleForReading, isStdout: false)
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    func stopServer() {
        isServerRunning = false
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil
        stopServerFileSync()
        if let p = process, p.isRunning {
            p.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if p.isRunning { p.interrupt() }
            }
        }
        process = nil
    }
}
