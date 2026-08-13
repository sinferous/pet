# 🐱 Luna (macOS, Windows & Linux)

A cute pixel-art companion that lives on your desktop! It walks across your screens, plays, sleeps, follows your cursor, and keeps you hydrated with custom reminders.

Published by **sinferous** 🐾

![Platform Support](https://img.shields.io/badge/OS-macOS%20%7C%20Windows%20%7C%20Linux-blue?style=for-the-badge)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge)
![Electron](https://img.shields.io/badge/Electron-32.0-green?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)

---

## 🌟 Core Features

- 🎨 **Cute Pixel-Art Pet** — Bobs, blinks, walks, sleeps, plays, and reacts to clicks.
- 🖥️ **Multi-Monitor Walking** — Seamlessly crosses between all your displays and clamps correctly at edges.
- 💧 **Smart Water Reminders** — Keeps you hydrated on your terms:
  - Custom interval selector (choose every 1, 15, 30, 45, or 60 minutes).
  - Silent meows: Reminders are purely water-focused—no noisy random meows/purrs.
- ⏰ **Custom Reminders for Today** — Set custom time alarms (e.g., "14:30") with a personalized reminder message. The pet will sprint to the center of the display and display your message. These reminders only run for the current day.
- 🏃‍♂️ **Hydration Sprint** — When it is water time, the cat runs directly to the center of your primary screen.
- 💬 **Persistent Alert & Close Button** — The water voice bubble stays in the center of the screen until you click the red "×" button.
- 🚀 **Dismiss Sprint** — Dismissing the water alert triggers the cat to immediately sprint away (either to a random location, or back to the bottom-left corner if it was previously in Park/Idle mode).
- 👁️ **Hide / Seek** — Instantly hide the pet from your screens during meetings or screen sharing. Show it again whenever you click Hide/Seek on the menu bar or tray dropdown.
- 🖱️ **Interactive Drag & Physics** — Pet or drag the cat smoothly around the screen (zero jitter on macOS and Windows).
- 📌 **Click-Through Transparency** — Transparent borderless window. Clicking on empty areas passes straight through to apps underneath, so the pet never gets in your way.
- 😴 **Sleep Prevention (macOS)** — Optionally keeps your computer awake while running.
- 🔄 **Auto-Start at Login** — Launch the app automatically when starting your machine.
- 🎨 **Procedural Pixel Art** — Vector-designed SVG and procedural pixel art generated dynamically. No heavy image files required.

---

## 🖥️ Platform Options

### 1. macOS Version (Native Swift)
A lightweight, natively compiled Swift App utilizing AppKit and SpriteKit.

#### Installation
1. Go to **Releases** and download `Luna.dmg`.
2. Open the DMG and drag **Luna** to your **Applications** folder.
   > [!IMPORTANT]
   > You **must** drag the app to Applications and run it from there. Running it directly from the mounted DMG or a temporary folder causes macOS path randomization (App Translocation), which will break the "Start at Login" feature.
3. **First Launch (Gatekeeper)**: Since it is an unsigned app, macOS may block it or say it is "damaged".
   - **Method A (Easiest)**: Right-click **Luna** in Applications, select **Open**, and click **Open** in the confirmation dialog.
   - **Method B (System Settings)**: If blocked, open **System Settings** > **Privacy & Security**, scroll down to the "Security" section, and click **Open Anyway**.
   - **Method C (Terminal)**: If you see a "damaged and can't be opened" error, open Terminal and run the following command to clear macOS quarantine:
     ```bash
     xattr -dr com.apple.quarantine /Applications/Luna.app
     ```

#### Controls & Menu bar
A 🐱 tray icon in the system menu bar allows you to:
- Toggle **Prevent Sleep** (on/off).
- Toggle **Water Reminders** and set intervals.
- Toggle **Start at Login**.
- Toggle **Hide/Seek** (hides the pet from screens completely).
- Toggle **Idle (Park)** (strolls the pet to the bottom-left corner where it remains frozen until poked).
- **Poke** (unparks/unfreezes the pet).
- **Say** (displays custom meow dialogs).
- Trigger custom animations via the **Movements** submenu.

---

### 2. Desktop Version (Windows & Linux/Ubuntu)
A smooth, custom-designed companion built on Electron and web technology.

#### Installation

**Windows:**
1. Go to **Releases** and download the Windows setup installer (`Luna Setup 1.5.0.exe`).
2. Run the installer to install the application.
   > [!IMPORTANT]
   > You must run the setup installer to install Luna. Do not run the application directly from a temporary folder or zip extraction folder, as Windows clears temporary directories on system restart, which will break the "Start at Login" functionality.
3. Launch `Luna`.

**Linux (Ubuntu):**
1. Download the `.deb` package (`luna_1.5.0_amd64.deb`).
2. Install via apt or your package manager:
   ```bash
   sudo dpkg -i luna_1.5.0_amd64.deb
   ```

#### Controls & Control Panel
Right-click the cat (or the tray icon) to open the context menu:
- **Control Panel**: Opens the beautiful control panel to configure behavior, preview custom intervals, and trigger actions.
- **Start at Login**: Launch at system startup.
- **Hide/Seek**: Toggle pet visibility (completely hides the window).
- **Idle (Park)**: Parks the pet at the bottom-left corner of your display.
- **Poke**: Unfreezes the pet.
- **Close Speech Bubble**: Manually dismiss alerts.
- **Quit**: Exit the application.

---

## 🎨 Custom Sprites & Re-skinning

You can easily replace the built-in art with your own assets:

- **macOS**: Save custom frame files (named `0.png`, `1.png`, etc.) inside:
  `~/Library/Application Support/DesktopPet/Sprites/`
- **Windows**: Place custom sprites within the local resources folder.

Supported directories: `idle/`, `walk/`, `sleep/`, `drink/`, `play/`, `react/`, `follow/`.

---

## 🛠️ Development & Building

### macOS Build Instructions
Requires **macOS 13+** and **Swift 5.9+**.
```bash
# Build & Compile
swift build

# Run Core Tests
swift test

# Assemble Release Bundle (.app)
swift build -c release
bash scripts/build_app.sh

# Create DMG Installer
bash scripts/make_dmg.sh
```

### Desktop Build Instructions (Windows & Linux)
Requires **Node.js** and **npm**.
```bash
# Navigate to desktop
cd desktop

# Install dependencies
npm install

# Start in development mode
npm start

# Package for Windows distribution (exe)
npm run dist

# Package for Linux distribution (AppImage & deb)
npm run dist:linux
```

---

## 🛡️ Privacy & Performance
- **Offline First**: The app makes zero external network requests. Checking for updates simply opens the release page in your browser.
- **Ultra-lightweight**: Extremely low CPU and memory footprint on both platforms.

---

## 📄 License
MIT License. Created by **sinferous**.

---

## 📫 Feedback & Support

If you find any bugs, have feedback, or want to suggest new features, please report them directly to the developer at: **sinferous32@gmail.com**

