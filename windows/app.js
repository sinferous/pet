// Check environment safely without triggering require exceptions in standard browsers
const isElectron = typeof process !== 'undefined' && process.versions && process.versions.electron;
let ipcRenderer = null;

if (isElectron) {
  try {
    const electron = require('electron');
    ipcRenderer = electron.ipcRenderer;
  } catch (e) {
    console.error('Failed to load Electron ipcRenderer', e);
  }
} else {
  document.body.classList.add('browser-mode');
}

// Access behavior objects directly since they are already declared in the script scope
// const { PetState, PetAnimation, BehaviorMachine, ScreenNavigator, ScreenRect } = window;

const canvas = document.getElementById('petCanvas');
const ctx = canvas.getContext('2d', { willReadFrequently: true });
const container = document.getElementById('petContainer');

// Target Dimensions
const petWidth = 128;
const petHeight = 120;

// Preload SVG assets
const animations = {
  idle: 4,
  walk: 4,
  sleep: 2,
  drink: 4,
  play: 3,
  react: 2,
  laugh: 3,
  jump: 4
};

const images = {};
let loadedCount = 0;
let totalCount = 0;

for (const [key, val] of Object.entries(animations)) {
  totalCount += val;
}

function preloadImages(callback) {
  for (const [anim, count] of Object.entries(animations)) {
    images[anim] = [];
    for (let i = 0; i < count; i++) {
      const img = new Image();
      const onLoadOrError = () => {
        loadedCount++;
        if (loadedCount === totalCount) {
          callback();
        }
      };
      img.onload = () => {
        if (anim === 'idle' && i === 0 && isElectron) {
          try {
            const tempCanvas = document.createElement('canvas');
            tempCanvas.width = 32;
            tempCanvas.height = 32;
            const tempCtx = tempCanvas.getContext('2d');
            tempCtx.drawImage(img, 0, 0, 32, 32);
            const dataUrl = tempCanvas.toDataURL('image/png');
            ipcRenderer.send('set-tray-icon', dataUrl);
          } catch (e) {
            console.error('Failed to create tray icon from SVG', e);
          }
        }
        onLoadOrError();
      };
      img.onerror = (err) => {
        console.error(`Failed to load image: artwork/${anim}/${i}.svg`, err);
        // Show loading error on the window console/screen if applicable
        const banner = document.getElementById('error-banner');
        if (banner) {
          banner.style.display = 'block';
          banner.textContent = (banner.textContent || '') + `\nWarning: Failed to load asset: artwork/${anim}/${i}.svg`;
        }
        onLoadOrError();
      };
      img.src = `artwork/${anim}/${i}.svg`;
      images[anim].push(img);
    }
  }
}

// Initialize Behavior Engine
const behavior = new BehaviorMachine();
let screens = [];
let facing = 'right';
let walkTarget = null;
const walkSpeed = 1.5;

const animationFps = {
  idle: 2,
  walk: 6,
  sleep: 1.5,
  drink: 3,
  play: 5,
  react: 4,
  follow: 6,
  jump: 9
};

// Window/Container coordinates
let windowX = 0;
let windowY = 0;

// Drag state
let isDragging = false;
let dragOffsetX = 0;
let dragOffsetY = 0;

// Browser-mode cursor tracking
let browserMousePos = { x: 0, y: 0 };
window.addEventListener('mousemove', (e) => {
  browserMousePos.x = e.clientX;
  browserMousePos.y = e.clientY;
});

// Setup screens bounds
async function initScreens() {
  if (isElectron) {
    const displays = await ipcRenderer.invoke('get-screens');
    screens = displays.map(d => new ScreenRect(d.x, d.y, d.width, d.height));
  } else {
    // Single monitor simulated by browser window size
    screens = [new ScreenRect(0, 0, window.innerWidth, window.innerHeight)];
    window.addEventListener('resize', () => {
      screens[0] = new ScreenRect(0, 0, window.innerWidth, window.innerHeight);
    });
  }

  // Set initial position: center of primary screen
  if (screens.length > 0) {
    const s = screens[0];
    windowX = s.minX + (s.width - petWidth) / 2;
    windowY = s.minY + (s.height - petHeight) / 2;
    updateWindowBounds();
  }
}

function updateWindowBounds() {
  let yOffset = 0;
  if (currentAnim === 'jump') {
    if (currentFrameIndex === 1) {
      yOffset = -70; // High peak jump offset
    } else if (currentFrameIndex === 2) {
      yOffset = -35; // Lower landing offset
    }
  }

  if (isElectron) {
    ipcRenderer.send('set-window-bounds', { x: windowX - 64, y: windowY + yOffset });
  } else {
    container.style.left = `${windowX}px`;
    container.style.top = `${windowY + yOffset}px`;
  }
}

// Ticks walk progress
function startWalk() {
  if (screens.length === 0) return;
  walkTarget = ScreenNavigator.pickTarget(screens);
}

function advanceWalk() {
  if (!walkTarget) return;

  const step = ScreenNavigator.step(windowX, windowY, facing, walkSpeed, screens, petWidth, petHeight);
  facing = step.facing;
  windowX = step.x;
  windowY = step.y;
  updateWindowBounds();

  if (Math.abs(windowX - walkTarget.x) < walkSpeed * 2) {
    walkTarget = null;
    behavior.completeWalk();
  }
}

// Ticks cursor follow behavior
async function advanceFollow() {
  let mouse;
  if (isElectron) {
    mouse = await ipcRenderer.invoke('get-cursor-position');
  } else {
    mouse = browserMousePos;
  }

  const targetX = mouse.x - petWidth / 2;
  const dx = targetX - windowX;
  const maxStep = walkSpeed * 1.5;
  const clampedDx = Math.max(-maxStep, Math.min(maxStep, dx));

  if (Math.abs(dx) > 2) {
    facing = dx > 0 ? 'right' : 'left';
  }

  windowX += clampedDx;

  updateWindowBounds();
}

let wasPressedOnCat = false;

// Drag & Drop
container.addEventListener('mousedown', async (e) => {
  const rect = canvas.getBoundingClientRect();
  const x = e.clientX - rect.left;
  const y = e.clientY - rect.top;

  // Inspect alpha to ensure we clicked on the pet body (with fallback for Chrome local file CORS restrictions)
  let alpha = 255;
  try {
    const pixel = ctx.getImageData(x, y, 1, 1).data;
    alpha = pixel[3];
  } catch (err) {
    // Bounding box fallback: ignore click if it's on outer transparent borders
    if (x < 15 || x > 113 || y < 15 || y > 115) {
      alpha = 0;
    } else {
      console.warn('Bypassing canvas transparency check due to browser security restrictions.');
    }
  }

  if (alpha < 8) {
    wasPressedOnCat = false;
    return; // ignore transparent clicks
  }

  if (e.button === 2) {
    wasPressedOnCat = false;
    if (isElectron) {
      ipcRenderer.send('show-context-menu');
    }
    return;
  }

  wasPressedOnCat = true;
  isDragging = true;
  behavior.handleDragStart();

  if (isElectron) {
    const mouse = await ipcRenderer.invoke('get-cursor-position');
    dragOffsetX = mouse.x - windowX;
    dragOffsetY = mouse.y - windowY;
  } else {
    dragOffsetX = e.clientX - windowX;
    dragOffsetY = e.clientY - windowY;
  }
});

window.addEventListener('mousemove', async (e) => {
  if (!isDragging) return;

  let mouseX, mouseY;
  if (isElectron) {
    const mouse = await ipcRenderer.invoke('get-cursor-position');
    mouseX = mouse.x;
    mouseY = mouse.y;
  } else {
    mouseX = e.clientX;
    mouseY = e.clientY;
  }

  windowX = mouseX - dragOffsetX;
  windowY = mouseY - dragOffsetY;

  // Clamp pet to remain entirely inside the active monitor bounds
  let s = screens.find(scr => scr.contains(mouseX, mouseY));
  if (!s && screens.length > 0) {
    s = screens[0];
  }
  if (s) {
    windowX = Math.max(s.minX, Math.min(s.maxX - petWidth, windowX));
    windowY = Math.max(s.minY, Math.min(s.maxY - petHeight, windowY));
  }
  updateWindowBounds();
});

window.addEventListener('mouseup', () => {
  if (!wasPressedOnCat) {
    return; // ignore clicks that did not start on the cat
  }
  wasPressedOnCat = false;

  if (!isDragging) {
    behavior.handleClick();
  } else {
    isDragging = false;
    behavior.handleDragEnd();

    // Keep the current height instead of snapping to floor
    updateWindowBounds();
  }
});

window.addEventListener('contextmenu', (e) => {
  e.preventDefault();
});

// Hit-testing transparency (only relevant in Electron)
function handleMouseMove(e) {
  if (isDragging || !isElectron) return;

  const closeEl = document.getElementById('speechBubbleClose');
  const isOverCloseBtn = e.target === closeEl || (e.target && e.target.closest('#speechBubbleClose'));

  if (isOverCloseBtn) {
    ipcRenderer.send('set-ignore-mouse-events', false, { forward: true });
    return;
  }

  const rect = canvas.getBoundingClientRect();
  const x = e.clientX - rect.left;
  const y = e.clientY - rect.top;

  if (x >= 0 && x < petWidth && y >= 0 && y < petHeight) {
    const pixel = ctx.getImageData(x, y, 1, 1).data;
    const alpha = pixel[3];
    const ignore = alpha < 8;
    ipcRenderer.send('set-ignore-mouse-events', ignore, { forward: true });
  } else {
    ipcRenderer.send('set-ignore-mouse-events', true, { forward: true });
  }
}

if (isElectron) {
  window.addEventListener('mousemove', handleMouseMove);
}

const waterSentences = [
  "💧 Stay hydrated, human!",
  "💧 Glug glug! Water time!",
  "💧 Drink water now!",
  "💧 Keep your batteries full!",
  "💧 Hydrate or dry-rate!",
  "💧 Be like a plant: water!",
  "💧 System alert: Drink water!",
  "💧 Take a sip of water!",
  "💧 Hydration check!",
  "💧 Drink up!"
];

const catVoices = [
  "Purrrrr...",
  "Meow~",
  "Prrrp?",
  "Mrrrp!",
  "Nyaa~",
  "Prrrr...",
  "Meow! 🐾",
  "*stretches*",
  "Purrrrrrrrr..."
];

let speechTimeout = null;
let isWaterReminderActive = false;

function showSpeechBubble(text, isWaterReminder = false) {
  const bubble = document.getElementById('speechBubble');
  const textEl = document.getElementById('speechBubbleText');
  const closeEl = document.getElementById('speechBubbleClose');
  if (!bubble || !textEl) return;

  textEl.textContent = text;
  bubble.style.display = 'block';
  isWaterReminderActive = isWaterReminder;

  if (closeEl) {
    closeEl.style.display = isWaterReminder ? 'flex' : 'none';
  }

  if (speechTimeout) {
    clearTimeout(speechTimeout);
    speechTimeout = null;
  }

  if (!isWaterReminder) {
    speechTimeout = setTimeout(() => {
      bubble.style.display = 'none';
    }, 3000);
  }
}

function triggerWaterReminderBubble() {
  const idx = Math.floor(Math.random() * waterSentences.length);
  showSpeechBubble(waterSentences[idx], true);
}

window.closeSpeechBubble = (event) => {
  if (event) event.stopPropagation(); // prevent drag trigger
  const bubble = document.getElementById('speechBubble');
  if (bubble) {
    bubble.style.display = 'none';
  }
  if (isWaterReminderActive) {
    isWaterReminderActive = false;
    behavior.enter(PetState.run); // run somewhere else immediately!
  }
};

function triggerRandomMeow() {
  // Disabled as per user request
}

function showSayBubble() {
  // Only show if not currently showing a bubble
  const bubble = document.getElementById('speechBubble');
  if (bubble && bubble.style.display === 'block') return;
  showSpeechBubble("sathya sathya sathya", 4000);
}

window.showSayBubble = showSayBubble;

// State transition callback
behavior.onStateChange = (state) => {
  currentAnim = state === PetState.follow ? 'walk' : state;
  currentFrameIndex = 0;
  animTime = 0;

  if (state === PetState.walk) {
    startWalk();
  } else if (state === PetState.drink) {
    triggerWaterReminderBubble();
  } else if (state === PetState.react) {
    // React state plays animation but has no voice bubbles as requested
  }
};

// Animation playback state
let currentAnim = 'idle';
let currentFrameIndex = 0;
let animTime = 0;

// 60Hz Loop
let lastTime = performance.now();

function loop(now) {
  const dt = (now - lastTime) / 1000.0;
  lastTime = now;

  behavior.tick();

  if (hydrationWalkTarget) {
    // Running to center
    const step = ScreenNavigator.step(windowX, windowY, hydrationWalkTarget.x, hydrationWalkTarget.y, walkSpeed * 2.5, screens, petWidth, petHeight);
    facing = step.facing;
    windowX = step.x;
    windowY = step.y;
    updateWindowBounds();
    currentAnim = 'run';
    if (Math.hypot(windowX - hydrationWalkTarget.x, windowY - hydrationWalkTarget.y) < walkSpeed * 2.5 * 1.5) {
      hydrationWalkTarget = null;
      behavior.setParked(false);
      behavior.enter(PetState.drink);
    }
  } else if (behavior.state === PetState.walk) {
    advanceWalk();
  } else if (behavior.state === PetState.follow) {
    advanceFollow();
  } else if (behavior.state === PetState.idle) {
    // Proximity check in browser-mode (in Electron it is monitored globally in main.js)
    if (!isElectron) {
      const dx = browserMousePos.x - (windowX + petWidth / 2);
      const dy = browserMousePos.y - (windowY + petHeight / 2);
      const dist = Math.sqrt(dx * dx + dy * dy);
      behavior.setCursor(dist < 80);
    }
  }

  // Play Animation
  const fps = animationFps[behavior.state] || 2;
  animTime += dt;
  const animKey = currentAnim === 'follow' ? 'walk' : currentAnim;
  const frames = images[animKey] || [];

  if (frames.length > 0) {
    currentFrameIndex = Math.floor(animTime * fps) % frames.length;
    const img = frames[currentFrameIndex];

    ctx.clearRect(0, 0, petWidth, petHeight);
    ctx.save();

    if (facing === 'left') {
      ctx.translate(petWidth, 0);
      ctx.scale(-1, 1);
    }

    ctx.drawImage(img, 0, 0, petWidth, petHeight);
    ctx.restore();

    // Draw Zzz overlay for Sleep (after restore, so it is never inverted)
    if (behavior.state === PetState.sleep) {
      ctx.save();
      ctx.fillStyle = '#010101'; // match the black outlines of the cat
      ctx.font = 'bold 20px monospace';
      
      const bobZ = Math.sin(animTime * 3.5) * 3.5;
      const isLeft = facing === 'left';
      const zX = isLeft ? petWidth * 0.22 : petWidth * 0.68;
      
      ctx.fillText('Z', zX, petHeight * 0.28 + bobZ);
      ctx.font = 'bold 13px monospace';
      ctx.fillText('z', zX + (isLeft ? 15 : -15), petHeight * 0.40 + bobZ);
      ctx.restore();
    }
  }

  updateWindowBounds();

  requestAnimationFrame(loop);
}

let hydrationWalkTarget = null;

function triggerWaterHydrationFlow() {
  if (screens.length === 0) return;
  const s = screens[0];
  const targetX = s.minX + (s.width - petWidth) / 2;
  const targetY = s.minY + (s.height - petHeight) / 2;
  hydrationWalkTarget = { x: targetX, y: targetY };
  currentAnim = 'run';
  currentFrameIndex = 0;
  animTime = 0;
  behavior.setParked(true);
}

// Water Reminder preview trigger (every 10 seconds for testing)
setInterval(() => {
  if (typeof Notification !== 'undefined' && Notification.permission === 'granted') {
    new Notification('Desktop Pet', {
      body: 'Time to drink some water! 💧'
    });
  }
  triggerWaterHydrationFlow();
}, 10000);

// Request notification permission in browser mode
if (!isElectron && typeof Notification !== 'undefined' && Notification.requestPermission) {
  Notification.requestPermission().catch(err => {
    console.log('Notification permission request ignored or blocked', err);
  });
}

// Keyboard Shortcut for testing water drink reminder instantly
window.addEventListener('keydown', (e) => {
  if (e.key.toLowerCase() === 'w') {
    console.log('Mocking water reminder...');
    triggerWaterHydrationFlow();
  }
});

window.triggerState = (stateName) => {
  console.log(`Manually triggering state: ${stateName}`);
  if (stateName === 'drink') {
    triggerWaterHydrationFlow();
  } else {
    behavior.enter(stateName);
  }
};

// Force the cat to walk/run to a random position every 1 minute
setInterval(() => {
  // Ignore if busy, dragging, settings dialog open, or showing a water reminder
  if (hydrationWalkTarget || isPromptDialogOpen || isDragging || isWaterReminderActive) return;
  const state = Math.random() < 0.5 ? PetState.walk : PetState.run;
  behavior.enter(state);
}, 60000);

// Start Application
preloadImages(() => {
  initScreens().then(() => {
    if (isElectron) {
      const cp = document.getElementById('controlPanel');
      if (cp) cp.style.display = 'none';
    }
    requestAnimationFrame(loop);
  });
});
