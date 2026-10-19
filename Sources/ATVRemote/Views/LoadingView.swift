import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var vm: RemoteViewModel
    @Environment(\.theme) var theme

    var body: some View {
        SetupScaffold {
            RingSpinner()
            SetupTitle(text: "Starting…")
            SetupBody(text: vm.loadingCopy)
            if vm.showLoadingHelp {
                VStack(spacing: 8) {
                    Text("Taking a while?")
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.fg)
                        .underline()
                    Text("The first launch installs Apple TV support with Python and can take a few minutes. If it's still stuck, quit, delete this folder, and reopen:")
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.muted)
                    Text(vm.workingPathText)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(theme.fg)
                        .padding(8)
                        .background(theme.field)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.line, lineWidth: 1))
                        .textSelection(.enabled)
                }
            }
        }
    }
}
