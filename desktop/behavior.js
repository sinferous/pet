// Port of DesktopPetCore's BehaviorMachine, ScreenNavigator, and ScreenRect to JavaScript

class ScreenRect {
  constructor(minX, minY, width, height) {
    this.minX = minX;
    this.minY = minY;
    this.width = width;
    this.height = height;
  }

  get maxX() { return this.minX + this.width; }
  get maxY() { return this.minY + this.height; }
  get centerX() { return this.minX + this.width / 2; }

  contains(x, y) {
    return x >= this.minX && x < this.maxX && y >= this.minY && y < this.maxY;
  }
}

const PetState = {
  idle: 'idle',
  walk: 'walk',
  run: 'run',
  sleep: 'sleep',
  drink: 'drink',
  play: 'play',
  react: 'react',
  follow: 'follow',
  laugh: 'laugh',
  jump: 'jump',
  roll: 'roll',
  woolball: 'woolball',
  cheer: 'cheer',
  love: 'love',
  anger: 'anger'
};

const PetAnimation = {
  idle: 'idle',
  walk: 'walk',
  run: 'run',
  sleep: 'sleep',
  drink: 'drink',
  play: 'play',
  react: 'react',
  follow: 'follow',
  laugh: 'laugh',
  jump: 'jump',
  roll: 'roll',
  woolball: 'woolball',
  cheer: 'cheer',
  love: 'love',
  anger: 'anger'
};

class BehaviorMachine {
  constructor({
    clock = () => Date.now() / 1000.0,
    rollChance = () => Math.random(),
    idleDecisionDelay = () => 5 + Math.random() * 10,   // 5...15s — max 20s in one place
    sleepAfterIdle = () => 30 + Math.random() * 30      // 30...60s
  } = {}) {
    this.clock = clock;
    this.rollChance = rollChance;
    this.idleDecisionDelay = idleDecisionDelay;
    this.sleepAfterIdle = sleepAfterIdle;

    this.onStateChange = null;
    this.state = PetState.idle;

    const t = this.clock();
    this.nextDecisionTime = t + this.idleDecisionDelay();
    this.nextSleepTime = t + this.sleepAfterIdle();
    this.stateUntil = 0;
    this.walkDeadline = 0;
    this.runDeadline = 0;
    this.rollDeadline = 0;
    this.woolballDeadline = 0;
    this.cheerDeadline = 0;
    this.loveDeadline = 0;

    this.cursorInRange = false;
    this.dragging = false;
    this.parked = false;
  }

  // Parked mode: the cat stays put (idle, no walking/running/following/sleeping).
  // Used by the "Idle (Park)" control; "Poke" turns it back off.
  setParked(value) {
    if (this.parked === value) return;
    this.parked = value;
    if (value) {
      this.enter(PetState.idle);
    } else {
      this.nextDecisionTime = 0; // resume: decide on the very next tick
    }
  }

  setCursor(inRange) {
    if (this.parked) return;
    this.cursorInRange = inRange;
    if (inRange && (this.state === PetState.idle || this.state === PetState.walk || this.state === PetState.run)) {
      if (this.rollChance() < 0.30) {
        this.enter(PetState.follow);
      }
    } else if (!inRange && this.state === PetState.follow) {
      this.enter(PetState.idle);
    }
  }

  handleClick() {
    if (this.state === PetState.sleep) {
      this.enter(PetState.react); // wake up
    } else if (this.state !== PetState.drink) {
      this.enter(PetState.react);
    }
  }

  handleDragStart() {
    this.dragging = true;
    if (this.state !== PetState.sleep) {
      this.enter(PetState.react);
    }
  }

  handleDragEnd() {
    this.dragging = false;
    this.enter(PetState.idle);
  }

  startWaterDrink() {
    this.enter(PetState.drink);
  }

  completeWalk() {
    if (this.state === PetState.walk || this.state === PetState.run) {
      this.enter(PetState.idle);
    }
  }

  tick() {
    const t = this.clock();
    if (this.parked) return; // parked: no activity decisions, no sleep, stays idle

    // Expire finite-duration states
    switch (this.state) {
      case PetState.react:
      case PetState.sleep:
      case PetState.follow:
      case PetState.laugh:
      case PetState.jump:
      case PetState.anger:
        if (t >= this.stateUntil) {
          this.enter(PetState.idle);
        }
        break;
      case PetState.walk:
        if (t >= this.walkDeadline) {
          this.enter(PetState.idle); // safety deadline
        }
        break;
      case PetState.run:
        if (t >= this.runDeadline) {
          this.enter(PetState.idle); // safety deadline
        }
        break;
      case PetState.roll:
        if (t >= this.rollDeadline) {
          this.enter(PetState.idle); // safety deadline
        }
        break;
      case PetState.woolball:
        if (t >= this.woolballDeadline) {
          this.enter(PetState.idle); // safety deadline
        }
        break;
      case PetState.cheer:
        if (t >= this.cheerDeadline) {
          this.enter(PetState.idle); // safety deadline
        }
        break;
      case PetState.love:
        if (t >= this.loveDeadline) {
          this.enter(PetState.idle); // safety deadline
        }
        break;
    }

    // Decide new activity if idle/play expired (laugh/jump expire via stateUntil)
    if ((this.state === PetState.idle || this.state === PetState.play) && t >= this.nextDecisionTime) {
      this.decideActivity(t);
    }

    // Idle long enough -> sleep
    if (this.state === PetState.idle && t >= this.nextSleepTime) {
      this.enter(PetState.sleep);
    }
  }

  decideActivity(t) {
    this.nextDecisionTime = t + this.idleDecisionDelay();
    const roll = this.rollChance();
    if (this.state === PetState.play || this.state === PetState.laugh || this.state === PetState.jump) {
      this.enter(PetState.idle);
      return;
    }
    // All 13 activities distributed more evenly
    if (roll < 0.10) {
      this.enter(PetState.walk);
    } else if (roll < 0.18) {
      this.enter(PetState.run);
    } else if (roll < 0.26) {
      this.enter(PetState.play);
    } else if (roll < 0.34) {
      this.enter(PetState.laugh);
    } else if (roll < 0.42) {
      this.enter(PetState.jump);
    } else if (roll < 0.49) {
      this.enter(PetState.roll);
    } else if (roll < 0.56) {
      this.enter(PetState.woolball);
    } else if (roll < 0.63) {
      this.enter(PetState.cheer);
    } else if (roll < 0.70) {
      this.enter(PetState.love);
    } else if (roll < 0.76) {
      this.enter(PetState.sleep);
    } else if (roll < 0.82) {
      this.enter(PetState.react);
    } else if (roll < 0.89) {
      this.enter(PetState.follow);
    } else {
      this.enter(PetState.idle);
    }
  }

  enter(newState) {
    if (newState === this.state) return;
    const t = this.clock();
    switch (newState) {
      case PetState.react:
        this.stateUntil = t + 2.5;
        break;
      case PetState.anger:
        this.stateUntil = t + 4.0;
        break;
      case PetState.drink:
        this.stateUntil = t + 6.0;
        break;
      case PetState.sleep:
        this.stateUntil = t + (10 + Math.random() * 10);  // 10...20s
        break;
      case PetState.follow:
        this.stateUntil = t + 10.0;
        break;
      case PetState.play:
        this.stateUntil = t + (5 + Math.random() * 4); // 5...9s
        break;
      case PetState.laugh:
        this.stateUntil = t + (3 + Math.random() * 2); // 3...5s
        break;
      case PetState.jump:
        this.stateUntil = t + (3 + Math.random() * 2); // 3...5s
        break;
      case PetState.walk:
        this.walkDeadline = t + (10 + Math.random() * 15); // 10...25s
        break;
      case PetState.run:
        this.runDeadline = t + (5 + Math.random() * 10); // 5...15s
        break;
      case PetState.roll:
        this.rollDeadline = t + (4 + Math.random() * 3); // 4...7s
        break;
      case PetState.woolball:
        this.woolballDeadline = t + (5 + Math.random() * 3); // 5...8s
        break;
      case PetState.cheer:
        this.cheerDeadline = t + (3 + Math.random() * 2); // 3...5s
        break;
      case PetState.love:
        this.loveDeadline = t + (4 + Math.random() * 2); // 4...6s
        break;
      case PetState.idle:
        this.nextDecisionTime = t + this.idleDecisionDelay();
        this.nextSleepTime = t + this.sleepAfterIdle();
        break;
    }
    this.state = newState;
    if (this.onStateChange) {
      this.onStateChange(newState);
    }
  }
}

const ScreenNavigator = {
  adjacencyTolerance: 4.0,

  pickTarget(screens, margin = 40, winWidth = 128, winHeight = 120, headroom = 0, stayAtBottom = false) {
    if (screens.length === 0) return null;
    const index = Math.floor(Math.random() * screens.length);
    const screen = screens[index];
    const insetX = Math.min(margin, screen.width / 4);
    const insetY = Math.min(margin, screen.height / 4);
    const rangeX = screen.width - insetX * 2 - winWidth;
    const rangeY = screen.height - insetY * 2 - winHeight + headroom;
    const x = rangeX > 0 ? screen.minX + insetX + Math.random() * rangeX : screen.centerX;
    let y = rangeY > 0 ? screen.minY - headroom + insetY + Math.random() * rangeY : screen.minY - headroom;
    if (stayAtBottom) {
      y = screen.maxY - winHeight;
    }
    return {
      screenIndex: index,
      x: x,
      y: y
    };
  },

  step(currentX, currentY, targetX, targetY, speed, screens, winWidth = 128, winHeight = 120, headroom = 0) {
    // Find containing screen by the CAT's center (the cat always stays on-screen,
    // even when the window's effects headroom extends above the display top).
    const screen = screens.find(s => s.contains(currentX + winWidth / 2, currentY + (winHeight + headroom) / 2));
    if (!screen) {
      return { x: currentX, y: currentY, facing: 'right', crossedScreen: false };
    }

    // Step at `speed` toward the target — diagonal when the target is off-axis.
    const dx = targetX - currentX;
    const dy = targetY - currentY;
    const len = Math.hypot(dx, dy);
    let x = currentX;
    let y = currentY;
    if (len > 0) {
      const s = Math.min(speed, len);
      x += (dx / len) * s;
      y += (dy / len) * s;
    }
    let facing = dx >= 0 ? 'right' : 'left';
    let crossed = false;

    // Horizontal screen edge → cross to an adjacent display, else stop & turn.
    if (x <= screen.minX) {
      const next = this.adjacentScreen('left', screen, screens);
      if (next) {
        x = next.maxX - winWidth;
        crossed = true;
      } else {
        x = screen.minX + 0.1;
        facing = 'right';
      }
    } else if (x >= screen.maxX - winWidth) {
      const next = this.adjacentScreen('right', screen, screens);
      if (next) {
        x = next.minX;
        crossed = true;
      } else {
        x = screen.maxX - winWidth - 0.1;
        facing = 'left';
      }
    }

    // Vertical edges → clamp the CAT to the display. The window may rise off the
    // top by `headroom` (the effects zone); the cat (headroom lower) stays inside.
    y = Math.max(screen.minY - headroom, Math.min(screen.maxY - winHeight, y));

    return { x: x, y: y, facing: facing, crossedScreen: crossed };
  },

  adjacentScreen(direction, screen, screens) {
    if (direction === 'right') {
      const candidates = screens.filter(s => Math.abs(s.minX - screen.maxX) <= this.adjacencyTolerance);
      if (candidates.length === 0) return null;
      return candidates.sort((a, b) => a.minX - b.minX)[0];
    } else {
      const candidates = screens.filter(s => Math.abs(s.maxX - screen.minX) <= this.adjacencyTolerance);
      if (candidates.length === 0) return null;
      return candidates.sort((a, b) => b.maxX - a.maxX)[0];
    }
  }
};

if (typeof module === 'object' && module !== null && typeof module.exports === 'object') {
  module.exports = {
    ScreenRect,
    PetState,
    PetAnimation,
    BehaviorMachine,
    ScreenNavigator
  };
} else {
  window.ScreenRect = ScreenRect;
  window.PetState = PetState;
  window.PetAnimation = PetAnimation;
  window.BehaviorMachine = BehaviorMachine;
  window.ScreenNavigator = ScreenNavigator;
}
