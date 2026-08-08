========================================================================
                          🐱 LUNA (macOS & Windows)
========================================================================
Published by: sinferous 🐾
License: MIT

Welcome to Luna! A cute pixel-art companion that lives on your
desktop, walks across your monitors, plays, sleeps, and keeps you hydrated
with custom, silence-friendly water reminders.


🌟 CORE FEATURES
------------------------------------------------------------------------
* Cute Pixel-Art Pet: Bobs, blinks, walks, sleeps, plays, and reacts when pet.
* Multi-Monitor Support: Walks seamlessly across multiple screens and
  aligns perfectly at display boundaries.
* Smart Water Reminders: Keeps you hydrated on your terms:
  - Custom interval selector (choose 1, 15, 30, 45, or 60 minutes).
  - No noisy background meows/purrs: Reminders are strictly water-focused.
* Hydration Sprint: When it is water time, the cat runs directly to the
  center of your primary screen.
* Persistent Alert: The water bubble stays centered in the screen with
  a red close ("x") button and will not auto-dismiss.
* Dismiss Sprint: Closing the alert triggers the cat to immediately
  sprint away to a new random location.
* Smooth Drag & Drop: Drag the cat anywhere with zero jitter or lag.
* Click-Through Transparency: Click on empty space behind the cat to
  interact with windows underneath.
* Start at Login: Launch the application automatically at system startup.
* Prevent Sleep (macOS): Keeps your computer awake while running.


🖥️ HOW TO TEST & RUN

1. macOS Version (Native Swift)
----------------------------------------
* Open the "Luna.dmg" package.
* Drag "Luna" to your Applications folder.
* FIRST LAUNCH (Gatekeeper Bypass): Right-click (or Control-click)
  on the app in Applications, choose "Open", and click "Open" again in
  the macOS security prompt.
* Click the 🐱 icon in your top menu bar to change water reminder settings.

2. Windows Version (Electron)
----------------------------------------
* Run the installer executable or launch "Luna.exe" from the build.
* Right-click the cat to open the context menu:
  - Select "Control Panel" to customize reminder intervals and trigger animations.
  - Select "Start at Login" to configure automatic startup.
  - Select "Quit" to exit.


💡 PRO-TIP: CONTROLLING AN ANNOYING CAT
------------------------------------------------------------------------
If the cat starts walking around too much or gets in your way, you can
freeze it:
* Select "Stay" (or "Idle (Park)") from the menu. The cat will walk to
  the corner of the screen and sit down quietly.
* To get it moving again, choose the "Poke" option from the menu, and
  it will get back up and resume normal movement.


🛠️ HOW TO BUILD FROM SOURCE

Windows Version:
* Install Node.js (with npm).
* Run `npm install` in the project root to install dependencies.
* Run `npm start` to run in development mode.
* Run `npm run package` to package for distribution.

macOS Version:
* Requires macOS 13+ and Swift 5.9+.
* Run `swift build` to compile development build.
* Run `swift test` to run test suites.
* Run `swift build -c release` and run `bash scripts/build_app.sh`
  to package the App Bundle.


📫 FEEDBACK & SUPPORT
------------------------------------------------------------------------
If you find any bugs, have feedback, or want to suggest new features,
please report them directly to the developer at: sinferous32@gmail.com
