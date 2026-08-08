# 🐱 Luna Autostart Fixes & Context Log

This document provides a comprehensive log of the autostart and restart fixes applied to the Windows version of **Luna**, including the root causes identified, the measures taken, and recommendations for distribution and testing.

---

## 🔍 Identified Root Causes

When checking why the application was not launching on Windows startup after a system restart, three major issues were uncovered:

1. **Temporary Execution Location (Temp Folder)**
   * **The Issue:** The application was configured to build *only* as a `portable` executable. When a user runs a portable app directly from inside a ZIP file (or a temporary folder), Windows automatically extracts and executes the application from `AppData\Local\Temp\...`.
   * **The Consequence:** The "Start at Login" routine wrote this temporary path into the Windows Registry. Upon system restart, Windows cleared the temp folder. The path became invalid, preventing the application from running.

2. **Unquoted Executable Paths containing Spaces**
   * **The Issue:** The path of the extracted folder or the portable binary contained spaces (e.g., `...DesktopPet-exe (2).zip.403\Luna 1.0.0.exe`). Under the older Electron v31 dependency, the path was written to the Windows Registry `Run` key *without* double quotes.
   * **The Consequence:** Windows Registry keys containing spaces must be quoted. Without quotes, Windows split the command on the space (interpreting `DesktopPet-exe` as the program and `(2)...` as arguments), causing immediate failure to launch.

3. **Startup Race Condition (Settings vs. Screens)**
   * **The Issue:** Inside [index.html](file:///j:/Work/Webtree%20Online/Desktop%20pet/windows/index.html), the configuration settings (including `isParked`) were requested at the top level (immediately on load), whereas screen boundaries were queried asynchronously inside the `preloadImages` callback.
   * **The Consequence:** When `isParked` was loaded from settings, the list of screens was still empty `[]`. As a result, `parkPet()` returned early without executing because it lacked screen coordinate metrics to park the pet, ignoring the user's preference on startup.

---

## 🛠️ Measures & Fixes Implemented

To ensure a seamless, reliable experience for your friends when testing, the following solutions were developed and implemented:

### 1. Switched to Combined Installer + Portable Targets
* **File Modified:** [package.json](file:///j:/Work/Webtree%20Online/Desktop%20pet/windows/package.json)
* **Action:** Added the `nsis` target in addition to `portable` under the build configuration.
* **Benefit:** When building via `npm run dist`, two versions are generated:
  - **`Luna Setup 1.0.0.exe` (NSIS Installer):** Highly recommended for distribution. It installs the application permanently to `%LOCALAPPDATA%\Programs\luna\Luna.exe`, creating stable registry entries that persist across PC restarts.
  - **`Luna 1.0.0.exe` (Portable):** A standalone version that can be run directly.

### 2. Upgraded Electron to v32 (with Registry Quoting Fix)
* **File Modified:** [package.json](file:///j:/Work/Webtree%20Online/Desktop%20pet/windows/package.json)
* **Action:** Upgraded the Electron dependency from `^31.0.0` to `^32.0.0` (resolves to `32.3.3`).
* **Benefit:** Electron v32 includes security and functionality patches that automatically wrap autostart Registry paths in double-quotes. This prevents paths with spaces or special characters from breaking the boot sequence.

### 3. Added Temporary Execution Warning Check
* **File Modified:** [main.js](file:///j:/Work/Webtree%20Online/Desktop%20pet/windows/main.js)
* **Action:** Created a helper function `checkRunningFromTemp()` called on `app.whenReady()`.
* **Benefit:** If your friends try to run the portable version directly from a temporary folder (like inside a ZIP file), the app will pop up a friendly warning dialog:
  > **Luna - Temporary Location Warning**
  >
  > *Luna is currently running from a temporary location (often happens when opened directly from a ZIP file).*
  > *The "Start at Login" feature will NOT work after a restart because temporary files are deleted by Windows.*
  > *To resolve this: Move the application to a permanent folder (like Desktop/Documents) and run it.*

### 4. Resolved Startup Race Condition
* **File Modified:** [index.html](file:///j:/Work/Webtree%20Online/Desktop%20pet/windows/index.html)
* **Action:** Moved the initial settings load routine `ipcRenderer.invoke('get-settings')` inside the `initScreens().then(...)` block at the end of the script.
* **Benefit:** This ensures that the monitor screen dimensions are fully resolved and populated in the browser state before the configuration checks `isParked` and executes the `parkPet()` function.

---

## 📦 Verification Details

* **Build Validation:** A clean compile was performed using `npm run dist` and completed successfully:
  - Assembled target `nsis` -> `dist\Luna Setup 1.0.0.exe`
  - Assembled target `portable` -> `dist\Luna 1.0.0.exe`
* **Startup Validation:** Verified that `npm start` initializes correctly without any runtime warnings or syntax errors on the updated Electron engine.

---

## 🚀 Recommendation for Testing with Friends

When sharing this application with your friends, please advise them to use the **`Luna Setup 1.0.0.exe` installer**:

1. Send them **`Luna Setup 1.0.0.exe`**.
2. They should run the setup to install Luna in a permanent, stable user directory.
3. Right-click the cat on their screen, select **Start at Login** to enable autostart.
4. When they reboot their PC, the companion will start automatically without manual launch.

---

## 🤖 Git Integration & Automated Builds

To make deployment and testing simple:
1. **Pushed to Git**: All fixes have been staged, committed, and pushed directly to the `main` branch on GitHub (`https://github.com/sinferous/pet.git`).
2. **GitHub Actions Workflow**: The push automatically triggers the CI/CD pipeline configured in [.github/workflows/main.yml](file:///j:/Work/Webtree%20Online/Desktop%20pet/.github/workflows/main.yml).
3. **Automated Artifact Generation**:
   - The workflow compiles the macOS version and packages it as **`Luna.dmg`**.
   - The workflow compiles the Windows version and packages it as **`Luna Setup 1.0.0.exe`** and **`Luna 1.0.0.exe`**.
   - Your friends can download the fresh builds directly from the GitHub Actions run artifacts or the Releases page.
