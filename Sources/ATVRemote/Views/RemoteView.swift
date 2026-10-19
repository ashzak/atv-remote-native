import SwiftUI

struct RemoteView: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    @Binding var showDeviceMenu: Bool
    @Binding var showKeyboard: Bool

    var body: some View {
        VStack(spacing: 12) {
            if !vm.connected {
                Text("Not connected to the Apple TV. Pick it from the menu above.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.muted)
                    .padding(9)
                    .frame(maxWidth: .infinity)
                    .background(theme.field)
                    .cornerRadius(8)
            }

            header
            HStack(spacing: 40) {
                RoundIconButton(systemImage: "chevron.left") { vm.key("menu") }
                TVButton()
            }
            Touchpad()
                .opacity(vm.connected ? 1 : 0.4)
                .allowsHitTesting(vm.connected)

            HStack(spacing: 40) {
                RoundIconButton(systemImage: "mic", disabled: true) {}
                RoundIconButton(systemImage: vm.nowPlaying.isPlaying ? "pause.fill" : "play.fill") { vm.key("play_pause") }
            }
            .opacity(vm.connected ? 1 : 0.4)
            .allowsHitTesting(vm.connected)

            NowPlayingView()
                .opacity(vm.connected ? 1 : 0.4)
                .allowsHitTesting(vm.connected)

            VolumeRow()
                .opacity(vm.connected ? 1 : 0.4)
                .allowsHitTesting(vm.connected)

            MoreGrid()
                .opacity(vm.connected ? 1 : 0.4)
                .allowsHitTesting(vm.connected)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 6) {
            HeaderIconButton(systemImage: "power") { vm.power() }
            Button(action: { showDeviceMenu = true }) {
                HStack(spacing: 5) {
                    Text(vm.deviceHeaderLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9)).opacity(0.5)
                }
                .foregroundColor(theme.fg)
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            HeaderIconButton(systemImage: "keyboard") { showKeyboard = true; vm.getText() }
        }
        .onAppear { vm.updateDeviceHeader() }
    }
}

private struct TVButton: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    @State private var holdTask: DispatchWorkItem?

    var body: some View {
        Image(systemName: "tv")
            .font(.system(size: 17))
            .frame(width: 56, height: 56)
            .foregroundColor(theme.fg)
            .background(theme.bg)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(theme.line, lineWidth: 1.5))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if holdTask == nil {
                            let task = DispatchWorkItem { vm.key("control_center"); holdTask = nil }
                            holdTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: task)
                        }
                    }
                    .onEnded { _ in
                        if let task = holdTask {
                            task.cancel()
                            holdTask = nil
                            vm.key("home")
                        }
                    }
            )
    }
}

/// Port of the #touchpad pointer handling in remote_window.js.
private struct Touchpad: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    @State private var start: (point: CGPoint, time: Date)?
    @State private var touching = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(theme.field)
                    .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(touching ? theme.fg : theme.line, lineWidth: touching ? 2 : 1.5))

                Image(systemName: "chevron.up").font(.system(size: 12)).foregroundColor(theme.muted).opacity(0.35)
                    .position(x: geo.size.width / 2, y: 14)
                Image(systemName: "chevron.down").font(.system(size: 12)).foregroundColor(theme.muted).opacity(0.35)
                    .position(x: geo.size.width / 2, y: geo.size.height - 14)
                Image(systemName: "chevron.left").font(.system(size: 12)).foregroundColor(theme.muted).opacity(0.35)
                    .position(x: 15, y: geo.size.height / 2)
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(theme.muted).opacity(0.35)
                    .position(x: geo.size.width - 15, y: geo.size.height / 2)
                Text("swipe · tap")
                    .font(.system(size: 11))
                    .tracking(0.9)
                    .textCase(.uppercase)
                    .foregroundColor(theme.muted)
                    .opacity(0.5)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if start == nil { start = (value.startLocation, Date()) }
                        touching = true
                    }
                    .onEnded { value in
                        defer { start = nil; touching = false }
                        guard let start else { return }
                        let dx = value.location.x - start.point.x
                        let dy = value.location.y - start.point.y
                        let w = geo.size.width, h = geo.size.height
                        if hypot(dx, dy) < 12 {
                            let rx = start.point.x / w - 0.5
                            let ry = start.point.y / h - 0.5
                            if max(abs(rx), abs(ry)) > 0.34 {
                                if abs(rx) > abs(ry) { vm.key(rx > 0 ? "right" : "left") }
                                else { vm.key(ry > 0 ? "down" : "up") }
                            } else {
                                vm.key("select")
                            }
                        } else {
                            func norm(_ v: CGFloat, _ s: CGFloat) -> Int { max(0, min(1000, Int((v / s * 1000).rounded()))) }
                            let dur = max(60, min(700, Int(Date().timeIntervalSince(start.time) * 1000)))
                            vm.swipe(
                                sx: norm(start.point.x, w), sy: norm(start.point.y, h),
                                ex: norm(value.location.x, w), ey: norm(value.location.y, h),
                                dur: dur
                            )
                        }
                    }
            )
        }
        .frame(width: 224, height: 176)
    }
}

private struct NowPlayingView: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    @State private var sliderValue: Double = 0

    private var idle: Bool { vm.nowPlaying.totalTime <= 0 }

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(idle ? "Nothing playing" : (vm.nowPlaying.title ?? "Playing"))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text([vm.nowPlaying.artist, vm.nowPlaying.album].compactMap { $0 }.joined(separator: " — "))
                    .font(.system(size: 11))
                    .foregroundColor(theme.muted)
                    .lineLimit(1)
            }
            .frame(minHeight: 32)

            Slider(value: Binding(
                get: { vm.scrubbing ? sliderValue : vm.npPosition },
                set: { newVal in sliderValue = newVal; vm.scrubbing = true }
            ), in: 0...max(1, vm.nowPlaying.totalTime), onEditingChanged: { editing in
                if !editing { vm.setPosition(sliderValue) }
            })
            .disabled(idle)
            .tint(theme.fg)

            HStack {
                Text(fmtTime(vm.scrubbing ? sliderValue : vm.npPosition)).font(.system(size: 10.5, design: .monospaced)).foregroundColor(theme.muted)
                Spacer()
                Text(fmtTime(vm.nowPlaying.totalTime)).font(.system(size: 10.5, design: .monospaced)).foregroundColor(theme.muted)
            }

            HStack(spacing: 10) {
                PillButton(action: { vm.key("skip_backward") }) {
                    HStack(spacing: 5) { Image(systemName: "backward.fill"); Text("10s") }
                }
                PillButton(action: { vm.key("skip_forward") }) {
                    HStack(spacing: 5) { Text("10s"); Image(systemName: "forward.fill") }
                }
            }
        }
        .opacity(idle ? 0.4 : 1)
        .allowsHitTesting(!idle)
    }
}

private struct VolumeRow: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    var body: some View {
        HStack(spacing: 14) {
            PillButton(action: { vm.key("volume_down") }) { Image(systemName: "minus") }
            Text("VOLUME").font(.system(size: 11)).tracking(0.8).foregroundColor(theme.muted)
            PillButton(action: { vm.key("volume_up") }) { Image(systemName: "plus") }
        }
    }
}

private struct MoreGrid: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    @State private var expanded = false

    private let items: [(String, String)] = [
        ("Control Center", "control_center"), ("TV Guide", "guide"),
        ("Channel ▲", "channel_up"), ("Channel ▼", "channel_down"),
        ("Stop", "stop"), ("App Switcher", "top_menu")
    ]

    var body: some View {
        VStack(spacing: 10) {
            Button(action: { expanded.toggle() }) {
                Text("More").font(.system(size: 12)).foregroundColor(theme.muted).underline()
            }
            .buttonStyle(.plain)

            if expanded {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(items, id: \.1) { item in
                        Button(item.0) { vm.key(item.1) }
                            .buttonStyle(MoreButtonStyle(theme: theme))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MoreButtonStyle: ButtonStyle {
    let theme: Theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .padding(.vertical, 9).padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .foregroundColor(configuration.isPressed ? theme.bg : theme.fg)
            .background(configuration.isPressed ? theme.fg : theme.bg)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.line, lineWidth: 1))
    }
}
