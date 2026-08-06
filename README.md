# 🐱 Desktop Pet for macOS

A cute pixel-art cat that lives on your desktop! It walks across your
screens, plays, sleeps, follows your cursor, and reminds you to drink
water every hour.

![Desktop Pet](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 🎨 **Cute pixel-art pet** — bobs, blinks, walks, sleeps, plays, reacts to clicks
- 🖥️ **Multi-monitor walking** — seamlessly crosses between all your displays
- 💧 **Hourly water reminders** — system notification + in-app drink animation
- 😴 **Sleep prevention** — keeps your Mac awake while running (toggleable)
- 🖱️ **Interactive** — click to pet, drag to move, cursor follow
- 📌 **Always on top** — transparent overlay, clicks pass through empty areas
- 🔄 **Auto-start at login** — optional, off by default
- 🎨 **Custom sprites** — drop your own PNG frames to reskin the pet

## Installation

### Download

1. Go to [Releases](../../releases) and download the latest `DesktopPet.dmg`
   (or grab it from [GitHub Actions](../../actions) artifacts)
2. Open the DMG and drag **Desktop Pet** to your Applications folder

### First Launch (Gatekeeper)

Since this app is unsigned (no Apple Developer account), macOS will block
the first launch:

1. **Right-click** (or Control-click) on Desktop Pet in Applications
2. Choose **Open** from the context menu
3. Click **Open** in the dialog

You only need to do this once — subsequent launches work normally.

Alternatively, run in Terminal:
```bash
xattr -dr com.apple.quarantine /Applications/Desktop\ Pet.app
```

## Usage

Once running, the pet appears on your desktop. A **🐱 menu bar icon**
gives you control:

| Menu Item | Description |
|---|---|
| Prevent Sleep | Keeps Mac awake (on by default) |
| Water Reminders | Hourly drink-water notifications |
| Start at Login | Auto-launch at login (off by default) |
| Check for Updates… | Opens the GitHub Releases page |
| Quit Desktop Pet | Exits the app |

### Interacting with the Pet

- **Click** the pet to make it react (happy face!)
- **Drag** the pet to move it anywhere on screen
- **Move your cursor nearby** and the pet follows you
- The pet will **walk**, **play**, and **sleep** on its own

## Custom Artwork

You can replace the built-in pixel art with your own sprites:

1. Create a folder at:
   ```
   ~/Library/Application Support/DesktopPet/Sprites/
   ```
2. Inside, create subfolders for each animation:
   ```
   idle/   walk/   sleep/   drink/   play/   react/   follow/
   ```
3. Add numbered PNG frames (e.g., `0.png`, `1.png`, `2.png`)
4. Restart Desktop Pet

Each frame should be a small sprite (the built-in art is 16×15 pixels,
scaled 4× to 64×60 points on screen).

## Building from Source

Requires **macOS 13+** and **Swift 5.9+**.

```bash
# Build
swift build

# Run tests
swift test

# Build release + assemble .app
swift build -c release
bash scripts/build_app.sh

# Create DMG
bash scripts/make_dmg.sh
```

The built `.app` is at `dist/DesktopPet.app` and the DMG at
`dist/DesktopPet.dmg`.

### CI

Pushes to `main` trigger the
[GitHub Actions workflow](.github/workflows/build.yml) which builds,
tests, and uploads a `DesktopPet.dmg` artifact on a macOS 15 runner.

## Architecture

```
Sources/
├── DesktopPetCore/          # Pure Foundation — cross-platform, testable
│   ├── PixelArt/            # Pixel palette, renderer, procedural pet generator
│   ├── Behavior/            # PetState enum, BehaviorMachine (state machine)
│   └── Navigation/          # ScreenRect, ScreenNavigator (multi-display math)
├── DesktopPet/              # macOS app layer (AppKit + SpriteKit)
│   ├── main.swift           # NSApplication bootstrap
│   ├── AppDelegate.swift    # Lifecycle, notification delegate
│   ├── PetWindow.swift      # Transparent NSPanel with alpha hit-test
│   ├── PetWindowController  # Wires window, scene, behavior, navigation
│   ├── PetScene.swift       # SpriteKit scene: animation, input, overlays
│   ├── PetSprite.swift      # Frame animation playback
│   ├── SpriteSource.swift   # CGImage from pixel art + custom PNG loading
│   ├── Navigation/          # ScreenAdapter (NSScreen ↔ ScreenRect)
│   └── Services/            # Settings, SleepPreventer, AutoStart, Water, Menu
Tests/
└── DesktopPetTests/         # Unit tests for core modules
```

The **DesktopPetCore** library depends only on Foundation and can be
tested on any platform with Swift. The **DesktopPet** executable adds
macOS-specific AppKit, SpriteKit, IOKit, and ServiceManagement.

## How It Works

- **Transparent window**: A borderless `NSPanel` at floating level with
  clear background. `hitTest` samples each frame's alpha — transparent
  pixels let clicks pass through.
- **Pixel art**: String-array sprites are converted to RGBA buffers →
  `CGImage` → `SKTexture` at runtime. No image assets needed.
- **State machine**: `BehaviorMachine` is tick-driven (no timers) with
  injectable clock for deterministic testing. States: idle, walk, sleep,
  drink, play, react, follow.
- **Multi-screen**: `ScreenNavigator` uses global coordinates and screen
  adjacency detection (4pt tolerance) to walk across displays.
- **Sleep prevention**: In-process IOKit assertion — no child processes.
- **No network**: The app makes zero network requests. "Check for
  Updates" simply opens a URL in your browser.

## License

MIT
