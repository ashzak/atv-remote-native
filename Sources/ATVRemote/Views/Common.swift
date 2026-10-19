import SwiftUI

/// Spinning ring — port of .ring / @keyframes ring-spin.
struct RingSpinner: View {
    @Environment(\.theme) var theme
    @State private var spinning = false

    var body: some View {
        Circle()
            .stroke(theme.line, lineWidth: 3)
            .overlay(
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(theme.fg, lineWidth: 3)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            )
            .frame(width: 34, height: 34)
            .onAppear { spinning = true }
    }
}

/// Port of .setup — centered column of setup-screen content.
struct SetupScaffold<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 14) { content }
            .frame(maxWidth: 272)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
    }
}

struct SetupTitle: View {
    @Environment(\.theme) var theme
    let text: String
    var body: some View {
        Text(text).font(.system(size: 15, weight: .semibold)).foregroundColor(theme.fg)
    }
}

struct SetupBody: View {
    @Environment(\.theme) var theme
    let text: String
    var body: some View {
        Text(text).font(.system(size: 12.5)).foregroundColor(theme.muted).lineSpacing(3)
    }
}

/// Port of .btn / .btn--primary / .btn--ghost.
struct ATVButton: View {
    enum Style { case primary, ghost, outline }
    @Environment(\.theme) var theme
    let title: String
    var style: Style = .outline
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .padding(.horizontal, 20)
                .frame(minHeight: 38)
        }
        .buttonStyle(ATVButtonStyle(style: style, theme: theme))
    }
}

private struct ATVButtonStyle: ButtonStyle {
    let style: ATVButton.Style
    let theme: Theme
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let bg: Color
        let fg: Color
        let border: Color
        switch style {
        case .primary:
            bg = pressed ? theme.accent.opacity(0.82) : theme.accent
            fg = theme.accentFg
            border = theme.accent
        case .outline:
            bg = pressed ? theme.fg : theme.bg
            fg = pressed ? theme.bg : theme.fg
            border = theme.fg
        case .ghost:
            bg = .clear
            fg = theme.muted
            border = .clear
        }
        return configuration.label
            .foregroundColor(fg)
            .background(bg)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: style == .ghost ? 0 : 1.5))
            .scaleEffect(pressed ? 0.97 : 1)
    }
}

/// Round icon button — port of .rw-round.
struct RoundIconButton: View {
    @Environment(\.theme) var theme
    let systemImage: String
    var disabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(RoundButtonStyle(theme: theme, disabled: disabled))
        .disabled(disabled)
    }
}

private struct RoundButtonStyle: ButtonStyle {
    let theme: Theme
    let disabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(disabled ? theme.fg.opacity(0.4) : (configuration.isPressed ? theme.bg : theme.fg))
            .background(configuration.isPressed && !disabled ? theme.fg : theme.bg)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(configuration.isPressed && !disabled ? theme.fg : theme.line, lineWidth: 1.5))
            .opacity(disabled ? 0.4 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

/// Small round header icon — port of .rw-icon.
struct HeaderIconButton: View {
    @Environment(\.theme) var theme
    let systemImage: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(HeaderIconStyle(theme: theme))
    }
}

private struct HeaderIconStyle: ButtonStyle {
    let theme: Theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(theme.fg)
            .background(configuration.isPressed ? theme.field : Color.clear)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
    }
}

/// Pill button — port of .rw-pill.
struct PillButton<Label: View>: View {
    @Environment(\.theme) var theme
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 30)
        }
        .buttonStyle(PillButtonStyle(theme: theme))
    }
}

private struct PillButtonStyle: ButtonStyle {
    let theme: Theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? theme.bg : theme.fg)
            .background(configuration.isPressed ? theme.fg : theme.bg)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(theme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

/// Device row — port of .device-row.
struct DeviceRow: View {
    @Environment(\.theme) var theme
    let name: String
    var isCurrent = false
    var action: () -> Void

    var body: some View {
        let s = shortName(name)
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.label).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                    if !s.addr.isEmpty {
                        Text(s.addr).font(.system(size: 11)).foregroundColor(theme.muted).lineLimit(1)
                    }
                }
                Spacer()
                Text("›").foregroundColor(theme.fg.opacity(0.4))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(DeviceRowStyle(theme: theme, isCurrent: isCurrent))
    }
}

private struct DeviceRowStyle: ButtonStyle {
    let theme: Theme
    let isCurrent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? theme.bg : theme.fg)
            .background(configuration.isPressed ? theme.fg : theme.bg)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isCurrent ? theme.fg : theme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}
