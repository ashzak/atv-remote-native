import SwiftUI
import AppKit

struct PairView: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    @FocusState private var focused: Int?

    var body: some View {
        SetupScaffold {
            Text("Step \(vm.pairStep) of 2 · \(vm.pairStep == 1 ? "AirPlay" : "Companion")")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(theme.muted)
            SetupTitle(text: "Enter the pairing code")
            SetupBody(text: "A 4-digit code is showing on your TV.")

            HStack(spacing: 9) {
                ForEach(0..<4, id: \.self) { i in
                    PinBox(text: Binding(
                        get: { vm.pinDigits[i] },
                        set: { newVal in setDigit(i, newVal) }
                    ), filled: !vm.pinDigits[i].isEmpty)
                    .focused($focused, equals: i)
                }
            }
            .onAppear { focused = 0 }
            .onChange(of: vm.pairStep) { _ in focused = 0 }

            if vm.pinError {
                Text("That code didn't work. Check your TV and try again.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.fg)
            }

            HStack(spacing: 10) {
                ATVButton(title: "Cancel", style: .ghost) { vm.cancelPairing() }
                ATVButton(title: "Continue", style: .primary) { vm.submitPinIfComplete() }
                    .disabled(vm.pinDigits.joined().count != 4 || vm.pinSubmitting)
            }
        }
    }

    private func setDigit(_ i: Int, _ newVal: String) {
        let filtered = String(newVal.filter(\.isNumber).prefix(1))
        vm.pinDigits[i] = filtered
        if !filtered.isEmpty, i < 3 { focused = i + 1 }
        if vm.pinDigits.joined().count == 4 { vm.submitPinIfComplete() }
    }
}

private struct PinBox: View {
    @Environment(\.theme) var theme
    @Binding var text: String
    var filled: Bool

    var body: some View {
        TextField("", text: $text)
            .multilineTextAlignment(.center)
            .font(.system(size: 26, design: .monospaced))
            .foregroundColor(theme.fg)
            .frame(width: 46, height: 56)
            .background(theme.field)
            .cornerRadius(11)
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(filled ? theme.fg : theme.line, lineWidth: 2))
            .textFieldStyle(.plain)
    }
}

struct PyErrorView: View {
    var body: some View {
        SetupScaffold {
            SetupTitle(text: "Python isn't installed")
            SetupBody(text: "This app needs Python 3 to reach your Apple TV. Install it — turn on \"Add Python to PATH\" — then reopen this app.")
            ATVButton(title: "Download Python", style: .primary) {
                NSWorkspace.shared.open(URL(string: "https://www.python.org/downloads/")!)
            }
        }
    }
}
