import SwiftUI

struct RootView: View {
    @ObservedObject var vm: RemoteViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeviceMenu = false
    @State private var showKeyboard = false

    private var theme: Theme { Theme.forMode(vm.uimode, systemIsDark: colorScheme == .dark) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            Group {
                switch vm.screen {
                case .loading: LoadingView()
                case .scan: ScanView()
                case .devices: DevicesView()
                case .pair: PairView()
                case .pyerror: PyErrorView()
                case .remote: RemoteView(showDeviceMenu: $showDeviceMenu, showKeyboard: $showKeyboard)
                }
            }

            if showDeviceMenu { DeviceMenuSheet(isPresented: $showDeviceMenu) }
            if showKeyboard { KeyboardSheet(isPresented: $showKeyboard) }
        }
        .environmentObject(vm)
        .environment(\.theme, theme)
        .frame(width: 320, height: 680)
        .alert("Connection failed", isPresented: $vm.connectionFailureAlert) {
            Button("OK") { vm.dismissConnectionFailureAlert() }
        } message: {
            Text("Couldn't connect to the Apple TV. Make sure it's powered on and on the same network as this Mac, then pick it from the menu at the top to try again.")
        }
        .onAppear { vm.boot() }
    }
}
