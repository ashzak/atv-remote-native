import Foundation

/// Port of the websocket half of app/js/remote_window.js — same wire
/// protocol, same auth-then-flush-pending flow, same reconnect/watchdog
/// timers, talking to the (unmodified) wsserver.py helper.
final class ATVClient: NSObject {
    static let shared = ATVClient()

    private let url = URL(string: "ws://localhost:8765")!
    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private var open = false
    private var authed = false
    private var pending: [String] = []
    private var reconnectTimer: Timer?
    private var watchdogTimer: Timer?

    // Dispatched on the main actor; set by the app's view-model.
    var onAuthed: (() -> Void)?
    var onScanResult: (([String]) -> Void)?
    var onStartPair2: (() -> Void)?
    var onPairCredentials: ((DeviceCredentials) -> Void)?
    var onConnected: (() -> Void)?
    var onConnectionFailure: (() -> Void)?
    var onCurrentText: ((String) -> Void)?
    var onNowPlaying: ((NowPlayingInfo) -> Void)?

    override init() {
        super.init()
        session = URLSession(configuration: .default)
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, !self.open else { return }
            self.connect()
        }
    }

    func connect() {
        reconnectTimer?.invalidate()
        task?.cancel(with: .goingAway, reason: nil)
        open = false
        authed = false

        let t = session.webSocketTask(with: url)
        task = t
        t.resume()
        receiveLoop(t)

        // URLSessionWebSocketTask has no explicit "open" callback; treat the
        // task as open immediately and let the first auth send fail/retry
        // via the reconnect path if the server isn't listening yet.
        open = true
        sendRaw(cmd: "auth", data: .string(ServerRunner.shared.wsToken))
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }

    private func receiveLoop(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                self.open = false
                self.authed = false
                DispatchQueue.main.async { self.scheduleReconnect() }
            case .success(let message):
                if case .string(let text) = message, let data = text.data(using: .utf8) {
                    DispatchQueue.main.async { self.handle(data) }
                }
                self.receiveLoop(t)
            }
        }
    }

    // ---------------------------------------------------------------- send
    enum Payload {
        case string(String)
        case object([String: Any])
        case array([String])
        case none
    }

    private func sendRaw(cmd: String, data: Payload) {
        var obj: [String: Any] = ["cmd": cmd]
        switch data {
        case .string(let s): obj["data"] = s
        case .object(let o): obj["data"] = o
        case .array(let a): obj["data"] = a
        case .none: obj["data"] = ""
        }
        guard let json = try? JSONSerialization.data(withJSONObject: obj),
              let text = String(data: json, encoding: .utf8) else { return }
        if open && (authed || cmd == "auth") {
            task?.send(.string(text)) { _ in }
        } else {
            pending.append(text)
        }
    }

    func send(_ cmd: String, _ data: Payload = .none) { sendRaw(cmd: cmd, data: data) }
    func key(_ k: String) { send("key", .string(k)) }

    private func flushPending() {
        let items = pending
        pending.removeAll()
        for text in items { task?.send(.string(text)) { _ in } }
    }

    // ---------------------------------------------------------------- receive
    private func handle(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = obj["command"] as? String else { return }
        let payload = obj["data"]

        switch command {
        case "authed":
            authed = true
            flushPending()
            onAuthed?()
        case "scanResult":
            onScanResult?(payload as? [String] ?? [])
        case "startPair2":
            onStartPair2?()
        case "pairCredentials":
            if let d = payload as? [String: Any], let creds = decodeCredentials(d) {
                onPairCredentials?(creds)
            }
        case "connected":
            onConnected?()
        case "connection_failure":
            onConnectionFailure?()
        case "current-text":
            onCurrentText?(payload as? String ?? "")
        case "nowplaying":
            onNowPlaying?(decodeNowPlaying(payload as? [String: Any] ?? [:]))
        default:
            break
        }
    }

    private func decodeCredentials(_ d: [String: Any]) -> DeviceCredentials? {
        guard let identifier = d["identifier"] as? String, let credentials = d["credentials"] as? String else { return nil }
        let companion = d["Companion"] as? String
        return DeviceCredentials(identifier: identifier, credentials: credentials, companion: companion)
    }

    private func decodeNowPlaying(_ d: [String: Any]) -> NowPlayingInfo {
        if let err = d["error"] as? String {
            return NowPlayingInfo(title: nil, artist: nil, album: nil, position: 0, totalTime: 0, state: "", error: err)
        }
        return NowPlayingInfo(
            title: d["title"] as? String,
            artist: d["artist"] as? String,
            album: d["album"] as? String,
            position: (d["position"] as? NSNumber)?.doubleValue ?? 0,
            totalTime: (d["total_time"] as? NSNumber)?.doubleValue ?? 0,
            state: d["state"] as? String ?? "",
            error: nil
        )
    }

    /// Credentials -> {"identifier":..., "credentials":..., "Companion":...} for the "connect" command.
    func connectPayload(_ c: DeviceCredentials) -> Payload {
        var obj: [String: Any] = ["identifier": c.identifier, "credentials": c.credentials]
        if let companion = c.companion { obj["Companion"] = companion }
        return .object(obj)
    }
}
