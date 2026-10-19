import SwiftUI

/// Ported 1:1 from app/css/remote_window.css :root / dark-mode variables.
struct Theme {
    var bg: Color
    var fg: Color
    var muted: Color
    var line: Color
    var field: Color
    var accent: Color
    var accentFg: Color

    static let light = Theme(
        bg: Color(hex: 0xFFFFFF), fg: Color(hex: 0x131313), muted: Color(hex: 0x6B6B6B),
        line: Color(hex: 0xD8D8D8), field: Color(hex: 0xF4F4F4),
        accent: Color(hex: 0x131313), accentFg: Color(hex: 0xFFFFFF)
    )

    static let dark = Theme(
        bg: Color(hex: 0x000000), fg: Color(hex: 0xF2F2F2), muted: Color(hex: 0x9B9B9B),
        line: Color(hex: 0x333333), field: Color(hex: 0x161616),
        accent: Color(hex: 0xF2F2F2), accentFg: Color(hex: 0x000000)
    )

    static func forMode(_ mode: UIMode, systemIsDark: Bool) -> Theme {
        switch mode {
        case .darkmode: return .dark
        case .lightmode: return .light
        case .systemmode: return systemIsDark ? .dark : .light
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
