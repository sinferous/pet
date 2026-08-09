const canvas = document.getElementById('petCanvas');
const ctx = canvas.getContext('2d');
const container = document.getElementById('petContainer');

// Sizing
const petWidth = 128;
const petHeight = 120;

// Setup animations config
const animations = {
  idle: 4,
  walk: 4,
  sleep: 2,
  drink: 4,
  play: 3,
  react: 2,
  laugh: 3,
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
      img.onload = onLoadOrError;
      img.onerror = (err) => {
        console.error(`Failed to load frame: artwork/${anim}/${i}.svg`, err);
        onLoadOrError();
      };
      img.src = `artwork/${anim}/${i}.svg`;
      images[anim].push(img);
    }
  }
}

// State
const behavior = new BehaviorMachine();

let suppressAngerBubble = false;

behavior.onStateChange = (state) => {
  currentAnim = state;
  currentFrameIndex = 0;
  animTime = 0;

  if (state === PetState.walk) {
    startWalk();
  } else if (state === PetState.drink) {
    triggerSpeechBubble("💧 Gulp gulp! Hydration time!", 4000);
    if (window.Android) window.Android.triggerHapticFeedback();
  } else if (state === PetState.anger) {
    if (!suppressAngerBubble) {
      const messages = ["💢 Grrr! Stop slacking!", "💢 Focus, human!", "💢 Doomscrolling detected!", "💢 Don't ignore me!"];
      const randomMsg = messages[Math.floor(Math.random() * messages.length)];
      triggerSpeechBubble(randomMsg, 4000);
    }
    suppressAngerBubble = false; // Reset flag
    if (window.Android) window.Android.triggerHapticFeedback();
  }
};
let screens = [];
let facing = 'right';
let walkTarget = null;
const walkSpeed = 1.2;

let windowX = 0;
let windowY = 0;
let isDragging = false;

const animationFps = {
  idle: 2,
  walk: 5,
  sleep: 1.2,
  drink: 3,
  play: 4,
  react: 3,
  laugh: 4,
  roll: 6,
  love: 3,
  anger: 4
};

let currentAnim = 'idle';
let currentFrameIndex = 0;
let lastTime = 0;
let animTime = 0;
let bubbleTimeout = null;

// Speech bubble
function triggerSpeechBubble(text, duration = 3000) {
  const bubble = document.getElementById('speechBubble');
  const bubbleText = document.getElementById('speechBubbleText');
  if (bubble && bubbleText) {
    bubbleText.textContent = text;
    bubble.style.display = 'block';
    if (bubbleTimeout) clearTimeout(bubbleTimeout);
    bubbleTimeout = setTimeout(() => {
      bubble.style.display = 'none';
      if (behavior.state === PetState.anger) {
        behavior.enter(PetState.idle);
      }
    }, duration);
  }
}

// Android integration hooks
window.onInitScreen = function(w, h, x, y) {
  screens = [new ScreenRect(0, 0, w, h)];
  windowX = x;
  windowY = y;
  
  preloadImages(() => {
    lastTime = performance.now();
    requestAnimationFrame(loop);
    triggerSpeechBubble("Meow! I'm here! 🐾", 3000);
  });
};

window.onDragEnd = function(x, y) {
  windowX = x;
  windowY = y;
  isDragging = false;
  behavior.handleDragEnd();
};

window.onAppChanged = function(appName) {
  console.log("App changed: " + appName);
  const isLauncher = appName.toLowerCase().includes("launcher") || 
                     appName.toLowerCase().includes("home") || 
                     appName.toLowerCase().includes("system");

  if (appName === "Instagram" || appName === "TikTok" || appName === "YouTube" || appName === "Facebook") {
    triggerSpeechBubble("💧 We were just here... " + appName + " again? 👀", 4000);
    behavior.enter(PetState.react);
    if (window.Android) window.Android.triggerHapticFeedback();
  } else if (appName === "Browser") {
    triggerSpeechBubble("💧 Still searching the web, human?", 4500);
    behavior.enter(PetState.idle);
  } else if (appName !== "Luna" && appName !== "Luna Mobile" && !isLauncher) {
    triggerSpeechBubble("💧 Opened " + appName + " 🐾", 3000);
  }
};

let currentScrollingSession = { appName: '', duration: 0 };
let alertedThresholds = {
  observe20m: false,
  react40m: false,
  intervene60m: false
};

window.onScrollDurationUpdate = function(appName, durationSeconds) {
  if (!appName) {
    currentScrollingSession = { appName: '', duration: 0 };
    alertedThresholds = { observe20m: false, react40m: false, intervene60m: false };
    if (behavior.parked) {
      behavior.setParked(false);
    }
    return;
  }
  
  currentScrollingSession = { appName, duration: durationSeconds };
  
  if (durationSeconds >= 3600) {
    if (!alertedThresholds.intervene60m) {
      alertedThresholds.intervene60m = true;
      const messages60m = [
        "We've been here for a while...",
        "An entire hour wasted... screen time is through the roof! 📈",
        "We've been scrolling for 60 minutes. Seriously, close the app. 📴",
        "One hour of doomscrolling. Your brain needs real air, human! 🧠",
        "60 minutes in the void. Let's reclaim our day now! 🌟"
      ];
      const randomMsg = messages60m[Math.floor(Math.random() * messages60m.length)];
      triggerSpeechBubble(randomMsg, 5000);
      suppressAngerBubble = true;
      behavior.setParked(true, PetState.anger);
      if (window.Android) window.Android.triggerHapticFeedback();
    }
  } else if (durationSeconds >= 2400) {
    if (!alertedThresholds.react40m) {
      alertedThresholds.react40m = true;
      const sassyMessages = [
        "Are we actually looking for something? 💅",
        "Still scrolling... I don't think the next post is going to save us. 🙄",
        "You're still here? Aren't we busy today? 💋",
        "40 minutes? Wow, the feed must be *so* intellectual today. 😹",
        "Still scrolling? Is this your career now? 💼",
        "40 minutes of swiping. Your thumb must be getting a great workout. 🏋️",
        "Are you waiting for a trophy at the end of the feed? 🏆"
      ];
      const randomSassy = sassyMessages[Math.floor(Math.random() * sassyMessages.length)];
      triggerSpeechBubble(randomSassy, 5000);
      suppressAngerBubble = true;
      behavior.setParked(true, PetState.anger);
      if (window.Android) window.Android.triggerHapticFeedback();
    }
  } else if (durationSeconds >= 1200) {
    if (!alertedThresholds.observe20m) {
      alertedThresholds.observe20m = true;
      const messages20m = [
        "💢 It's been 20 minutes... already? 👀",
        "💢 20 minutes of scrolling... time to take a break! 🛑",
        "💢 That's 20 minutes gone forever. Look up! 🙄",
        "💢 Hey, it's been 20 minutes. Don't fall into the scroll trap! 🕸️",
        "💢 20 minutes already! Let's do something else. 🚶"
      ];
      const randomMsg20m = messages20m[Math.floor(Math.random() * messages20m.length)];
      triggerSpeechBubble(randomMsg20m, 5000);
      suppressAngerBubble = true;
      behavior.setParked(true, PetState.anger);
      if (window.Android) window.Android.triggerHapticFeedback();
    }
  }
};

function updateWindowBounds() {
  let clampedY = windowY;
  if (clampedY < 160) clampedY = 160;
  if (window.Android) {
    window.Android.setWindowBounds(windowX, clampedY);
  } else {
    container.style.left = `${windowX}px`;
    container.style.top = `${clampedY}px`;
  }
}

function startWalk() {
  if (screens.length === 0) return;
  walkTarget = ScreenNavigator.pickTarget(screens);
}

function advanceWalk() {
  if (!walkTarget) return;

  const step = ScreenNavigator.step(windowX, windowY, walkTarget.x, walkTarget.y, walkSpeed, screens, petWidth, petHeight);
  facing = step.facing;
  windowX = step.x;
  windowY = step.y;
  updateWindowBounds();

  if (Math.abs(windowX - walkTarget.x) < walkSpeed * 2) {
    walkTarget = null;
    behavior.completeWalk();
  }
}

// Main Loop
function loop(now) {
  const dt = (now - lastTime) / 1000.0;
  lastTime = now;

  if (isDragging) {
    requestAnimationFrame(loop);
    return;
  }

  behavior.tick();

  if (behavior.state === PetState.walk) {
    advanceWalk();
  }

  // Force face right if resting at the left border so the cat looks at the screen content
  if (behavior.state !== PetState.walk && windowX <= 5) {
    facing = 'right';
  }

  // Animate
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

    if (img) {
      ctx.drawImage(img, 0, 0, petWidth, petHeight);
    }
    ctx.restore();
  }

  requestAnimationFrame(loop);
}

window.triggerState = (stateName) => {
  console.log("Manually triggering state: " + stateName);
  behavior.enter(stateName);
};

// Randomly trigger actions every 45s (limited to supported border actions)
setInterval(() => {
  if (isDragging || behavior.parked) return;
  const nextActions = [PetState.walk, PetState.play, PetState.laugh, PetState.roll];
  const choice = nextActions[Math.floor(Math.random() * nextActions.length)];
  behavior.enter(choice);
}, 45000);
