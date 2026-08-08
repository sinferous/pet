const { app, BrowserWindow, ipcMain, screen, Tray, Menu, powerSaveBlocker, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');

// Disable hardware acceleration before ready to avoid visual glitches with transparency
app.disableHardwareAcceleration();

let mainWindow;
let tray = null;

// Settings persistence
const settingsPath = path.join(app.getPath('userData'), 'settings.json');
let settings = {
  sleepPrevention: true,
  waterReminders: true,
  waterIntervalMinutes: 60,
  autoStart: true,
  isParked: false
};

function loadSettings() {
  try {
    if (fs.existsSync(settingsPath)) {
      const data = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
      settings = { ...settings, ...data };
    }
  } catch (e) {
    console.error('Failed to load settings', e);
  }
}

function saveSettings() {
  try {
    fs.writeFileSync(settingsPath, JSON.stringify(settings), 'utf8');
  } catch (e) {
    console.error('Failed to save settings', e);
  }
}

// Power save blocker
let sleepBlockerId = null;
function applySleepPrevention() {
  if (settings.sleepPrevention) {
    if (sleepBlockerId === null) {
      sleepBlockerId = powerSaveBlocker.start('prevent-display-sleep');
    }
  } else {
    if (sleepBlockerId !== null) {
      powerSaveBlocker.stop(sleepBlockerId);
      sleepBlockerId = null;
    }
  }
}

// Auto-start login item
function applyAutoStart() {
  app.setLoginItemSettings({
    openAtLogin: settings.autoStart,
    path: app.getPath('exe')
  });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 256,
    height: 320,
    transparent: true,
    frame: false,
    resizable: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    hasShadow: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile('index.html');

  // Align to bottom-center of the primary screen initially
  const primaryDisplay = screen.getPrimaryDisplay();
  const { width, height } = primaryDisplay.workAreaSize;
  const initialX = Math.round(primaryDisplay.bounds.x + (width - 256) / 2);
  const initialY = Math.round(primaryDisplay.bounds.y + height - 320);
  mainWindow.setBounds({ x: initialX, y: initialY, width: 256, height: 320 });

  // Handle transparent click-through
  ipcMain.on('set-ignore-mouse-events', (event, ignore, options) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (win) {
      win.setIgnoreMouseEvents(ignore, options);
    }
  });

  ipcMain.handle('get-screens', () => {
    return screen.getAllDisplays().map(display => ({
      x: display.bounds.x,
      y: display.bounds.y,
      width: display.bounds.width,
      height: display.bounds.height
    }));
  });

  ipcMain.on('set-window-bounds', (event, bounds) => {
    if (mainWindow) {
      mainWindow.setBounds({
        x: Math.round(bounds.x),
        y: Math.round(bounds.y),
        width: 256,
        height: 320
      });
    }
  });

  ipcMain.on('show-context-menu', (event) => {
    const contextMenu = Menu.buildFromTemplate(getMenuTemplate());
    const win = BrowserWindow.fromWebContents(event.sender);
    if (win) {
      contextMenu.popup({ window: win });
    }
  });

  ipcMain.on('set-tray-icon', (event, dataUrl) => {
    const img = nativeImage.createFromDataURL(dataUrl);
    createTray(img);
  });

  ipcMain.handle('get-cursor-position', () => {
    const point = screen.getCursorScreenPoint();
    return { x: point.x, y: point.y };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function getMenuTemplate() {
  return [
    {
      label: 'Prevent Sleep',
      type: 'checkbox',
      checked: settings.sleepPrevention,
      click: (item) => {
        settings.sleepPrevention = item.checked;
        saveSettings();
        applySleepPrevention();
      }
    },
    {
      label: 'Water Reminders',
      type: 'checkbox',
      checked: settings.waterReminders,
      click: (item) => {
        settings.waterReminders = item.checked;
        saveSettings();
        sendToRenderer('toggle-water-reminders', item.checked);
      }
    },
    {
      label: `Hydration Interval… (${settings.waterIntervalMinutes} min)`,
      click: () => {
        sendToRenderer('prompt-hydration-interval');
      }
    },
    {
      label: 'Start at Login',
      type: 'checkbox',
      checked: settings.autoStart,
      click: (item) => {
        settings.autoStart = item.checked;
        saveSettings();
        applyAutoStart();
      }
    },
    { type: 'separator' },
    {
      label: 'Idle (Park)',
      type: 'checkbox',
      checked: settings.isParked,
      click: (item) => {
        settings.isParked = item.checked;
        saveSettings();
        sendToRenderer('menu-action', item.checked ? 'idle-park' : 'poke');
        updateTrayMenu();
      }
    },
    {
      label: 'Poke',
      click: () => {
        settings.isParked = false;
        saveSettings();
        sendToRenderer('menu-action', 'poke');
        updateTrayMenu();
      }
    },
    {
      label: 'Say',
      click: () => {
        sendToRenderer('menu-action', 'say');
      }
    },
    {
      label: 'Movements',
      submenu: [
        { label: 'Idle', click: () => triggerMovement('idle') },
        { label: 'Walk', click: () => triggerMovement('walk') },
        { label: 'Sleep', click: () => triggerMovement('sleep') },
        { label: 'Play', click: () => triggerMovement('play') },
        { label: 'React (Shy)', click: () => triggerMovement('react') },
        { label: 'Drink (Water)', click: () => triggerMovement('drink') },
        { label: 'Laugh (Tears)', click: () => triggerMovement('laugh') },
        { label: 'Jump (Hops)', click: () => triggerMovement('jump') },
        { label: 'Run', click: () => triggerMovement('run') },
        { label: 'Roll', click: () => triggerMovement('roll') },
        { label: 'Wool Ball', click: () => triggerMovement('woolball') },
        { label: 'Cheer', click: () => triggerMovement('cheer') },
        { label: 'Love', click: () => triggerMovement('love') }
      ]
    },
    { type: 'separator' },
    {
      label: 'Quit Desktop Pet',
      click: () => {
        app.quit();
      }
    }
  ];
}

// Tray Menu creation & updating
function createTray(iconImage) {
  if (tray) {
    if (iconImage) {
      tray.setImage(iconImage);
    }
    return;
  }
  const icon = iconImage || nativeImage.createEmpty();
  tray = new Tray(icon);
  tray.setToolTip('Desktop Pet');
  updateTrayMenu();
}

function updateTrayMenu() {
  if (!tray) return;
  const contextMenu = Menu.buildFromTemplate(getMenuTemplate());
  tray.setContextMenu(contextMenu);
}

function triggerMovement(stateName) {
  settings.isParked = false;
  saveSettings();
  sendToRenderer('menu-action', 'trigger-state', stateName);
  updateTrayMenu();
}

function sendToRenderer(channel, ...args) {
  if (mainWindow && mainWindow.webContents) {
    mainWindow.webContents.send(channel, ...args);
  }
}

// IPC Handlers for Settings synchronization
ipcMain.handle('get-settings', () => {
  return settings;
});

ipcMain.on('update-settings', (event, newSettings) => {
  settings = { ...settings, ...newSettings };
  saveSettings();
  applySleepPrevention();
  applyAutoStart();
  updateTrayMenu();
});

// App Lifecycle
app.whenReady().then(() => {
  loadSettings();
  applySleepPrevention();
  applyAutoStart();
  createWindow();
  createTray();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
