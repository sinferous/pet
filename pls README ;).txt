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
* FIRST LAUNCH (Gatekeeper Bypass): Right-click (or Control-click)
  on the app in Applications, choose "Open", and click "Open" again in
  the macOS security prompt.
* Click the 🐱 icon in your top menu bar to change water reminder
  settings.


2. Cross-Platform Desktop Version (Windows & Ubuntu Linux)
-----------------------------------------------------------

Windows:
* Install the application using the setup installer ("Luna Setup 1.0.0.exe").
  (Note: You MUST install the application rather than running a portable version from a zip or temporary folder, otherwise the "Start at Login" feature will fail to function after a system restart).
* Right-click Luna to open the context menu:
  - Select "Control Panel" to customize reminder intervals and trigger animations.
  - Select "Start at Login" to configure automatic startup.
  - Select "Quit" to exit.

Ubuntu (Linux):
* Install using the Debian package ("luna_1.0.0_amd64.deb") or run the standalone package ("Luna-1.0.0.AppImage").
  (Note: For the AppImage, right-click the file, choose "Properties" -> "Permissions", and check "Allow executing file as program", or run `chmod +x Luna-1.0.0.AppImage` from your terminal).
* Right-click Luna to open the context menu:
  - Select "Control Panel" to customize reminder intervals and trigger animations.
  - Select "Start at Login" to configure automatic startup.
  - Select "Quit" to exit.


💡 PRO-TIP: CONTROLLING AN ANNOYING CAT
------------------------------------------------------------------------

If Luna starts walking around too much or gets in your way, you can
freeze her:

* Select "Stay" (or "Idle (Park)") from the menu. Luna will walk to the
  corner of the screen and sit down quietly.

* To get her moving again, choose the "Poke" option from the menu, and
  Luna will get back up and resume normal movement.


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