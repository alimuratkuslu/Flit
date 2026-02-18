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

Each of the 9 slots maps to an app you choose. If the app is minimized it unminimizes, if it's on a different Space macOS switches to it automatically. If the app isn't running, nothing happens.

---

## Menu bar

When Flit is running you'll see a small swift icon in your menu bar.

```
 ──────────────────
  Flit
 ──────────────────
  Settings...  ⌘,
 ──────────────────
  Quit Flit    ⌘Q
 ──────────────────
```

Click it to open Settings or quit. That's the entire interface — everything else happens in the background.

---

## How to assign apps to shortcuts

1. Click the Flit icon in the menu bar → **Settings…**
2. You'll see 9 rows, one for each shortcut slot

```
┌─────────────────────────────────────────┐
│  Flit                                   │
│  Option+Number → instantly focus an app │
├─────────────────────────────────────────┤
│  ⌥1  │  Safari              ▾           │
│  ⌥2  │  Terminal            ▾           │
│  ⌥3  │  — None —            ▾           │
│  ⌥4  │  Xcode               ▾           │
│  ⌥5  │  — None —            ▾           │
│  ⌥6  │  — None —            ▾           │
│  ⌥7  │  — None —            ▾           │
│  ⌥8  │  — None —            ▾           │
│  ⌥9  │  — None —            ▾           │
├─────────────────────────────────────────┤
│  ⌥+Number shortcuts are active globally │  Done  │
└─────────────────────────────────────────┘
```

3. Click the dropdown next to any slot and pick an app from the list
4. Click **Done** — the shortcut works immediately, no restart needed

Assignments are saved automatically and survive reboots.

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
