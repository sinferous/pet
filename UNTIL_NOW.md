# UNTIL NOW: Luna Evolution & Change Log

This file documents the milestones, architecture, recent features, and bug fixes across all platforms (**macOS**, **Windows**, and **Android**). It serves as the living changelog and central reference for project history, features, and file organization. All significant changes and updates should be documented here.

---

## 📅 Project History & Milestones

1.  **Desktop Codebase Review:** Reviewed the original cross-platform codebase:
    *   **macOS:** Built in Swift using SpriteKit and AppKit.
    *   **Windows:** Built in Electron using an HTML5 Canvas and Javascript engine.
    *   **Procedural Art:** The vector SVG frames are generated dynamically from [Cat.svg](file:///j:/Work/Webtree%20Online/Desktop%20pet/Pet%20model/Cat.svg) using a Node.js generation script.
2.  **Luna Mobile Proposal Review:** Evaluated the product direction for mobile:
    *   Shifting focus from desktop *hydration* alerts to mobile *usage awareness* (curbing mindless scrolling, late-night phone checks, and repetitive app opening).
    *   Analyzed OS differences: Android allows background services and system alert overlays; iOS requires Live Activities, Widgets, and notifications due to sandboxing.
3.  **Android Core Implementation:** Created a lightweight, native Android application that runs a background **Foreground Service** hosting a transparent floating **WebView** overlay. This layout lets us reuse 100% of the desktop HTML/JS animation engine while integrating native Android app tracking and haptics.

---

## 📂 Android File & Code Architecture

All android resources have been organized under the new [/android](file:///j:/Work/Webtree%20Online/Desktop%20pet/android/) directory:

```
android/
├── settings.gradle            # Project module configuration
├── build.gradle               # Gradle build plugins
├── gradle.properties          # Gradle options & AndroidX configuration
└── app/
    ├── build.gradle           # App namespace & dependency definitions (targets SDK 33)
    └── src/main/
        ├── AndroidManifest.xml # Permission and component declarations
        ├── java/com/webtree/desktoppet/
        │   ├── MainActivity.kt        # Setup dashboard: checks permissions & toggles service
        │   ├── FloatingPetService.kt  # Service managing overlay WebView, dragging, and app-check timer
        │   ├── UsageTracker.kt        # Checks active foreground app via UsageStatsManager
        │   └── BootReceiver.kt        # Re-runs service upon device reboot
        ├── res/
        │   ├── layout/activity_main.xml # Dashboard screen layout
        │   └── values/
        │       ├── strings.xml         # Text resources
        │       ├── colors.xml          # Sleek dark-mode colors
        │       └── themes.xml          # App theme
        └── assets/            # Embedded HTML5 animation assets
            ├── index.html     # Transparent page rendering canvas & speech bubble
            ├── style.css      # Pixel-art speech bubble positioning
            ├── behavior.js    # Core FSM state logic (copied from desktop)
            ├── app.js         # Mobile animation clock & native-to-JS bridge interface
            └── artwork/       # SVGs representing all animation frames (idle, walk, react, sleep, etc.)
```

---

## ⚙️ How the Android System Works

1.  **Permissions Verification:**
    *   **Draw Over Other Apps (`SYSTEM_ALERT_WINDOW`):** Allows Android to place Luna's window on top of home screens and active apps.
    *   **Usage Stats (`PACKAGE_USAGE_STATS`):** Allows checking the foreground package to determine if the user is using distracting social media apps.
2.  **Floating WebView & Transparent Hit-Testing:**
    *   The `FloatingPetService` programmatically creates a transparent `WebView` sized to `128x120` density pixels using `WindowManager`.
    *   It overrides `onTouchEvent` in Kotlin. On press, it draws the touched pixel on a 1x1 bitmap to sample transparency:
        *   If the pixel is transparent (alpha < 10), it returns `false` to let the click pass through to the app underneath.
        *   If the pixel is opaque, it handles native window dragging and passes touch events to the web canvas (allowing user interaction like petting).
3.  **Haptic/Logic Bridge:**
    *   We exposed a `@JavascriptInterface` object called `Android` to the WebView.
    *   As Luna computes steps, she calls `window.Android.setWindowBounds(x, y)` to move the overlay window.
    *   Pet reactions trigger `window.Android.triggerHapticFeedback()`, making the phone vibrate gently.
4.  **Habit & Scrolling Checks:**
    *   Every 2 seconds, `UsageTracker` checks the foreground app package.
    *   When the user opens a social media app (e.g., Instagram), it calls `window.onAppChanged("Instagram")` to trigger a meow message: *"We were just here... Instagram again? 👀"*.
    *   If they stay in the app for more than 20 seconds, it calls `window.onAppTimeWarning` to show a gentle reminder to look up.

---

## 📲 How to Deploy and Verify on a Phone

1.  Download and install **Android Studio**.
2.  Open Android Studio and select the [android](file:///j:/Work/Webtree%20Online/Desktop%20pet/android/) directory.
3.  On your phone, enable **Developer Options** (tap **Build Number** 7 times in Settings -> About Phone) and turn on **USB Debugging**.
4.  Connect your phone to your PC via USB.
5.  In Android Studio, select your phone in the device selector and press the **Run** button (green play icon).
6.  Once open, tap the permission cards in the app dashboard to grant **Draw Over Other Apps** and **Usage Access**, then click **Start Luna 🐱**.

---

## 🚀 Added Features & Optimizations (Recent Updates)

### 🐛 WebView Local CORS & Bridge Crash Fixes
*   **Local File Access:** Enabled `allowFileAccessFromFileURLs` and `allowUniversalAccessFromFileURLs` in WebView settings to fix local asset CORS block issues.
*   **Console Logging Redirect:** Bound JavaScript `console.log()` outputs directly to Android Studio's **Logcat** with the tag `LunaWebViewConsole` via a custom `WebChromeClient`.
*   **Vibrate Permission Crash:** Added `<uses-permission android:name="android.permission.VIBRATE" />` to `AndroidManifest.xml` to prevent haptic vibration calls from causing background service crashes.

### 🤖 FSM Behavior Engine Improvements
*   **Tick Engine Alignment:** Replaced desktop-specific `behavior.update()` calls with `behavior.tick()` to correctly progress states.
*   **Transition Re-Sync:** Re-bound the `behavior.onStateChange` listener in `app.js` to ensure the WebView instantly restarts the frame index and animation clock when changing states, making manual triggers react immediately.
*   **Draw Safeguard:** Added safety checks to verify loaded image objects before executing `ctx.drawImage()`, preventing canvas rendering exceptions.

### 💢 Anger Emotion State (All Platforms)
*   **Procedural Art Design:** Expanded `generate_frames.js` with red slanted eyebrows, a growling mouth overlay, and an anime-style pulsing anger vein mark (`💢`).
*   **Re-generated Vector Frames:** Ran the generator to produce `anger/0.svg` and `anger/1.svg` and copied them into the Android assets directory, aligning Mac/Windows/Android assets.
*   **FSM Registration:** Configured `anger` as a formal FSM state inside `behavior.js` and `app.js` with a 4.0-second timer.

### 🛡️ Left Border Boundary Constraints & Walk-Back
*   **Home Position Locking:** Restricted `pickTarget()` to return `x = 0, y = 160` (bringing the resting point down `160dp` from the top of the screen to completely clear any notch, status bar, or multi-line speech bubbles).
*   **Offset Translation Bridge:** Resized the native WindowManager layout from `128x120` to `200x220` dp (leaving a full `100dp` of vertical head space for speech bubbles). Offset the cat canvas `36px` right and `100px` down. Subtracts this offset in `setWindowBounds()` and adds it back in `onTouchEvent()` ACTION_UP to ensure native coordinates perfectly sync with the Javascript logic.
*   **Removed Run/Jump:** Removed `run` and `jump` actions from FSM intervals and dashboard layouts to fit phone screens better.
*   **Release Walk-Back:** Changed drag-end (`handleDragEnd()`) to transition directly to `walk` so releasing the cat anywhere on screen makes her walk smoothly back to her top-left base instead of teleporting.
*   **Y-Axis Floor Constraints:** Clamped coordinate position updates in `updateWindowBounds()` (Javascript) and `setWindowBounds()` (Kotlin) to a minimum of Y=160. Clamped manual dragging in `onTouchEvent()` (Kotlin) to a minimum of `60*density` (corresponding to Y=160), preventing Luna from ever going above Y=160 on her own or via dragging.

### 🌀 Doomscrolling Interventions & Simulation Controls
*   **Threshold Specific Warnings:**
    *   **20 Mins:** Luna walks to the top-left, parks herself, enters the **Anger** state (`PetState.anger`), vibrates the phone, and shows one of 5 randomized alerts.
    *   **40 Mins:** Parks herself, enters the **Anger** state, vibrates, and shows one of 7 randomized sassy messages.
    *   **60 Mins:** Parks herself, enters the **Anger** state, vibrates, and shows one of 5 randomized reminders.
*   **Auto-Calming Expression:** Once the speech bubble's timeout expires and the warning disappears, Luna automatically transitions from the `anger` state back to `idle` (normal/happy eyes) while remaining parked at her base coordinate.
*   **Development Simulation Panel:** Added 20 Min, 40 Min, and 60 Min simulation buttons on the MainActivity layout. The service first sends a reset signal (`'', 0`) to clear previous alert flags and then delay-fires the target time, making all interventions infinitely replayable for testing.
*   **Clipped Bubble / Side Bleed Fix:** Left-aligned the speech bubble in CSS (`left: 36px`) to keep it flush with the screen border and prevent text clipping on the left edge. Removed close cross mark from the bubble.

### 🎨 Custom Adaptive Launcher Icon
*   **Vector Foreground:** Created `ic_launcher_foreground.xml` utilizing the exact full-body vector paths from the original desktop `Cat.svg` (ears, tail, blue screen collar, open smile, and ribbon bow). Wrapped paths in a group scaled to `80%` to keep her perfectly centered inside the launcher circular crop safe zone.
*   **Vector Background:** Created `ic_launcher_background.xml` with a sleek dark-mode background matching the app's brand theme.
*   **Link in Manifest:** Bound the new icons inside `AndroidManifest.xml` using `android:icon` and `android:roundIcon`.

### 🛡️ System Launcher & Home Filters
*   **Ignored Packages:** Added filter rules inside `onAppChanged()` (Javascript) to ignore active packages containing the keywords `"launcher"`, `"home"`, or `"system"`. This prevents speech bubble alerts from showing when the user exits to the home screen (e.g., Google's *Nexus Launcher* or Samsung's *One UI Home*).

### 🍏 macOS Hit-Testing & Hydration Alert Fixes
*   **Headroom Click & Scroll Pass-Through:** Removed global `NSEvent.pressedMouseButtons != 0` check in `updateIgnoreMouseEvents()`. Mouse hovers, clicks, and scroll wheel events in the 200px transparent headroom above Luna now pass through 100% directly to underlying desktop windows and applications.
*   **Expanded Drag Hitbox & Interactive Area:** Applied padded bounding boxes (`insetBy(dx: -4, dy: -4)`) and alpha threshold `>= 4` in [PetScene.swift](file:///j:/Work/Webtree%20Online/Desktop%20pet/Sources/DesktopPet/PetScene.swift) and [PetWindow.swift](file:///j:/Work/Webtree%20Online/Desktop%20pet/Sources/DesktopPet/PetWindow.swift), making Luna's body responsive to clicks and dragging without requiring pixel-perfect precision.
*   **Hydration Alert Run-Away Fix:** Padded close button hit bounds (`insetBy(dx: -6, dy: -6)`) so clicks on the speech bubble `×` button reliably close the alert. Updated `onCloseSpeechBubble` in [PetWindowController.swift](file:///j:/Work/Webtree%20Online/Desktop%20pet/Sources/DesktopPet/PetWindowController.swift) to clear hydration locks, unpark `BehaviorMachine`, and immediately trigger `.run` to a new random location.

### 📌 "Stay at Bottom" Mode (Windows & macOS)
*   **Persistent Setting:** Added **"Stay at Bottom"** checkbox toggle to both Windows tray menu ([main.js](file:///j:/Work/Webtree%20Online/Desktop%20pet/desktop/main.js)) and macOS menu bar ([StatusItemController.swift](file:///j:/Work/Webtree%20Online/Desktop%20pet/Sources/DesktopPet/Services/StatusItemController.swift)), saving preference in `settings.json` / `UserDefaults`.
*   **Bottom Floor Movement Locking:** When enabled, target coordinate calculation ([ScreenNavigator](file:///j:/Work/Webtree%20Online/Desktop%20pet/Sources/DesktopPetCore/Navigation/ScreenNavigator.swift)) locks Y to the screen floor (`minY` on Mac, `maxY - winHeight` on Windows).
*   **Action & Drag Clamping:** Hydration runs, custom reminders, and manual mouse dragging remain strictly clamped to the bottom edge in front of the taskbar/dock until disabled.

### 🅿️ "Idle / Free" Mode (Windows & macOS)
*   **Menu Item Renaming:** Simplified the control menu options by removing legacy terms like "Poke" and renaming the menu item to **"Idle / Free"**.
*   **Checked = Idle:** When **"Idle / Free"** is checked (ON), Luna sits at the bottom-left corner of the primary display (`screen.frame.minX + 12`, `screen.frame.minY`) and stays there permanently (automatically walking back if manually dragged).
*   **Unchecked = Free:** When **"Idle / Free"** is unchecked (OFF), Luna is set free to roam around normally.



