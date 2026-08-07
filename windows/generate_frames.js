const fs = require('fs');
const path = require('path');

// 1. Read Cat.svg
const catPath = path.join(__dirname, '..', 'Pet model', 'Cat.svg');
const catContent = fs.readFileSync(catPath, 'utf8');

// Parse paths
const lines = catContent.split('\n');
const bodyPaths = [];
let blackTailBacking = '';
let whiteTail = '';

for (let line of lines) {
  line = line.trim();
  if (!line) continue;

  if (line.includes('<path') || line.includes('<circle') || line.includes('<ellipse') || line.includes('<g>') || line.includes('</g>')) {
    if (line.includes('M215.14')) {
      // Path 1 (black tail backing)
      blackTailBacking = line;
    } else if (line.includes('M144.84') || line.includes('M140.84')) {
      // Path 2 (white tail highlight)
      whiteTail = line;
    } else {
      bodyPaths.push(line);
    }
  }
}

// 2. Correct eye covers and closed eye arcs for the robot cat
const leftEyeCover = `<rect x="113" y="178" width="14" height="24" fill="#010101" />`;
const rightEyeCover = `<rect x="173" y="178" width="14" height="24" fill="#010101" />`;

const leftEyeHappy = `<path d="M 113 191 Q 120 183, 127 191" stroke="#81bec9" stroke-width="3.5" fill="none" stroke-linecap="round" />`;
const rightEyeHappy = `<path d="M 173 191 Q 180 183, 187 191" stroke="#81bec9" stroke-width="3.5" fill="none" stroke-linecap="round" />`;

const leftEyeClosed = `<path d="M 113 189 Q 120 197, 127 189" stroke="#81bec9" stroke-width="3.5" fill="none" stroke-linecap="round" />`;
const rightEyeClosed = `<path d="M 173 189 Q 180 197, 187 189" stroke="#81bec9" stroke-width="3.5" fill="none" stroke-linecap="round" />`;

// Heart-shaped eyes for the LOVE frames (drawn over the black eye covers)
const leftEyeHeart = `<path d="M 120 179 C 120 174, 114 174, 114 179 C 114 185, 119 189, 120 192 C 121 189, 126 185, 126 179 C 126 174, 120 174, 120 179 Z" fill="#81bec9" stroke="#010101" stroke-width="2.5" />`;
const rightEyeHeart = `<path d="M 180 179 C 180 174, 174 174, 174 179 C 174 185, 179 189, 180 192 C 181 189, 186 185, 186 179 C 186 174, 180 174, 180 179 Z" fill="#81bec9" stroke="#010101" stroke-width="2.5" />`;

const leftCheekExtra = `<circle cx="100" cy="195" r="14" fill="#dc5a88" opacity="0.6" />`;
const rightCheekExtra = `<circle cx="200" cy="195" r="14" fill="#dc5a88" opacity="0.6" />`;

// Laughing mouth overlays
const mouthCover = `<rect x="135" y="196" width="28" height="26" fill="#010101" />`;
const mouthLaughWide = `<path d="M 134 200 Q 150 216, 166 200 Z" fill="#81bec9" stroke="#010101" stroke-width="2.5" stroke-linecap="round" />`;
const mouthLaughMedium = `<path d="M 136 202 Q 150 212, 164 202 Z" fill="#81bec9" stroke="#010101" stroke-width="2.5" stroke-linecap="round" />`;

// Teardrop overlays for laughter
const leftTearSmall = `<path d="M 108 186 Q 102 182, 104 188 Q 106 190, 108 186 Z" fill="#81bec9" stroke="#010101" stroke-width="2" />`;
const leftTearMedium = `<path d="M 106 184 Q 96 177, 99 187 Q 102 191, 106 184 Z" fill="#81bec9" stroke="#010101" stroke-width="2" />`;
const leftTearLarge = `<path d="M 104 182 Q 90 172, 94 186 Q 98 192, 104 182 Z" fill="#81bec9" stroke="#010101" stroke-width="2" />`;

const rightTearSmall = `<path d="M 192 186 Q 198 182, 196 188 Q 194 190, 192 186 Z" fill="#81bec9" stroke="#010101" stroke-width="2" />`;
const rightTearMedium = `<path d="M 194 184 Q 204 177, 201 187 Q 198 191, 194 184 Z" fill="#81bec9" stroke="#010101" stroke-width="2" />`;
const rightTearLarge = `<path d="M 196 182 Q 210 172, 206 186 Q 202 192, 196 182 Z" fill="#81bec9" stroke="#010101" stroke-width="2" />`;

const waterBottle = `
  <g id="bottle">
    <rect x="220" y="160" width="22" height="42" rx="6" fill="#81bec9" stroke="#010101" stroke-width="3" />
    <rect x="227" y="152" width="8" height="8" fill="#fefefe" stroke="#010101" stroke-width="2.5" />
    <path d="M 221.5 180 L 240.5 180 L 240.5 198 Q 231 202, 221.5 198 Z" fill="#2a9d8f" opacity="0.5" />
  </g>
`;

// Helper to wrap the SVG content
function makeSVG(innerContent) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 300" width="300" height="300">
${innerContent}
</svg>`;
}

// Map of all 26 frames
const framesConfig = {
  // IDLE: 4 frames
  'idle/0': { mainTransform: '', transform: '', tailAngle: 0 },
  'idle/1': { mainTransform: 'translate(0, -6)', transform: '', tailAngle: 6 },
  'idle/2': { mainTransform: '', transform: '', tailAngle: 0 },
  'idle/3': { mainTransform: 'translate(0, -6)', transform: '', tailAngle: -6, overlays: leftEyeCover + rightEyeCover + leftEyeClosed + rightEyeClosed },

  // WALK: 4 frames
  'walk/0': { mainTransform: '', transform: '', tailAngle: -5 },
  'walk/1': { mainTransform: 'translate(0, -8) rotate(-4 150 220)', transform: '', tailAngle: 8 },
  'walk/2': { mainTransform: '', transform: '', tailAngle: -5 },
  'walk/3': { mainTransform: 'translate(0, -8) rotate(4 150 220)', transform: '', tailAngle: 8 },

  // SLEEP: 2 frames
  'sleep/0': {
    mainTransform: 'translate(0, 30) rotate(4 150 220)',
    transform: 'scale(1.05, 0.8)',
    tailAngle: -22,
    overlays: leftEyeCover + rightEyeCover + leftEyeClosed + rightEyeClosed
  },
  'sleep/1': {
    mainTransform: 'translate(0, 25) rotate(4 150 220)',
    transform: 'scale(1.05, 0.82)',
    tailAngle: -24,
    overlays: leftEyeCover + rightEyeCover + leftEyeClosed + rightEyeClosed
  },

  // PLAY: 3 frames (squash/stretch inside SVG - window coordinates handle the jump)
  'play/0': {
    mainTransform: '',
    transform: 'scale(1.06, 0.9)',
    tailAngle: -10,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy
  },
  'play/1': {
    mainTransform: '',
    transform: 'scale(0.95, 1.05)',
    tailAngle: 18,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy
  },
  'play/2': {
    mainTransform: '',
    transform: '',
    tailAngle: 0,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy
  },

  // REACT: 2 frames
  'react/0': {
    mainTransform: '',
    transform: '',
    tailAngle: 10,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy + leftCheekExtra + rightCheekExtra
  },
  'react/1': {
    mainTransform: 'translate(0, -15)',
    transform: '',
    tailAngle: -10,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy + leftCheekExtra + rightCheekExtra
  },

  // DRINK: 4 frames
  'drink/0': {
    mainTransform: '',
    transform: '',
    tailAngle: -5,
    bgOverlays: waterBottle
  },
  'drink/1': {
    mainTransform: '',
    transform: '',
    tailAngle: 0,
    bgOverlays: `
      <g transform="translate(-30, -25) rotate(-20 230 180)">
        ${waterBottle}
      </g>
    `
  },
  'drink/2': {
    mainTransform: 'rotate(-6 150 220)',
    transform: '',
    tailAngle: 8,
    bgOverlays: `
      <g transform="translate(-70, -50) rotate(-60 230 180)">
        ${waterBottle}
      </g>
    `,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy
  },
  'drink/3': {
    mainTransform: '',
    transform: '',
    tailAngle: 0,
    bgOverlays: `
      <g transform="translate(-10, -5) rotate(-5 230 180)">
        ${waterBottle}
      </g>
    `
  },

  // LAUGH: 3 frames
  'laugh/0': {
    mainTransform: 'translate(0, -12)',
    transform: 'scale(0.95, 1.05)',
    tailAngle: 15,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy + mouthCover + mouthLaughWide + leftTearSmall + rightTearSmall
  },
  'laugh/1': {
    mainTransform: '',
    transform: 'scale(1.05, 0.95)',
    tailAngle: -10,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy + mouthCover + mouthLaughMedium + leftTearLarge + rightTearLarge
  },
  'laugh/2': {
    mainTransform: 'translate(0, -8)',
    transform: 'scale(0.98, 1.02)',
    tailAngle: 10,
    overlays: leftEyeCover + rightEyeCover + leftEyeHappy + rightEyeHappy + mouthCover + mouthLaughWide + leftTearMedium + rightTearMedium
  },

  // JUMP: 4 frames
  'jump/0': {
    mainTransform: '',
    transform: 'scale(1.1, 0.85)',
    tailAngle: 0
  },
  'jump/1': {
    mainTransform: '',
    transform: 'scale(0.9, 1.15)',
    tailAngle: 0
  },
  'jump/2': {
    mainTransform: '',
    transform: 'scale(1.15, 0.85)',
    tailAngle: 0
  },
  'jump/3': {
    mainTransform: '',
    transform: '',
    tailAngle: 0
  },

  // RUN: 4 frames — lean forward, squash/stretch gait, streaming tail.
  'run/0': {
    mainTransform: '',
    transform: 'rotate(-6 150 220) scale(1.05, 0.9)',
    tailAngle: -18
  },
  'run/1': {
    mainTransform: 'translate(0, -10)',
    transform: 'rotate(-4 150 220) scale(0.96, 1.07)',
    tailAngle: 6
  },
  'run/2': {
    mainTransform: '',
    transform: 'rotate(-6 150 220) scale(1.05, 0.9)',
    tailAngle: -18
  },
  'run/3': {
    mainTransform: 'translate(0, -10)',
    transform: 'rotate(-4 150 220) scale(0.96, 1.07)',
    tailAngle: 6
  },

  // ROLL: 4 frames — the cat tumbles end-over-end (90° rotation steps about the
  // middle of the viewBox, so the whole cat+tail stays in frame).
  'roll/0': {
    mainTransform: '',
    transform: 'scale(1.05, 0.9)',
    tailAngle: -6
  },
  'roll/1': {
    mainTransform: 'rotate(90 150 150)',
    transform: 'scale(1.05, 0.9)',
    tailAngle: 0
  },
  'roll/2': {
    mainTransform: 'rotate(180 150 150)',
    transform: '',
    tailAngle: 0
  },
  'roll/3': {
    mainTransform: 'rotate(-90 150 150)',
    transform: 'scale(0.95, 1.05)',
    tailAngle: 0
  },

  // LOVE: 3 frames — heart-shaped eyes + blush, gentle bob.
  'love/0': {
    mainTransform: '',
    transform: '',
    tailAngle: 5,
    overlays: leftEyeCover + rightEyeCover + leftEyeHeart + rightEyeHeart + leftCheekExtra + rightCheekExtra
  },
  'love/1': {
    mainTransform: 'translate(0, -6)',
    transform: '',
    tailAngle: -5,
    overlays: leftEyeCover + rightEyeCover + leftEyeHeart + rightEyeHeart + leftCheekExtra + rightCheekExtra
  },
  'love/2': {
    mainTransform: '',
    transform: '',
    tailAngle: 5,
    overlays: leftEyeCover + rightEyeCover + leftEyeHeart + rightEyeHeart + leftCheekExtra + rightCheekExtra
  }
};

// 3. Generate all frames
for (const [frameKey, config] of Object.entries(framesConfig)) {
  const mainTransform = config.mainTransform ? ` transform="${config.mainTransform}"` : '';
  const transform = config.transform ? ` transform="${config.transform}"` : '';
  const tailAngle = config.tailAngle || 0;
  const overlays = config.overlays || '';
  const bgOverlays = config.bgOverlays || '';

  // Render tail group with rotation centered at base (180, 85)
  const tailGroup = `
    <g transform="rotate(${tailAngle} 180 85)">
      ${blackTailBacking}
      ${whiteTail}
    </g>
  `;

  // Combined frame structure: tail and body are wrapped together under mainTransform
  const frameContent = makeSVG(`
    <g${mainTransform}>
      ${tailGroup}
      <g${transform}>
        ${bodyPaths.join('\n')}
        ${overlays}
      </g>
    </g>
    ${bgOverlays}
  `);

  // Write to windows/artwork/
  const winDestPath = path.join(__dirname, 'artwork', `${frameKey}.svg`);
  fs.mkdirSync(path.dirname(winDestPath), { recursive: true });
  fs.writeFileSync(winDestPath, frameContent, 'utf8');

  // Write to Resources/Artwork/
  const macDestPath = path.join(__dirname, '..', 'Resources', 'Artwork', `${frameKey}.svg`);
  fs.mkdirSync(path.dirname(macDestPath), { recursive: true });
  fs.writeFileSync(macDestPath, frameContent, 'utf8');
}

console.log(`Successfully generated ${Object.keys(framesConfig).length} animated frames for screen-space playing!`);
