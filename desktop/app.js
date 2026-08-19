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

const canvas = document.getElementById('petCanvas');
const ctx = canvas.getContext('2d', { willReadFrequently: true });
const container = document.getElementById('petContainer');

// Target Dimensions
const petWidth = 128;
const petHeight = 120;
const headroom = 200;
const winHeight = petHeight + headroom; // 320px total window height

// Preload SVG assets
const animations = {
  idle: 4,
  walk: 4,
  run: 4,
  sleep: 2,
  drink: 4,
  play: 3,
  react: 2,
  laugh: 3,
  jump: 4,
  roll: 4,
  love: 3,
  anger: 2
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
const runSpeed = 4.0;
const rollSpeed = 1.5;
let rollDir = 1;

const animationFps = {
  idle: 2,
  walk: 6,
  run: 12,
  sleep: 1.5,
  drink: 3,
  play: 5,
  react: 4,
  laugh: 4,
  jump: 6,
  roll: 6,
  love: 4,
  anger: 2
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
    screens = [new ScreenRect(0, 0, window.innerWidth, window.innerHeight)];
    window.addEventListener('resize', () => {
      screens[0] = new ScreenRect(0, 0, window.innerWidth, window.innerHeight);
    });
  }

  if (screens.length > 0) {
    const s = screens[0];
    windowX = s.minX + (s.width - petWidth) / 2;
    windowY = s.minY + (s.height - petHeight) / 2;
    updateWindowBounds();
  }
}

let isStayAtBottom = false;

if (isElectron) {
  ipcRenderer.invoke('get-settings').then(s => {
    if (s && typeof s.stayAtBottom === 'boolean') {
      isStayAtBottom = s.stayAtBottom;
    }
  });
  ipcRenderer.on('update-settings', (event, s) => {
    if (s && typeof s.stayAtBottom === 'boolean') {
      isStayAtBottom = s.stayAtBottom;
      if (isStayAtBottom && screens.length > 0) {
        behavior.enter(PetState.run);
      }
    }
  });
}

function updateWindowBounds() {
  if (isStayAtBottom && screens.length > 0) {
    let s = screens.find(scr => scr.contains(windowX, windowY)) || screens[0];
    windowY = s.maxY - winHeight;
  }

  let yOffset = 0;
  if (currentAnim === 'jump') {
    if (currentFrameIndex === 1) {
      yOffset = -70;
    } else if (currentFrameIndex === 2) {
      yOffset = -35;
    }
  }

  if (isElectron) {
    ipcRenderer.send('set-window-bounds', { x: windowX - 64, y: windowY + yOffset });
  } else {
    container.style.left = `${windowX}px`;
    container.style.top = `${windowY + yOffset}px`;
  }
}

function startWalk() {
  if (screens.length === 0) return;
  walkTarget = ScreenNavigator.pickTarget(screens, 40, petWidth, petHeight, 0, isStayAtBottom);
}

function advanceWalk(speed = walkSpeed) {
  if (!walkTarget) return;

  const step = ScreenNavigator.step(windowX, windowY, walkTarget.x, walkTarget.y, speed, screens, petWidth, petHeight);
  facing = step.facing;
  windowX = step.x;
  windowY = step.y;
  updateWindowBounds();

  if (Math.hypot(windowX - walkTarget.x, windowY - walkTarget.y) < speed * 1.5) {
    walkTarget = null;
    behavior.completeWalk();
  }
}

function advanceRoll() {
  if (screens.length === 0) return;
  let s = screens.find(scr => scr.contains(windowX + petWidth / 2, windowY + petHeight / 2)) || screens[0];
  let x = windowX + rollDir * rollSpeed;
  if (x <= s.minX) {
    x = s.minX + 0.1;
    rollDir = 1;
  } else if (x >= s.maxX - petWidth) {
    x = s.maxX - petWidth - 0.1;
    rollDir = -1;
  }
  windowX = x;
  facing = rollDir > 0 ? 'right' : 'left';
  updateWindowBounds();
}

let followSprinting = false;

async function advanceFollow() {
  let mouse;
  if (isElectron) {
    mouse = await ipcRenderer.invoke('get-cursor-position');
  } else {
    mouse = browserMousePos;
  }

  const targetX = mouse.x - petWidth / 2;
  const dx = targetX - windowX;
  const dist = Math.abs(dx);
  followSprinting = dist > 250;
  const maxStep = followSprinting ? runSpeed : walkSpeed * 1.5;
  const clampedDx = Math.max(-maxStep, Math.min(maxStep, dx));

  if (Math.abs(dx) > 2) {
    facing = dx > 0 ? 'right' : 'left';
  }

  windowX += clampedDx;
  updateWindowBounds();
}

let wasPressedOnCat = false;

container.addEventListener('mousedown', async (e) => {
  const rect = canvas.getBoundingClientRect();
  const x = e.clientX - rect.left;
  const y = e.clientY - rect.top;

  let alpha = 255;
  try {
    const pixel = ctx.getImageData(x, y, 1, 1).data;
    alpha = pixel[3];
  } catch (err) {
    if (x < 10 || x > 118 || y < headroom + 10 || y > winHeight - 5) {
      alpha = 0;
    }
  }

  if (alpha < 4) {
    wasPressedOnCat = false;
    return;
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
  if (isElectron) {
    ipcRenderer.send('set-dragging', true);
    ipcRenderer.send('set-ignore-mouse-events', false);
  }
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

  let s = screens.find(scr => scr.contains(mouseX, mouseY));
  if (!s && screens.length > 0) {
    s = screens[0];
  }
  if (s) {
    windowX = Math.max(s.minX, Math.min(s.maxX - petWidth, windowX));
    if (isStayAtBottom) {
      windowY = s.maxY - winHeight;
    } else {
      windowY = Math.max(s.minY, Math.min(s.maxY - winHeight, windowY));
    }
  }
  updateWindowBounds();
});

window.addEventListener('mouseup', () => {
  if (!wasPressedOnCat) return;
  wasPressedOnCat = false;

  if (!isDragging) {
    behavior.handleClick();
  } else {
    isDragging = false;
    if (isElectron) {
      ipcRenderer.send('set-dragging', false);
    }
    behavior.handleDragEnd();

    if (isManuallyParked) {
      parkPet();
    } else {
      updateWindowBounds();
    }
  }
});

window.addEventListener('contextmenu', (e) => {
  e.preventDefault();
  if (isElectron) {
    ipcRenderer.send('show-context-menu');
  }
});

function handleMouseMove(e) {
  if (isDragging || !isElectron) return;

  if ((typeof isPromptDialogOpen !== 'undefined' && isPromptDialogOpen) || (typeof isReminderDialogOpen !== 'undefined' && isReminderDialogOpen)) {
    ipcRenderer.send('set-ignore-mouse-events', false, { forward: true });
    return;
  }

  const closeEl = document.getElementById('speechBubbleClose');
  let isOverCloseBtn = false;
  if (closeEl && window.getComputedStyle(closeEl).display !== 'none') {
    const crect = closeEl.getBoundingClientRect();
    isOverCloseBtn = (
      e.clientX >= crect.left &&
      e.clientX < crect.right &&
      e.clientY >= crect.top &&
      e.clientY < crect.bottom
    );
  }

  if (isOverCloseBtn) {
    ipcRenderer.send('set-ignore-mouse-events', false, { forward: true });
    return;
  }

  const rect = canvas.getBoundingClientRect();
  const x = e.clientX - rect.left;
  const y = e.clientY - rect.top;

  let ignore = true;
  if (x >= 0 && x < petWidth && y >= headroom && y < winHeight) {
    if (isElectron && process.platform === 'linux') {
      ignore = false;
    } else {
      try {
        const pixel = ctx.getImageData(x, y, 1, 1).data;
        ignore = pixel[3] < 4;
      } catch (err) {
        ignore = !(x >= 10 && x < 118 && y >= headroom + 10 && y < winHeight - 5);
      }
    }
  }
  ipcRenderer.send('set-ignore-mouse-events', ignore, { forward: true });
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
  if (event) event.stopPropagation();
  const bubble = document.getElementById('speechBubble');
  if (bubble) {
    bubble.style.display = 'none';
  }
  if (isWaterReminderActive) {
    isWaterReminderActive = false;
    if (isManuallyParked) {
      parkPet();
    } else {
      behavior.setParked(false);
      behavior.enter(PetState.run);
    }
  }
};

function triggerRandomMeow() {
  const bubble = document.getElementById('speechBubble');
  if (bubble && bubble.style.display === 'block') return;

  const idx = Math.floor(Math.random() * catVoices.length);
  showSpeechBubble(catVoices[idx], false);
}

function showSayBubble() {
  const bubble = document.getElementById('speechBubble');
  if (bubble && bubble.style.display === 'block') return;
  showSpeechBubble("Sathya Sathya", false);
}

window.showSayBubble = showSayBubble;

// Particle & Celebration effects (cheer, love, wool ball)
const rollColors = ['#ff6b6b', '#ffd93d', '#6bcb77', '#4d96ff', '#ff9f45', '#c77dff', '#ff5d8f'];
let confetti = [];
let heartEmojis = [];
let woolBall = null;

function spawnConfettiBurst(count) {
  for (let i = 0; i < count; i++) {
    confetti.push({
      x: petWidth / 2 + (Math.random() - 0.5) * petWidth,
      y: headroom + petHeight * (0.25 + Math.random() * 0.55),
      vx: (Math.random() - 0.5) * 280,
      vy: -(Math.random() * 220 + 60),
      w: 4 + Math.random() * 4,
      h: 6 + Math.random() * 5,
      color: rollColors[Math.floor(Math.random() * rollColors.length)],
      rot: Math.random() * Math.PI * 2,
      vr: (Math.random() - 0.5) * 12,
      life: 0.8 + Math.random() * 1.4
    });
  }
}

function spawnHeartEmoji(count) {
  for (let i = 0; i < count; i++) {
    heartEmojis.push({
      x: petWidth * (0.15 + Math.random() * 0.7),
      y: headroom + petHeight * (0.15 + Math.random() * 0.4),
      vx: (Math.random() - 0.5) * 26,
      vy: -(16 + Math.random() * 26),
      size: 5 + Math.random() * 7,
      life: 1.2 + Math.random() * 1.1,
      wobble: Math.random() * Math.PI * 2
    });
  }
}

function startCheer() {
  confetti = [];
  spawnConfettiBurst(48);
}

function startLove() {
  heartEmojis = [];
  spawnHeartEmoji(7);
}

function startWoolBall() {
  woolBall = {
    x: petWidth / 2,
    y: headroom + petHeight * 0.4,
    vx: (Math.random() > 0.5 ? 1 : -1) * (140 + Math.random() * 80),
    vy: -(120 + Math.random() * 60),
    r: 10,
    rot: 0
  };
}

function updateEffects(dt) {
  for (let i = confetti.length - 1; i >= 0; i--) {
    const p = confetti[i];
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vy += 320 * dt;
    p.rot += p.vr * dt;
    p.life -= dt;
    if (p.life <= 0 || p.y > winHeight + 10) {
      confetti.splice(i, 1);
    }
  }

  for (let i = heartEmojis.length - 1; i >= 0; i--) {
    const h = heartEmojis[i];
    h.y += h.vy * dt;
    h.wobble += dt * 5;
    h.x += Math.sin(h.wobble) * 20 * dt;
    h.life -= dt;
    if (h.life <= 0) {
      heartEmojis.splice(i, 1);
    }
  }

  if (woolBall) {
    const b = woolBall;
    b.x += b.vx * dt;
    b.y += b.vy * dt;
    b.vy += 400 * dt;
    b.rot += (b.vx / b.r) * dt;

    if (b.x - b.r < 0) {
      b.x = b.r;
      b.vx = Math.abs(b.vx) * 0.85;
    } else if (b.x + b.r > petWidth) {
      b.x = petWidth - b.r;
      b.vx = -Math.abs(b.vx) * 0.85;
    }

    const floorY = headroom + petHeight - b.r;
    if (b.y > floorY) {
      b.y = floorY;
      b.vy = -Math.abs(b.vy) * 0.75;
      b.vx *= 0.95;
    }
  }
}

function drawEffects(ctx) {
  confetti.forEach(p => {
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(p.rot);
    ctx.fillStyle = p.color;
    ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
    ctx.restore();
  });

  heartEmojis.forEach(h => {
    ctx.save();
    ctx.font = `${h.size * 2}px sans-serif`;
    ctx.fillStyle = '#ff4d4d';
    ctx.fillText('❤️', h.x, h.y);
    ctx.restore();
  });

  if (woolBall) {
    const b = woolBall;
    ctx.save();
    ctx.translate(b.x, b.y);
    ctx.rotate(b.rot);
    ctx.beginPath();
    ctx.arc(0, 0, b.r, 0, Math.PI * 2);
    ctx.fillStyle = '#e8590c';
    ctx.fill();
    ctx.strokeStyle = '#c2255c';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.strokeStyle = '#ff922b';
    ctx.lineWidth = 1.5;
    for (let i = 0; i < 3; i++) {
      ctx.beginPath();
      ctx.arc(0, 0, b.r * 0.8, i * Math.PI / 3, i * Math.PI / 3 + Math.PI * 0.8);
      ctx.stroke();
    }
    ctx.restore();
  }
}

// State transition callback
behavior.onStateChange = (state) => {
  currentAnim = state === PetState.follow ? 'walk' : state;
  if (state === PetState.cheer) {
    currentAnim = 'love';
  } else if (state === PetState.woolball) {
    currentAnim = 'play';
  }
  currentFrameIndex = 0;
  animTime = 0;

  if (state === PetState.cheer) {
    startCheer();
  } else if (state === PetState.love) {
    startLove();
  } else if (state === PetState.woolball) {
    startWoolBall();
  } else {
    woolBall = null;
  }

  if (state === PetState.walk || state === PetState.run) {
    startWalk();
  } else if (state === PetState.drink) {
    if (pendingCustomReminderMessage) {
      showSpeechBubble(pendingCustomReminderMessage, true);
      pendingCustomReminderMessage = null;
    } else {
      triggerWaterReminderBubble();
    }
  } else if (state === PetState.cheer) {
    if (pendingCustomReminderMessage) {
      showSpeechBubble(pendingCustomReminderMessage, true);
      pendingCustomReminderMessage = null;
    }
  } else if (state === PetState.react) {
    // React/shy state plays animation but shows no voice bubble as requested
  }
};

// Animation playback state
let currentAnim = 'idle';
let currentFrameIndex = 0;
let animTime = 0;

// 60Hz Loop
let lastTime = performance.now();

function loop(now) {
  const dt = Math.min((now - lastTime) / 1000, 0.1);
  lastTime = now;

  const bubble = document.getElementById('speechBubble');
  const isBubbleActive = bubble && bubble.style.display === 'block';

  if (!isBubbleActive) {
    behavior.tick();

    if (hydrationWalkTarget) {
      const step = ScreenNavigator.step(windowX, windowY, hydrationWalkTarget.x, hydrationWalkTarget.y, walkSpeed * 2.5, screens, petWidth, petHeight);
      facing = step.facing;
      windowX = step.x;
      windowY = step.y;
      updateWindowBounds();
      currentAnim = 'run';
      if (Math.hypot(windowX - hydrationWalkTarget.x, windowY - hydrationWalkTarget.y) < walkSpeed * 2.5 * 1.5) {
        hydrationWalkTarget = null;
        if (pendingCustomReminderMessage) {
          behavior.enter(PetState.cheer);
        } else {
          behavior.enter(PetState.drink);
        }
      }
    } else if (parkWalkTarget) {
      const step = ScreenNavigator.step(windowX, windowY, parkWalkTarget.x, parkWalkTarget.y, walkSpeed * 1.5, screens, petWidth, petHeight);
      facing = step.facing;
      windowX = step.x;
      windowY = step.y;
      updateWindowBounds();
      currentAnim = 'walk';
      if (Math.hypot(windowX - parkWalkTarget.x, windowY - parkWalkTarget.y) < walkSpeed * 1.5 * 1.5) {
        parkWalkTarget = null;
        currentAnim = 'idle';
      }
    } else if (behavior.state === PetState.walk) {
      advanceWalk(walkSpeed);
    } else if (behavior.state === PetState.run) {
      advanceWalk(runSpeed);
    } else if (behavior.state === PetState.roll) {
      advanceRoll();
    } else if (behavior.state === PetState.cheer) {
      if (Math.random() < dt * 10) spawnConfettiBurst(2);
    } else if (behavior.state === PetState.woolball) {
      if (woolBall) facing = woolBall.x < petWidth / 2 ? 'left' : 'right';
    } else if (behavior.state === PetState.follow) {
      advanceFollow();
    } else if (behavior.state === PetState.idle) {
      if (!isElectron) {
        const dx = browserMousePos.x - (windowX + petWidth / 2);
        const dy = browserMousePos.y - (windowY + headroom + petHeight / 2);
        const dist = Math.sqrt(dx * dx + dy * dy);
        behavior.setCursor(dist < 80);
      }
    }
  }

  updateEffects(dt);

  const fps = animationFps[behavior.state] || 2;
  animTime += dt;
  const animKey = currentAnim === 'follow' ? (followSprinting ? 'run' : 'walk') : currentAnim;
  const frames = images[animKey] || [];

  if (frames.length > 0) {
    currentFrameIndex = Math.floor(animTime * fps) % frames.length;
    const img = frames[currentFrameIndex];

    ctx.clearRect(0, 0, petWidth, winHeight);
    ctx.save();

    if (facing === 'left') {
      ctx.translate(petWidth, 0);
      ctx.scale(-1, 1);
    }

    ctx.drawImage(img, 0, headroom, petWidth, petHeight);
    ctx.restore();

    if (behavior.state === PetState.sleep) {
      ctx.save();
      ctx.fillStyle = '#010101';
      ctx.font = 'bold 20px monospace';
      
      const bobZ = Math.sin(animTime * 3.5) * 3.5;
      const isLeft = facing === 'left';
      const zX = isLeft ? petWidth * 0.22 : petWidth * 0.68;
      
      ctx.fillText('Z', zX, headroom + petHeight * 0.28 + bobZ);
      ctx.font = 'bold 13px monospace';
      ctx.fillText('z', zX + (isLeft ? 15 : -15), headroom + petHeight * 0.40 + bobZ);
      ctx.restore();
    }
  }

  drawEffects(ctx);
  updateWindowBounds();

  requestAnimationFrame(loop);
}

let hydrationWalkTarget = null;

function triggerWaterHydrationFlow() {
  if (screens.length === 0) return;
  const s = screens[0];
  const targetX = s.minX + (s.width - petWidth) / 2;
  const targetY = isStayAtBottom ? s.maxY - winHeight : s.minY + (s.height - winHeight) / 2;
  hydrationWalkTarget = { x: targetX, y: targetY };
  currentAnim = 'run';
  currentFrameIndex = 0;
  animTime = 0;
  behavior.setParked(true);
}

let parkWalkTarget = null;
let isManuallyParked = false;

function parkPet() {
  if (screens.length === 0) return;
  const s = screens[0];
  parkWalkTarget = { x: s.minX + 12, y: s.maxY - winHeight };
  behavior.setParked(true);
  walkTarget = null;
  currentAnim = 'walk';
  currentFrameIndex = 0;
  animTime = 0;
  isManuallyParked = true;
}

function pokePet() {
  parkWalkTarget = null;
  behavior.setParked(false);
  isManuallyParked = false;
  currentAnim = 'idle';
}

window.parkPet = parkPet;
window.pokePet = pokePet;

let isPromptDialogOpen = false;
let promptCallback = null;

function showPromptDialog(defaultValue, callback) {
  const dialog = document.getElementById('promptDialog');
  const input = document.getElementById('promptInput');
  if (!dialog || !input) return;

  input.value = defaultValue;
  dialog.style.display = 'block';
  isPromptDialogOpen = true;
  promptCallback = callback;

  behavior.setParked(true);

  if (isElectron) {
    ipcRenderer.send('set-ignore-mouse-events', false);
  }
}

window.submitPromptDialog = () => {
  const dialog = document.getElementById('promptDialog');
  const input = document.getElementById('promptInput');
  if (dialog && input) {
    dialog.style.display = 'none';
    isPromptDialogOpen = false;
    if (!isManuallyParked) {
      behavior.setParked(false);
    }
    if (promptCallback) {
      promptCallback(input.value);
      promptCallback = null;
    }
  }
};

window.cancelPromptDialog = () => {
  const dialog = document.getElementById('promptDialog');
  if (dialog) {
    dialog.style.display = 'none';
    isPromptDialogOpen = false;
    if (!isManuallyParked) {
      behavior.setParked(false);
    }
    promptCallback = null;
  }
};

if (!isElectron && typeof Notification !== 'undefined' && Notification.requestPermission) {
  Notification.requestPermission().catch(err => {
    console.log('Notification permission request ignored or blocked', err);
  });
}

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
    isManuallyParked = false;
    behavior.enter(stateName);
  }
};

let customReminders = [];
let pendingCustomReminderMessage = null;
let isReminderDialogOpen = false;

window.formatTimeInput = (e) => {
  const input = e.target;
  const val = input.value;
  const lastLen = parseInt(input.getAttribute('data-last-len') || '0', 10);
  if (val.length > lastLen && /^\d{2}$/.test(val)) {
    input.value = val + ':';
  }
  input.setAttribute('data-last-len', val.length.toString());
};

window.showReminderDialog = () => {
  const dialog = document.getElementById('reminderDialog');
  const timeInput = document.getElementById('reminderTimeInput');
  const msgInput = document.getElementById('reminderMsgInput');
  if (dialog) {
    dialog.style.display = 'block';
    isReminderDialogOpen = true;
    behavior.setParked(true);
    walkTarget = null;
    currentAnim = 'idle';
    if (isElectron) {
      ipcRenderer.send('set-ignore-mouse-events', false);
    }
    if (timeInput) {
      timeInput.value = '';
      timeInput.setAttribute('data-last-len', '0');
      timeInput.focus();
    }
    if (msgInput) {
      msgInput.value = '';
    }
  }
};

window.submitReminderDialog = () => {
  const dialog = document.getElementById('reminderDialog');
  const timeInput = document.getElementById('reminderTimeInput');
  const msgInput = document.getElementById('reminderMsgInput');
  if (dialog && timeInput && msgInput) {
    let time = timeInput.value.trim();
    const msg = msgInput.value.trim();
    if (time && msg) {
      const parts = time.split(':');
      if (parts.length === 2) {
        const hr = parts[0].trim().padStart(2, '0');
        const min = parts[1].trim().padStart(2, '0');
        time = `${hr}:${min}`;
      }
      customReminders.push({ time, msg, triggered: false });
    }
    dialog.style.display = 'none';
    isReminderDialogOpen = false;
    if (!isManuallyParked) {
      behavior.setParked(false);
    }
  }
};

window.cancelReminderDialog = () => {
  const dialog = document.getElementById('reminderDialog');
  if (dialog) {
    dialog.style.display = 'none';
    isReminderDialogOpen = false;
    if (!isManuallyParked) {
      behavior.setParked(false);
    }
  }
};

function triggerCustomReminder(message) {
  pendingCustomReminderMessage = message;
  
  if (screens.length === 0) return;
  const s = screens[0];
  
  const targetX = s.minX + (s.width - petWidth) / 2;
  const targetY = isStayAtBottom ? s.maxY - winHeight : s.minY + (s.height - winHeight) / 2 - 100;
  
  hydrationWalkTarget = { x: targetX, y: targetY };
  behavior.setParked(true);
  currentAnim = 'run';
  currentFrameIndex = 0;
  animTime = 0;
}

let waterIntervalMinutes = 60;
let waterTimer = null;

function scheduleWaterReminder() {
  if (waterTimer) clearInterval(waterTimer);
  waterTimer = setInterval(() => {
    triggerWaterHydrationFlow();
  }, waterIntervalMinutes * 60 * 1000);
}

setInterval(() => {
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const nowStr = `${hours}:${minutes}`;
  
  customReminders.forEach(r => {
    if (!r.triggered && r.time === nowStr) {
      r.triggered = true;
      triggerCustomReminder(r.msg);
    }
  });
}, 10000);



setInterval(() => {
  if (hydrationWalkTarget || isPromptDialogOpen || isReminderDialogOpen || isDragging || isWaterReminderActive || isManuallyParked) return;
  const state = Math.random() < 0.5 ? PetState.walk : PetState.run;
  behavior.enter(state);
}, 60000);

if (isElectron) {
  ipcRenderer.on('menu-action', (event, action, data) => {
    if (action === 'idle-park') {
      parkPet();
    } else if (action === 'poke' || action === 'free') {
      pokePet();
    } else if (action === 'say') {
      showSayBubble();
    } else if (action === 'trigger-state') {
      triggerState(data);
    } else if (action === 'prompt-custom-reminder') {
      showReminderDialog();
    }
  });

  ipcRenderer.on('toggle-water-reminders', (event, enabled) => {
    if (enabled) {
      scheduleWaterReminder();
    } else {
      if (waterTimer) clearInterval(waterTimer);
      waterTimer = null;
    }
  });

  ipcRenderer.on('prompt-hydration-interval', (event) => {
    const input = document.getElementById('waterIntervalInput');
    const currentVal = input ? input.value : String(waterIntervalMinutes);
    showPromptDialog(currentVal, (result) => {
      if (result !== null) {
        const parsed = parseInt(result, 10);
        if (!isNaN(parsed)) {
          const minutes = Math.max(1, Math.min(1440, parsed));
          waterIntervalMinutes = minutes;
          if (input) input.value = String(minutes);
          
          ipcRenderer.send('update-settings', { waterIntervalMinutes: minutes });
          scheduleWaterReminder();
        }
      }
    });
  });
}

// Start Application
preloadImages(() => {
  initScreens().then(() => {
    if (isElectron) {
      const cp = document.getElementById('controlPanel');
      if (cp) cp.style.display = 'none';

      ipcRenderer.invoke('get-settings').then((settings) => {
        if (settings) {
          if (typeof settings.waterIntervalMinutes === 'number') {
            waterIntervalMinutes = settings.waterIntervalMinutes;
          }
          if (settings.waterReminders) {
            scheduleWaterReminder();
          }
          if (settings.isParked) {
            parkPet();
          }
        }
      });
    }
    requestAnimationFrame(loop);
  });
});
