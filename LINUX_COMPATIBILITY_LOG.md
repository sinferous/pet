# Linux Compatibility Log

**Date:** August 13, 2026  
**Project:** Luna Desktop Pet Companion  

This document logs all Linux/Ubuntu compatibility issues, design challenges, attempted workarounds, failed solutions, and the final resolutions implemented for version 1.5.0.

---

## 1. Dragging and Options Menu Instantly Aborted (Click-Through Race)

### The Issue
On Linux (X11), clicking to drag the cat or right-clicking to open the option menu instantly aborted. The drag would stop after moving one pixel, and the tray menu would flash and close immediately.

### Attempted Approaches
*   **Attempt A (Failed):** Relying on standard `{ forward: true }` parameter in `win.setIgnoreMouseEvents()`. On Linux, this parameter is not supported by the underlying X11 system, causing the window to permanently freeze inside ignore-mouse mode or ignore the setting altogether.
*   **Attempt B (Failed):** Setting the ignore mode in the mousemove event. Because mousemove events stop firing once ignore-mouse is set to `true`, the window could never detect when the mouse moved away from the cat to restore click-through.

### Final Resolution
We implemented a main-process global mouse polling loop running every 50ms (only on Linux). It checks `screen.getCursorScreenPoint()` against `mainWindow.getBounds()`.
*   If the mouse is inside the window bounds, it sends a `'check-mouse-position'` IPC message to the renderer to perform an alpha check.
*   We wired `set-dragging` IPC events so that when the user begins dragging (`mousedown`), the polling loop is temporarily suspended and mouse-ignoring is disabled, letting the window track mouse drag moves smoothly.

---

## 2. Linux Distribution Packaging Formats (AppImage vs. DEB)

### The Issue
The build pipeline was configured to compile and upload both `.AppImage` (portable) and `.deb` (Debian/Ubuntu installer) packages for Linux, leading to redundant compile times and release asset bloating.

### Final Resolution
The user requested keeping `.deb` as the single release target format for Linux builds.
*   Removed the `"AppImage"` build target from the `linux.target` array in [package.json](file:///j:/Work/Webtree%20Online/Desktop%20pet/desktop/package.json#L33-L37).
*   Cleaned up all AppImage build scripts, paths, and release configurations in the GitHub Actions workflow file [.github/workflows/main.yml](file:///j:/Work/Webtree%20Online/Desktop%20pet/.github/workflows/main.yml).
*   Removed AppImage references from the installation documentation.

---

## 3. Input Formatting & Validation for Time Entries (6:20 vs 06:20)

### The Issue
The custom reminder time matching was strictly checking string equality against formatted system time `"HH:mm"` (e.g. `"06:20"`). If a user typed `"6:20"` into the dialog, the reminder would never trigger.

### Final Resolution
Instead of forcing users to guess the correct string structure, we added automatic normalization inside the submit callback:
*   On submit, the input string is split by colon (`:`), parsed as integers, and reformatted back with leading zeros using `String(format: "%02d:%02d")` in Swift and `.padStart(2, '0')` in JavaScript.
*   Entering `6:20` is now automatically stored as `06:20` and triggers exactly at the expected time.

---

## 4. Time Field Auto-Colon Insertion and Backspace Locking

### The Issue
Users wanted the convenience of typing two digits (e.g. `06`) and having the colon (`:`) append itself automatically so they could type minutes without searching for the colon key.

### Attempted Approaches
*   **Attempt A (Failed):** Appending `:` on every character length check of 2. If the user pressed **Backspace** to fix a typo, the length would fall from 3 to 2, causing the formatter to instantly re-append the colon, making it impossible to backspace past the colon.

### Final Resolution
We implemented an input length comparison check:
*   **Electron:** We added a custom `data-last-len` DOM attribute to the input. We only auto-append `:` if the current value length is greater than the last length (typing forward) and matches exactly 2 digits.
*   **macOS:** Conformed `AppDelegate` to `NSTextFieldDelegate` and wired `controlTextDidChange` using a `lastTimeFieldLength` state wrapper to check formatting constraints only when length increases.

---

## 5. Non-Interactive Dialogs & Cat Elements on Linux (Click Fall-Through)

### The Issue
Even after disabling ignore-mouse-events, users on Ubuntu could not click the speech bubble close button, type into custom reminder input fields, or drag the cat. Clicks fell through directly to background windows.

### Attempted Approaches
*   **Attempt A (Failed):** Using standard DOM hit testing (`e.target` and `document.elementFromPoint(x, y)`) in the mouse position check. Because the parent `#speechBubble` has `pointer-events: none` (to allow clicks to pass through the bubble text on Windows/macOS), the hit test completely bypassed the close button and returned transparent pixels, forcing the main process back into click-through ignore mode.

### Final Resolution
We replaced the DOM node hit test with a mathematical bounding box check:
*   Instead of reading DOM elements or querying canvas pixel alpha values (which can fail due to scale factor mismatches or CORS security restrictions on high-DPI Linux screens), we check if the coordinates fall inside the close button bounding rect (`getBoundingClientRect`) or the cat's coordinate bounding box (`x: 10..118`, `y: 200..320`).
*   This makes cat dragging and option menus 100% stable on Linux without impacting the precise per-pixel alpha hit tests used on macOS and Windows.

---

## 6. High-DPI Scale Factor Coordinate Offsets on Linux

### The Issue
If a user enabled fractional scaling or high-DPI scaling on Ubuntu, the cursor coordinates sent to the hit test were scaled up by 1.5x or 2x, shifting the calculated coordinate far away from the cat's physical position.

### Final Resolution
We updated the main process polling loop in `main.js` to query the screen's `scaleFactor`. On Linux, we divide the cursor coordinates by the scale factor before dispatching the position to the renderer.

---

## 7. App Dock/Taskbar Icon Visibility on Linux

### The Issue
Electron's `skipTaskbar: true` option is ignored by GNOME Shell and the Ubuntu Dock for standard window types, resulting in an active app icon showing in the dock launcher.

### Final Resolution
We configured `type: process.platform === 'linux' ? 'utility' : undefined` when instantiating the `BrowserWindow`. Marking the overlay window as a helper utility window forces the Linux task manager to hide the launcher icon completely.
