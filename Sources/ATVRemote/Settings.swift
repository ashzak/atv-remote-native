import Foundation

/// Replacement for the renderer's localStorage. Same key names/shape as the
/// Electron app so the mental model (and any future migration) stays simple.
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    // ---------------------------------------------------------------- theme
    var uimode: UIMode {
        get { UIMode(rawValue: d.string(forKey: "uimode") ?? "systemmode") ?? .systemmode }
        set { d.set(newValue.rawValue, forKey: "uimode") }
    }

    var alwaysOnTop: Bool {
        get { d.bool(forKey: "alwaysOnTopChecked") }
        set { d.set(newValue, forKey: "alwaysOnTopChecked") }
    }

    // ---------------------------------------------------------------- credentials
    /// name ("Living Room (10.0.0.4)") -> credentials
    var allDevices: [String: DeviceCredentials] {
        get {
            guard let data = d.data(forKey: "remote_credentials"),
                  let decoded = try? JSONDecoder().decode([String: DeviceCredentials].self, from: data) else { return [:] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { d.set(data, forKey: "remote_credentials") }
        }
    }

    func saveDevice(_ name: String, _ creds: DeviceCredentials) {
        var all = allDevices
        all[name] = creds
        allDevices = all
    }

    var currentCreds: DeviceCredentials? {
        get {
            guard let data = d.data(forKey: "atvcreds"),
                  let decoded = try? JSONDecoder().decode(DeviceCredentials.self, from: data) else { return nil }
            return decoded
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                d.set(data, forKey: "atvcreds")
            } else {
                d.removeObject(forKey: "atvcreds")
            }
        }
    }

    var currentDeviceName: String {
        let all = allDevices
        guard let cur = currentCreds else { return all.keys.first ?? "" }
        for (name, creds) in all where creds == cur { return name }
        return all.keys.first ?? ""
    }
}
