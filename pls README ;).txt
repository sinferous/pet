========================================================================
                            🐱 LUNA
              macOS, Windows & Ubuntu (Linux) Desktop Pet
========================================================================

Published by: sinferous 🐾
License: MIT


Welcome to Luna! A cute pixel-art companion that lives on your desktop,
walks across your monitors, plays, sleeps, and keeps you hydrated with
custom, silence-friendly water reminders.

A small desktop pet made to bring a little life to your workspace.


🌟 CORE FEATURES
------------------------------------------------------------------------

* 🐾 Cute Pixel-Art Pet
  Bobs, blinks, walks, sleeps, plays, and reacts when petted.

* 🖥️ Multi-Monitor Support
  Walks seamlessly across multiple screens and aligns at display
  boundaries.

* 💧 Smart Water Reminders
  Keeps you hydrated on your terms:
  - Custom interval selector (choose 1, 15, 30, 45, or 60 minutes).
  - No noisy background meows/purrs: reminders are strictly
    water-focused.

* 🏃 Hydration Sprint
  When it is water time, Luna runs directly to the center of your
  primary screen.

* 🔴 Persistent Alert
  The water bubble stays centered in the screen with a red close ("x")
  button and will not auto-dismiss.

* 💨 Dismiss Sprint
  Closing the alert triggers Luna to immediately sprint away to a new
  random location.

* 🖱️ Smooth Drag & Drop
  Drag Luna anywhere with zero jitter or lag.

* 👻 Click-Through Transparency
  Click on empty space behind Luna to interact with windows underneath.

* 🚀 Start at Login
  Launch the application automatically at system startup.

* 😴 Prevent Sleep (macOS)
  Keeps your computer awake while Luna is running.


🖥️ HOW TO TEST & RUN
------------------------------------------------------------------------

1. macOS Version (Native Swift)
--------------------------------

* Open the "Luna.dmg" package.
* Drag "Luna" to your Applications folder.
  (Note: You MUST drag the application to the Applications folder and run it
  from there instead of running it directly from the mounted DMG or temporary
  folders. Running it outside Applications causes macOS path randomization
  (translocation), which will prevent the "Start at Login" feature from working).
* FIRST LAUNCH (Gatekeeper Bypass): Since the app is unsigned/ad-hoc signed, macOS may block it or claim it is "damaged".
  - Option A: Right-click (or Control-click) on the app in `/Applications`, choose "Open", and confirm.
  - Option B: Go to **System Settings** > **Privacy & Security** and click **Open Anyway** under the security section.
  - Option C: If you see a "damaged and can't be opened" error, clear macOS quarantine by opening Terminal and running:
    `xattr -dr com.apple.quarantine /Applications/Luna.app`
* Click the 🐱 icon in your top menu bar to manage settings:
  - Toggle "Water Reminders", "Prevent Sleep", and "Start at Login".
  - Toggle "Hide/Seek" to instantly hide or show the pet.
  - Toggle "Idle (Park)" to park the pet in the bottom-left corner.
  - Choose "Poke" to unpark the pet.
  - Choose "Set Custom Reminder..." to set a time (e.g. 14:30) and message for today.


2. Cross-Platform Desktop Version (Windows & Ubuntu Linux)
-----------------------------------------------------------

Windows:
* Install the application using the setup installer ("Luna Setup 1.5.0.exe").
  (Note: You MUST install the application rather than running a portable version from a zip or temporary folder, otherwise the "Start at Login" feature will fail to function after a system restart).
* Right-click Luna (or the tray icon) to open the context menu:
  - Select "Control Panel" to customize reminder intervals and trigger animations.
  - Select "Start at Login" to configure automatic startup.
  - Select "Hide/Seek" to completely hide or show the pet window.
  - Select "Idle (Park)" to send the pet to the bottom-left corner.
  - Select "Poke" to unpark the pet.
  - Select "Set Custom Reminder..." to input a time and alert message for today.
  - Select "Quit" to exit.

Ubuntu (Linux):
* Install using the Debian package ("luna_1.5.0_amd64.deb").
* Right-click Luna (or the tray icon) to open the context menu:
  - Select "Control Panel" to customize reminder intervals and trigger animations.
  - Select "Start at Login" to configure automatic startup.
  - Select "Hide/Seek" to completely hide or show the pet window.
  - Select "Idle (Park)" to send the pet to the bottom-left corner.
  - Select "Poke" to unpark the pet.
  - Select "Set Custom Reminder..." to input a time and alert message for today.
  - Select "Quit" to exit.


💡 PRO-TIP: CONTROLLING AN ANNOYING CAT
------------------------------------------------------------------------

If Luna gets in your way, you can easily control her visibility or location:

* HIDE/SEEK (MEETINGS): Select "Hide/Seek" from the tray/menu bar. Luna will completely disappear from the screen (perfect for meetings or screen sharing). Select "Hide/Seek" again to bring her back.

* IDLE (PARK): Select "Idle (Park)" from the menu. Luna will walk to the bottom-left corner and sit quietly. The only override is a water reminder, which will temporarily bring her to the center of the display. Once dismissed, she will automatically walk back to her park position.

* POKE: Select "Poke" from the menu to wake her up from Park mode and resume normal wandering.


🛠️ HOW TO BUILD FROM SOURCE
------------------------------------------------------------------------

Cross-Platform Desktop Version (Windows & Linux):

* Install Node.js (with npm).
* Navigate to the `desktop` folder (`cd desktop`).
* Run "npm install" to install dependencies.
* Run "npm start" to run in development mode.
* Run "npm run dist" to package for Windows distribution.
* Run "npm run dist:linux" to package for Linux (AppImage & deb) distribution.


macOS Version:

* Requires macOS 13+ and Swift 5.9+.
* Run "swift build" to compile development build.
* Run "swift test" to run test suites.
* Run "swift build -c release" and run "bash scripts/build_app.sh"
  to package the App Bundle.


🐾 A LITTLE NOTE FROM THE DEVELOPER
------------------------------------------------------------------------

Luna started with a simple idea:

What if your desktop had a tiny companion that actually felt alive?

Something that could walk around while you work, remind you to drink
water, and make your desktop a little less boring.

That's Luna.

— sinferous 🐾


📫 FEEDBACK & SUPPORT
------------------------------------------------------------------------

If you find any bugs, have feedback, or want to suggest new features,
please report them directly to the developer at:

sinferous32@gmail.com


------------------------------------------------------------------------
             🐱 Thanks for giving Luna a home in your HEART.
========================================================================