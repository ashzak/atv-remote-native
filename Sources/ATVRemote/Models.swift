import Foundation

enum Screen: String {
    case loading, scan, devices, pair, pyerror, remote
}

enum UIMode: String {
    case systemmode, darkmode, lightmode
}

/// Mirrors the JSON blob the python helper hands back after pairing / stores
/// under "atvcreds" and inside "remote_credentials" — kept loose (dictionary)
/// since the server treats it as an opaque bag.
struct DeviceCredentials: Codable, Equatable {
    var identifier: String
    var credentials: String
    var companion: String?

    enum CodingKeys: String, CodingKey {
        case identifier
        case credentials
        case companion = "Companion"
    }
}

struct NowPlayingInfo {
    var title: String?
    var artist: String?
    var album: String?
    var position: Double
    var totalTime: Double
    var state: String
    var error: String?

    var isPlaying: Bool { state.lowercased().contains("playing") }

    static let empty = NowPlayingInfo(title: nil, artist: nil, album: nil, position: 0, totalTime: 0, state: "", error: nil)
}

/// "Living Room (10.0.0.4)" -> ("Living Room", "10.0.0.4")
func shortName(_ name: String) -> (label: String, addr: String) {
    guard let open = name.lastIndex(of: "("), name.hasSuffix(")") else {
        return (name.trimmingCharacters(in: .whitespaces), "")
    }
    let label = String(name[name.startIndex..<open]).trimmingCharacters(in: .whitespaces)
    let addr = String(name[name.index(after: open)..<name.index(before: name.endIndex)])
    return (label.isEmpty ? name : label, addr)
}

func fmtTime(_ seconds: Double) -> String {
    let s = max(0, Int(seconds.rounded()))
    let m = s / 60
    let ss = s % 60
    return String(format: "%d:%02d", m, ss)
}
