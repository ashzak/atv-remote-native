# ATV Remote (native)

A native macOS menu-bar app that controls an Apple TV — same UI and
functionality as [bsharper/atv-desktop-remote](https://github.com/bsharper/atv-desktop-remote),
rewritten from Electron/Node/Chromium to SwiftUI + AppKit. No Electron, no
Node, no Chromium.

## How it works

Apple TV control (discovery, AirPlay/Companion pairing, remote commands,
now-playing metadata) is handled by the same Python helper the original app
used, built on [`pyatv`](https://github.com/postlund/pyatv) — there's no
mature Swift equivalent for Apple's AirPlay2/Companion protocols, so
reimplementing that from scratch wasn't worth the risk. Everything else is
native:

- **UI**: SwiftUI, 1:1 port of every screen (loading, scan, pairing, remote,
  keyboard/device-switcher overlays) from the original HTML/CSS/JS.
- **App shell**: `NSStatusItem` menu-bar icon, a borderless `NSWindow` for the
  remote panel, a Carbon global-hotkey registrar, native light/dark/system
  theming.
- **Process management**: Swift `Process` spawns the bundled `wsserver.py`
  into `~/Library/Application Support/ATV Remote`, generates a per-launch
  auth token, and talks to it over `ws://localhost:8765` using
  `URLSessionWebSocketTask` — the exact same JSON wire protocol as before.

## Requirements

- macOS 13+
- Python 3 (the app bootstraps its own venv with `pyatv` + `websockets` on
  first launch — nothing is installed into your system Python)

## Building

No Xcode project required — this is a Swift Package Manager executable,
manually assembled into a `.app` bundle:

```sh
./build_app.sh          # swift build -c release, assemble + ad-hoc codesign
./build_app.sh --run    # same, then launch it
```

The result is `dist/ATV Remote.app`.

## Running from source

```sh
swift build
.build/debug/ATVRemote
```

## License

MIT — see [LICENSE](LICENSE). Portions (`Sources/ATVRemote/Resources/wsserver.py`,
`requirements.txt`, `start_server.sh`) are copied verbatim from the original
[atv-desktop-remote](https://github.com/bsharper/atv-desktop-remote) project
by Brian Harper.
