import SwiftUI
import Combine

/// Port of the state-machine half of app/js/remote_window.js (the parts that
/// aren't pure DOM/websocket plumbing — screen routing, pairing flow, device
/// switching, now-playing interpolation).
@MainActor
final class RemoteViewModel: ObservableObject {
    static let shared = RemoteViewModel()

    private let client = ATVClient.shared
    private let settings = Settings.shared

    @Published var screen: Screen = .loading
    @Published var loadingCopy = "Connecting to the helper."
    @Published var showLoadingHelp = false
    @Published var pythonMissing = false

    @Published var devices: [String] = []
    @Published var pairDevice = ""
    @Published var pairStep = 1
    @Published var pinDigits: [String] = ["", "", "", ""]
    @Published var pinError = false
    @Published var pinSubmitting = false

    @Published var connected = false
    @Published var deviceHeaderLabel = "Apple TV"
    @Published var nowPlaying = NowPlayingInfo.empty
    @Published var npPosition: Double = 0
    @Published var scrubbing = false

    @Published var uimode: UIMode
    @Published var alwaysOnTop: Bool

    @Published var windowVisible = true
    @Published var connectionFailureAlert = false

    private var npAt = Date()
    private var pinTimer: Timer?
    private var loadingHelpTimer: Timer?
    private var npPollTimer: Timer?
    private var npRenderTimer: Timer?
    private var _connFailShown = false

    var workingPathText: String { ServerRunner.workingPath.path }

    private init() {
        uimode = settings.uimode
        alwaysOnTop = settings.alwaysOnTop
        wireClient()
        wireServer()
        loadingHelpTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.showLoadingHelp = true }
        }
        npRenderTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.renderNowPlaying() }
        }
        npPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollNowPlaying() }
        }
    }

    // ---------------------------------------------------------------- wiring
    private func wireServer() {
        ServerRunner.shared.onStarted = { [weak self] in
            Task { @MainActor in
                self?.loadingHelpTimer?.invalidate()
                self?.client.connect()
            }
        }
    }

    private func wireClient() {
        client.onAuthed = { [weak self] in self?.afterAuth() }
        client.onScanResult = { [weak self] names in
            self?.devices = names
            self?.screen = .devices
        }
        client.onStartPair2 = { [weak self] in
            self?.pinResultReceived()
            self?.pairStep = 2
            self?.resetPin(focusFirst: true)
        }
        client.onPairCredentials = { [weak self] creds in
            guard let self else { return }
            self.pinResultReceived()
            self.settings.saveDevice(self.pairDevice, creds)
            self.settings.currentCreds = creds
            self.connectToATV()
        }
        client.onConnected = { [weak self] in
            guard let self else { return }
            self.setConnected(true)
            self.screen = .remote
            self.updateDeviceHeader()
            self.pollNowPlaying()
        }
        client.onConnectionFailure = { [weak self] in
            self?.setConnected(false)
            self?.onConnectionFailure()
        }
        client.onNowPlaying = { [weak self] info in self?.onNowPlaying(info) }
        client.onCurrentText = { [weak self] text in self?.currentTextHandler?(text) }
    }

    /// The keyboard sheet wants the ATV's current field text once, when it opens.
    var currentTextHandler: ((String) -> Void)?
    func onCurrentTextOnce(_ handler: @escaping (String) -> Void) {
        currentTextHandler = handler
    }

    // ---------------------------------------------------------------- boot
    func boot() {
        ServerRunner.shared.testPythonExists { [weak self] result in
            if case .failure = result {
                self?.pythonMissing = true
                if self?.screen == .loading { self?.screen = .pyerror }
            }
        }
        ServerRunner.shared.startServer()
    }

    // ---------------------------------------------------------------- auth / connect
    private func afterAuth() {
        if let creds = settings.currentCreds {
            connectToATV(creds: creds)
        } else if let first = settings.allDevices.keys.first {
            settings.currentCreds = settings.allDevices[first]
            connectToATV()
        } else {
            startScan()
        }
    }

    func connectToATV(creds overrideCreds: DeviceCredentials? = nil) {
        guard let creds = overrideCreds ?? settings.currentCreds else { startScan(); return }
        if screen != .remote { screen = .loading }
        loadingCopy = "Connecting to \(shortName(settings.currentDeviceName).label.isEmpty ? "your Apple TV" : shortName(settings.currentDeviceName).label)…"
        client.send("connect", client.connectPayload(creds))
    }

    private func onConnectionFailure() {
        updateDeviceHeader()
        screen = settings.allDevices.isEmpty ? .scan : .remote
        guard !_connFailShown else { return }
        _connFailShown = true
        connectionFailureAlert = true
    }

    func dismissConnectionFailureAlert() { _connFailShown = false; connectionFailureAlert = false }

    private func setConnected(_ v: Bool) { connected = v }

    // ---------------------------------------------------------------- scanning / pairing
    func startScan() {
        screen = .scan
        devices = []
        client.send("scan")
    }

    func startPairing(_ name: String) {
        pairDevice = name
        pairStep = 1
        screen = .pair
        resetPin(focusFirst: true)
        client.send("startPair", .string(name))
    }

    func cancelPairing() { resetPin(focusFirst: false); startScan() }

    func resetPin(focusFirst: Bool) {
        pinTimer?.invalidate()
        pinSubmitting = false
        pinDigits = ["", "", "", ""]
        pinError = false
    }

    private func pinAwait() {
        pinTimer?.invalidate()
        pinTimer = Timer.scheduledTimer(withTimeInterval: 9, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.pinError = true
                self?.resetPin(focusFirst: true)
            }
        }
    }

    private func pinResultReceived() {
        pinTimer?.invalidate()
        pinSubmitting = false
    }

    func submitPinIfComplete() {
        let code = pinDigits.joined()
        guard code.count == 4, !pinSubmitting else { return }
        pinSubmitting = true
        pinError = false
        pinAwait()
        client.send(pairStep == 1 ? "finishPair1" : "finishPair2", .string(code))
    }

    // ---------------------------------------------------------------- device switching
    func updateDeviceHeader() {
        deviceHeaderLabel = shortName(settings.currentDeviceName).label
        if deviceHeaderLabel.isEmpty { deviceHeaderLabel = "Apple TV" }
    }

    var allDeviceNames: [String] { Array(settings.allDevices.keys) }
    var currentDeviceName: String { settings.currentDeviceName }

    func switchDevice(_ name: String) {
        guard let creds = settings.allDevices[name] else { return }
        settings.currentCreds = creds
        updateDeviceHeader()
        connectToATV()
    }

    // ---------------------------------------------------------------- controls
    func key(_ k: String) { client.key(k) }
    func power() { client.send("power", .string("toggle")) }
    func swipe(sx: Int, sy: Int, ex: Int, ey: Int, dur: Int) {
        client.send("swipe", .object(["sx": sx, "sy": sy, "ex": ex, "ey": ey, "dur": dur]))
    }
    func setPosition(_ pos: Double) {
        client.send("set_position", .string(String(Int(pos.rounded()))))
        nowPlaying.position = pos
        npAt = Date()
        scrubbing = false
    }
    func getText() { client.send("gettext") }
    func setText(_ text: String) { client.send("settext", .object(["text": text])) }

    // ---------------------------------------------------------------- now playing
    private func pollNowPlaying() {
        guard connected, screen == .remote, windowVisible else { return }
        client.send("nowplaying")
    }

    private func onNowPlaying(_ info: NowPlayingInfo) {
        if info.error == nil {
            nowPlaying = info
            npAt = Date()
        } else {
            nowPlaying = .empty
        }
    }

    private func renderNowPlaying() {
        guard nowPlaying.totalTime > 0 else { npPosition = 0; return }
        var pos = nowPlaying.position + (nowPlaying.isPlaying ? Date().timeIntervalSince(npAt) : 0)
        pos = max(0, min(nowPlaying.totalTime, pos))
        if !scrubbing { npPosition = pos }
    }

    // ---------------------------------------------------------------- theme / settings
    func setTheme(_ mode: UIMode) {
        uimode = mode
        settings.uimode = mode
    }

    func setAlwaysOnTop(_ v: Bool) {
        alwaysOnTop = v
        settings.alwaysOnTop = v
        NotificationCenter.default.post(name: .atvSetAlwaysOnTop, object: v)
    }

    func setWindowVisible(_ v: Bool) {
        windowVisible = v
        if v { pollNowPlaying() }
    }

    func onPowerResume() {
        if settings.currentCreds != nil { connectToATV() }
    }
}

extension Notification.Name {
    static let atvSetAlwaysOnTop = Notification.Name("atvSetAlwaysOnTop")
    static let atvToggleWindow = Notification.Name("atvToggleWindow")
}
