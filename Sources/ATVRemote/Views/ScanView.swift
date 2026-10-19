import SwiftUI

struct ScanView: View {
    var body: some View {
        SetupScaffold {
            RingSpinner()
            SetupTitle(text: "Looking for your Apple TV")
            SetupBody(text: "Make sure it's powered on and on this network.")
        }
    }
}

struct DevicesView: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme

    var body: some View {
        SetupScaffold {
            SetupTitle(text: "Choose your Apple TV")
            SetupBody(text: "You only need to pair once.")
            if vm.devices.isEmpty {
                Text("No Apple TVs found. Make sure yours is powered on and on this network.")
                    .font(.system(size: 12.5))
                    .foregroundColor(theme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.devices, id: \.self) { name in
                        DeviceRow(name: name) { vm.startPairing(name) }
                    }
                }
            }
            ATVButton(title: "Search again", style: .ghost) { vm.startScan() }
        }
    }
}
