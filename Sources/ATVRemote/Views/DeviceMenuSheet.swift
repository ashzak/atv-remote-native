import SwiftUI

struct DeviceMenuSheet: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 12) {
                Text("Apple TV").font(.system(size: 13, weight: .semibold))
                VStack(spacing: 8) {
                    ForEach(vm.allDeviceNames, id: \.self) { name in
                        DeviceRow(name: name, isCurrent: name == vm.currentDeviceName) {
                            vm.switchDevice(name)
                            isPresented = false
                        }
                    }
                }
                ATVButton(title: "Pair another Apple TV", style: .ghost) {
                    isPresented = false
                    vm.startScan()
                }
                ATVButton(title: "Close", style: .ghost) { isPresented = false }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(theme.bg)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.line, lineWidth: 1))
        }
    }
}

struct KeyboardSheet: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme
    @Binding var isPresented: Bool
    @State private var text: String = ""
    @State private var sendTask: DispatchWorkItem?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 12) {
                Text("Type on the Apple TV").font(.system(size: 13, weight: .semibold))
                TextField("Text for the on-screen field", text: $text)
                    .font(.system(size: 20))
                    .padding(10)
                    .background(theme.field)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.line, lineWidth: 2))
                    .textFieldStyle(.plain)
                    .onChange(of: text) { newVal in
                        sendTask?.cancel()
                        let task = DispatchWorkItem { vm.setText(newVal) }
                        sendTask = task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: task)
                    }
                Text("Only works when a text field is focused on the Apple TV.")
                    .font(.system(size: 11)).foregroundColor(theme.muted)
                ATVButton(title: "Done", style: .ghost) { isPresented = false }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(theme.bg)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.line, lineWidth: 1))
        }
        .onAppear {
            vm.onCurrentTextOnce { t in text = t }
        }
    }
}
