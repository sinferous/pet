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
  sleep: 'sleep',
  drink: 'drink',
  play: 'play',
  react: 'react',
  follow: 'follow',
  laugh: 'laugh',
  jump: 'jump'
};

const PetAnimation = {
  idle: 'idle',
  walk: 'walk',
  sleep: 'sleep',
  drink: 'drink',
  play: 'play',
  react: 'react',
  follow: 'follow',
  laugh: 'laugh',
  jump: 'jump'
};

class BehaviorMachine {
  constructor({
    clock = () => Date.now() / 1000.0,
    rollChance = () => Math.random(),
    idleDecisionDelay = () => 20 + Math.random() * 40, // 20...60s
    sleepAfterIdle = () => 90 + Math.random() * 60      // 90...150s
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

    this.cursorInRange = false;
    this.dragging = false;
  }

  setCursor(inRange) {
    this.cursorInRange = inRange;
    if (inRange && (this.state === PetState.idle || this.state === PetState.walk)) {
      this.enter(PetState.follow);
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
    if (this.state === PetState.walk) {
      this.enter(PetState.idle);
    }
  }

  tick() {
    const t = this.clock();

    // Expire finite-duration states
    switch (this.state) {
      case PetState.react:
      case PetState.drink:
      case PetState.sleep:
      case PetState.follow:
        if (t >= this.stateUntil) {
          this.enter(PetState.idle);
        }
        break;
      case PetState.walk:
        if (t >= this.walkDeadline) {
          this.enter(PetState.idle); // safety deadline
        }
        break;
    }

    // Decide new activity if idle/play/laugh expired
    if ((this.state === PetState.idle || this.state === PetState.play || this.state === PetState.laugh) && t >= this.nextDecisionTime) {
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
    if (roll < 0.55) {
      this.enter(PetState.walk);
    } else if (roll < 0.70) {
      this.enter(PetState.play);
    } else if (roll < 0.80) {
      this.enter(PetState.laugh);
    } else if (roll < 0.90) {
      this.enter(PetState.jump);
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
      case PetState.drink:
        this.stateUntil = t + 6.0;
        break;
      case PetState.sleep:
        this.stateUntil = t + (20 + Math.random() * 20); // 20...40s
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

  pickTarget(screens, margin = 40) {
    if (screens.length === 0) return null;
    const index = Math.floor(Math.random() * screens.length);
    const screen = screens[index];
    const inset = Math.min(margin, screen.width / 3);
    let x;
    if (screen.width <= inset * 2) {
      x = screen.centerX;
    } else {
      x = screen.minX + inset + Math.random() * (screen.width - inset * 2);
    }
    // Floor of screen is maxY on Windows (top-left origin)
    return {
      screenIndex: index,
      x: x,
      y: screen.maxY - 60 // window height is 60
    };
  },

  step(currentX, currentY, facing, speed, screens, petWidth = 128, petHeight = 120) {
    // Find containing screen (using midpoint vertically)
    const screen = screens.find(s => s.contains(currentX + petWidth / 2, currentY + petHeight / 2));
    if (!screen) {
      return { x: currentX, y: currentY, facing: facing, crossedScreen: false };
    }

    let x = currentX + (facing === 'right' ? speed : -speed);
    let y = currentY;
    let resultFacing = facing;
    let crossed = false;

    if (facing === 'right' && x >= screen.maxX - petWidth) {
      const next = this.adjacentScreen('right', screen, screens);
      if (next) {
        x = next.minX;
        // Keep the exact same height y when crossing screens
        y = currentY;
        crossed = true;
      } else {
        x = screen.maxX - petWidth - 0.1;
        resultFacing = 'left';
      }
    } else if (facing === 'left' && x <= screen.minX) {
      const next = this.adjacentScreen('left', screen, screens);
      if (next) {
        x = next.maxX - petWidth - 0.1;
        // Keep the exact same height y when crossing screens
        y = currentY;
        crossed = true;
      } else {
        x = screen.minX + 0.1;
        resultFacing = 'right';
      }
    }

    return { x: x, y: y, facing: resultFacing, crossedScreen: crossed };
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
