<div align="center">

<img src="Flit/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" alt="Flit icon" />

# Flit

**Instantly switch to any running app with a single keystroke.**

`⌥1` `⌥2` `⌥3` `⌥4` `⌥5` `⌥6` `⌥7` `⌥8` `⌥9`

macOS 13+ &nbsp;·&nbsp; Menu bar app &nbsp;·&nbsp; No Dock icon &nbsp;·&nbsp; Zero latency

</div>

---

## What it does

Flit sits quietly in your menu bar and listens for `Option + Number` shortcuts globally. Press `⌥1` and you're instantly in Safari. Press `⌥2` and you're in Terminal. No `Cmd+Tab` cycling, no mouse, no delay — just one keypress per app.

Each of the 9 slots maps to an app you choose. Press the same slot twice to cycle through that app's open windows. Press `⌥Z` to jump back to the previous app instantly.

---

## Features

| Shortcut | Action |
|---|---|
| `⌥1` – `⌥9` | Switch to assigned app |
| `⌥N` again | Cycle through that app's windows |
| `⌥Z` | Focus back — return to previous app |
| `⌥⌥` (double-tap) | Quick-Pick overlay — browse all slots |

**Smart switching**
- Minimized windows are automatically unminimized
- Fullscreen apps switch Spaces automatically
- A HUD badge confirms which slot activated

**Settings**
- Launch at Login — start Flit with macOS
- Show HUD on Switch — floating badge with app icon and slot
- Automatic updates via Sparkle

---

## Menu bar

```
 ──────────────────────
  Flit
 ──────────────────────
  Check for Updates…
 ──────────────────────
  ⌥1 → Safari
  ⌥2 → Terminal
  ⌥4 → Xcode
 ──────────────────────
  Settings…        ⌘,
 ──────────────────────
  Quit Flit        ⌘Q
 ──────────────────────
```

---

## Settings

```
┌──────────────────────────────────────────┐
│  Flit                                    │
│  Option+Number → instantly focus an app  │
├──────────────────────────────────────────┤
│  ⌥1  │  Safari               ▾        ● │
│  ⌥2  │  Terminal             ▾        ● │
│  ⌥3  │  — None —             ▾          │
│  ⌥4  │  Xcode                ▾        ● │
│  ⌥5  │  — None —             ▾          │
│  ⌥6  │  — None —             ▾          │
│  ⌥7  │  — None —             ▾          │
│  ⌥8  │  — None —             ▾          │
│  ⌥9  │  — None —             ▾          │
├──────────────────────────────────────────┤
│  [✓] Launch at Login                     │
│  [✓] Show HUD on Switch                  │
├──────────────────────────────────────────┤
│                                  [ Done ]│
└──────────────────────────────────────────┘
```

● = app is currently running

---

## Quick-Pick Overlay

Double-tap `Option` to open a floating grid of all assigned slots. Click any icon to switch — or press `Escape` to dismiss.

```
┌─────────────────────────────────────┐
│           Quick Switch              │
│  ┌───────┐  ┌───────┐  ┌───────┐   │
│  │  🦊   │  │  >_   │  │       │   │
│  │Safari │  │ Term  │  │ None  │   │
│  │  ⌥1   │  │  ⌥2   │  │  ⌥3   │   │
│  └───────┘  └───────┘  └───────┘   │
│  ┌───────┐  ┌───────┐  ┌───────┐   │
│  │  ⚒   │  │       │  │       │   │
│  │ Xcode │  │ None  │  │ None  │   │
│  │  ⌥4   │  │  ⌥5   │  │  ⌥6   │   │
│  └───────┘  └───────┘  └───────┘   │
└─────────────────────────────────────┘
```

---

## Install

```bash
brew tap alimuratkuslu/flit
brew install --cask flit
```

Or download the latest DMG from [Releases](https://github.com/alimuratkuslu/Flit/releases) and drag Flit to your Applications folder.

---

## First launch

Flit needs Accessibility permission to intercept global keyboard shortcuts. On first launch macOS will show a prompt — click **Open Settings**, toggle Flit on in **System Settings → Privacy & Security → Accessibility**, then relaunch the app.

You only need to do this once.

---

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel

---

## Build from source

```bash
git clone https://github.com/alimuratkuslu/Flit.git
open Flit.xcodeproj
```

Press `Cmd+R` in Xcode. The app appears in your menu bar with no Dock icon.
