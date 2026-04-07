# MacBright

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](#compatibility)
[![Swift](https://img.shields.io/badge/swift-5.9%2B-orange.svg)](https://swift.org)
[![Release](https://img.shields.io/github/v/release/langscot/macbright?include_prereleases&sort=semver)](https://github.com/langscot/macbright/releases)

A tiny menu bar app that boosts your MacBook Pro's display brightness past Apple's normal SDR cap, using the same EDR headroom that HDR content gets.

I wanted a free, minimal version of this that I could read every line of source for. So I made my own.

> **Disclaimer:** This project was built with Claude Code (Opus 4.6).

## What it does

On MacBook Pro models with the Liquid Retina XDR display (and other EDR-capable Apple displays), the panel can physically light up *much* brighter than what macOS uses for normal SDR content — that extra range is reserved for HDR video and photos. MacBright unlocks that headroom for everything on screen.

The result on an XDR MacBook is a noticeable, comfortable brightness bump on top of the system slider's max.

## Install

### Download a release

Grab the latest `MacBright.zip` from the [Releases page](https://github.com/langscot/macbright/releases), unzip it, and drag `MacBright.app` into `/Applications`.

On first launch, macOS will block the app with a Gatekeeper warning ("MacBright Not Opened" with only **Done** / **Move to Bin** buttons). On macOS 15 Sequoia and later there's no right-click bypass — you have to allow it from System Settings:

1. Try to open `MacBright.app` once (double-click it). You'll get the blocked dialog. Click **Done**.
2. Open **System Settings** → **Privacy & Security**.
3. Scroll down to the **Security** section. You'll see a line: *"MacBright was blocked to protect your Mac."*
4. Click **Open Anyway** next to it.
5. Authenticate with your password / Touch ID.
6. macOS will show one final confirmation dialog — click **Open Anyway** again.

You only need to do this once. After that, double-clicking works normally.

> **Why the warning?** I don't pay for an [Apple Developer Program membership](https://developer.apple.com/programs/) ($99/yr), which means I can't sign or notarise the binary with an Apple-issued certificate. macOS therefore can't vouch for who built it. If you're not comfortable with that, clone the source, skim through it and build it yourself with the instructions below. I may get a developer license in the future.

### Build from source

```bash
git clone https://github.com/langscot/macbright.git
cd macbright
make app
open .build/MacBright.app
```

Requires macOS 13+ and Xcode command line tools (for `swift build`).

### Launch at login

Drag `MacBright.app` into System Settings → General → Login Items.

### Updates

MacBright has no auto-update mechanism. Watch this repo (or check the [Releases page](https://github.com/langscot/macbright/releases)) if you want to know when a new version ships.

## Usage

MacBright lives in the menu bar — click the sun icon for the menu:

- **Enabled** — on/off toggle.
- **Boost** — slider from no boost (1.0×) to ~2.0× headroom.
- **Only when plugged in** — auto-disables on battery (default on, since boosting uses extra backlight power).
- **Disable for current app** — adds the frontmost app to an exclude list. Useful for HDR games and video players where the extra boost blows out highlights. Boost auto-disables whenever that app is frontmost and re-enables when you switch away.

There's no preferences window. If you want to change a setting that isn't in the menu, edit the source.

## How it works

Two locks have to be picked at the same time:

1. **EDR mode has to be active.** macOS only lets the display run in its bright HDR-rendering mode when something HDR is on screen. MacBright keeps a 1×1 pixel `CAMetalLayer` window in the corner, set to `wantsExtendedDynamicRangeContent = true` and cleared to a high-EDR value. The mere presence of one bright EDR pixel is enough to keep the compositor in HDR mode for that display.

2. **Every pixel needs to be told to use the extra range.** Once EDR is active, the display's gamma table accepts output values above 1.0. MacBright writes a linear ramp from `0.0` to `ceiling` (where `ceiling` is configurable, max 2.0) via [`CGSetDisplayTransferByTable`](https://developer.apple.com/documentation/coregraphics/1455866-cgsetdisplaytransferbytable). Every pixel onscreen now gets multiplied through that ramp, and the >1.0 portion lands in the EDR backlight range.

To disable, MacBright calls `CGDisplayRestoreColorSyncSettings()` and tears down the EDR primer window. That's the entire mechanism.

Each lock alone is useless:

- Just the gamma write (without an active EDR surface) → values >1.0 get clamped, you get washout instead of brightness.
- Just the EDR window (without the gamma write) → only that 1×1 pixel is brighter, the rest of the screen is unchanged.

Both pieces use only public, documented Apple APIs — no private frameworks, no entitlements, no kernel extensions.

## Battery impact

Designed to be cheap:

- The HDR primer renders **one** Metal frame on enable and never again until disabled. No display link, no per-frame work.
- The gamma table is written once on enable and once on disable.
- Power source detection is event-driven via `IOPSNotificationCreateRunLoopSource` — no polling.
- App-frontmost detection uses `NSWorkspaceDidActivateApplicationNotification` — no polling.

The dominant power cost is the backlight itself; the app process should sit at ~0% CPU/GPU when boost is active.

## Architecture

```
Sources/MacBright/
  main.swift            # NSApplication entry point
  AppDelegate.swift     # creates menu bar + controller
  BoostController.swift # state machine: when to boost, when not to
  Brightness.swift      # the gamma table write + restore (GammaBoost)
  HDRPrimer.swift       # 1×1 EDR Metal window
  PowerMonitor.swift    # IOKit AC-power observer
  AppMonitor.swift      # frontmost app observer (for the exclude list)
  Settings.swift        # UserDefaults wrapper
  MenuBar.swift         # NSStatusItem + NSMenu UI
```

About 500 lines of Swift, no third-party dependencies, no private frameworks.

## Compatibility

Designed and tested on a MacBook Pro (M-series, Liquid Retina XDR Display).

It should also work on:
- Pro Display XDR
- Studio Display
- Any other display where `NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0`

On displays without EDR headroom (Air, older Pros, most external monitors), enabling MacBright just produces washout — there's no extra backlight to unlock. MacBright only ever touches built-in displays; external monitors are skipped on principle, since DDC-based external brightness is a totally different code path and would risk surprising users.

## Credits

- [TryAppleEDR](https://github.com/xzhih/TryAppleEDR) — early proof-of-concept for EDR rendering that helped me understand the public API surface.
- Apple's WWDC21 talk [Explore HDR rendering with EDR](https://developer.apple.com/videos/play/wwdc2021/10161/).

## License

MIT — see [LICENSE](LICENSE).
