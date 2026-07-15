<div align="center">

# Port Killer

**A tiny macOS menu bar app to find and kill processes hogging your dev ports.**

Stuck with `EADDRINUSE`? Port `3000` still busy after a crashed dev server?
Port Killer lives in your menu bar and kills the offending process in one click — or with a global keyboard shortcut.

![macOS](https://img.shields.io/badge/macOS-15%2B-000?logo=apple)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

## Features

- **Menu bar first** — no dock icon, no window clutter. Just a menu with your ports.
- **One-click kill** — active ports are listed on top; click to `kill -9` whatever is listening.
- **Kill All Active** — free every monitored port at once.
- **Global shortcut** — kill your dev ports from anywhere (default `⌘⇧A`). Configurable, with three scopes: all monitored ports, built-in dev ports only, or a hand-picked set.
- **Built-in dev ports** — `5173, 5174, 3000, 3001, 8000, 8080` out of the box. Add your own.
- **Live status** — polls in the background so the list is always current.
- **Launch at login** — optional, via macOS Login Items.

## Install

1. Download the latest **`Port Killer.dmg`** from the [**Releases**](../../releases) page.
2. Open the DMG and drag **Port Killer** into **Applications**.
3. Launch it. The icon (a red power symbol) appears in your menu bar.

The app is signed with a Developer ID and **notarized by Apple**, so it opens without Gatekeeper warnings.

### Permissions

- **Accessibility** (optional) — needed only so the global shortcut works while *other* apps are focused. Grant it under **System Settings → Privacy & Security → Accessibility**. Without it, the shortcut still works while Port Killer is active.

## How it works

Port Killer shells out to Apple's own `/usr/sbin/lsof` to find which process IDs are listening on a port, then `/bin/kill -9` to terminate them. No elevated privileges, no kernel extensions — it can only touch processes your user owns.

> **Why not on the Mac App Store?** App Store apps must run in a sandbox that forbids inspecting and killing *other* apps' processes — exactly what this tool does. So it's distributed here instead, notarized and free.

## Build from source

Requires **Xcode 26+** on macOS 15+.

```bash
git clone https://github.com/MehmetAkifff/Port-Killer.git
cd "Port Killer"
open "Port Killer.xcodeproj"   # then ⌘R
```

### Release build & notarization (maintainers)

Automation lives in [`fastlane/`](fastlane/Fastfile). Set your Apple credentials as env vars:

```bash
export APPLE_ID="you@example.com"
export APPLE_TEAM_ID="YUD7KSUK5K"
export AC_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # app-specific password

bundle install
bundle exec fastlane release          # build → sign → DMG → notarize → staple
bundle exec fastlane github tag:v1.0   # the above, then publish a GitHub Release
```

## Contributing

Issues and pull requests welcome. This is a small, focused app — let's keep it that way.

## License

[MIT](LICENSE) © Mehmet Akif Ergani
