const { app, BrowserWindow, ipcMain, screen, Tray, Menu, powerSaveBlocker, nativeImage, dialog } = require('electron');
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
  isParked: false,
  isHidden: false,
  stayAtBottom: false
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
  if (!app.isPackaged) {
    // In development mode, do not register startup to avoid polluting local startup directories.
    try {
      app.setLoginItemSettings({
        openAtLogin: false,
        ...(process.platform === 'win32' ? {
          path: app.getPath('exe'),
          args: [path.resolve(app.getAppPath())]
        } : {})
      });
    } catch (e) {
      console.error('Failed to clean up development autostart setting:', e);
    }
    return;
  }

  if (process.platform === 'win32') {
    const startupPath = process.env.PORTABLE_EXECUTABLE_FILE || app.getPath('exe');
    app.setLoginItemSettings({
      openAtLogin: settings.autoStart,
      path: startupPath
    });
  } else if (process.platform === 'linux') {
    app.setLoginItemSettings({
      openAtLogin: settings.autoStart
    });
  }
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
    type: process.platform === 'linux' ? 'utility' : undefined,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile('index.html');
  if (settings.isHidden) {
    mainWindow.hide();
  }

  let isDraggingLocal = false;
  let isMenuOpen = false;

  ipcMain.on('set-dragging', (event, dragging) => {
    isDraggingLocal = dragging;
    if (dragging && mainWindow) {
      mainWindow.setIgnoreMouseEvents(false);
    }
  });

  // Linux-only global mouse polling to support transparent click-through
  // (since { forward: true } option of setIgnoreMouseEvents is macOS/Windows only).
  if (process.platform === 'linux') {
    setInterval(() => {
      if (!mainWindow || mainWindow.isDestroyed()) return;
      if (isDraggingLocal || isMenuOpen) return;

      let cursor = screen.getCursorScreenPoint();
      
      // On Linux, adjust cursor position if scale factor is present
      if (process.platform === 'linux') {
        const primaryDisplay = screen.getPrimaryDisplay();
        const scale = primaryDisplay.scaleFactor || 1;
        if (scale !== 1) {
          cursor.x = Math.round(cursor.x / scale);
          cursor.y = Math.round(cursor.y / scale);
        }
      }

      const bounds = mainWindow.getBounds();
      
      const inside = (
        cursor.x >= bounds.x &&
        cursor.x < bounds.x + bounds.width &&
        cursor.y >= bounds.y &&
        cursor.y < bounds.y + bounds.height
      );
      
      if (inside) {
        const x = cursor.x - bounds.x;
        const y = cursor.y - bounds.y;
        mainWindow.webContents.send('check-mouse-position', { x, y });
      } else {
        mainWindow.setIgnoreMouseEvents(true);
      }
    }, 50);
  }

  // Align to center of the primary screen initially
  const primaryDisplay = screen.getPrimaryDisplay();
  const { width, height } = primaryDisplay.workAreaSize;
  const initialX = Math.round(primaryDisplay.bounds.x + (width - 256) / 2);
  const initialY = Math.round(primaryDisplay.bounds.y + (height - 320) / 2 - 100);
  mainWindow.setBounds({ x: initialX, y: initialY, width: 256, height: 320 });

  // Handle transparent click-through
  ipcMain.on('set-ignore-mouse-events', (event, ignore, options) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (win) {
      if (process.platform === 'linux') {
        win.setIgnoreMouseEvents(ignore);
      } else {
        win.setIgnoreMouseEvents(ignore, options);
      }
    }
  });

  ipcMain.handle('get-screens', () => {
    return screen.getAllDisplays().map(display => ({
      x: display.workArea.x,
      y: display.workArea.y,
      width: display.workArea.width,
      height: display.workArea.height
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
    isMenuOpen = true;
    if (mainWindow) {
      mainWindow.setIgnoreMouseEvents(false);
    }
    const contextMenu = Menu.buildFromTemplate(getMenuTemplate());
    const win = BrowserWindow.fromWebContents(event.sender);
    if (win) {
      contextMenu.popup({
        window: win,
        callback: () => {
          isMenuOpen = false;
        }
      });
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
      label: 'Set Custom Reminder…',
      click: () => {
        sendToRenderer('menu-action', 'prompt-custom-reminder');
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
      label: 'Stay at Bottom',
      type: 'checkbox',
      checked: settings.stayAtBottom,
      click: (item) => {
        settings.stayAtBottom = item.checked;
        saveSettings();
        sendToRenderer('update-settings', { stayAtBottom: item.checked });
        updateTrayMenu();
      }
    },
    {
      label: 'Idle / Free',
      type: 'checkbox',
      checked: settings.isParked,
      click: (item) => {
        settings.isParked = item.checked;
        saveSettings();
        sendToRenderer('menu-action', item.checked ? 'idle-park' : 'free');
        updateTrayMenu();
      }
    },
    {
      label: 'Hide/Seek',
      type: 'checkbox',
      checked: settings.isHidden,
      click: (item) => {
        settings.isHidden = item.checked;
        saveSettings();
        if (item.checked) {
          if (mainWindow) mainWindow.hide();
        } else {
          if (mainWindow) mainWindow.show();
        }
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
        { label: 'Love', click: () => triggerMovement('love') },
        { label: 'Anger', click: () => triggerMovement('anger') }
      ]
    },
    { type: 'separator' },
    {
      label: 'Quit Luna',
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
  tray.setToolTip('Luna');
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

// Helper to warn user if running from temporary directories
function checkRunningFromTemp() {
  if (process.platform !== 'win32') return; // Temp execution check is Windows-specific
  if (!app.isPackaged) return; // ignore in development mode
  
  const startupPath = process.env.PORTABLE_EXECUTABLE_FILE || app.getPath('exe');
  const tempPath = app.getPath('temp');
  
  if (
    startupPath.toLowerCase().includes(tempPath.toLowerCase()) || 
    startupPath.toLowerCase().includes('appdata\\local\\temp')
  ) {
    dialog.showMessageBox({
      type: 'warning',
      title: 'Luna - Temporary Location Warning',
      message: 'Running from a Temporary Folder',
      detail: 'Luna is currently running from a temporary location (this usually happens if you open it directly from a ZIP file).\n\nThe "Start at Login" feature will NOT work after a restart because temporary files are deleted by Windows.\n\nTo resolve this:\n1. Copy/move the application file to a permanent folder (like your Desktop, Documents, or local programs folder).\n2. Run the application from that permanent location.',
      buttons: ['OK']
    });
  }
}

// App Lifecycle
app.whenReady().then(() => {
  loadSettings();
  applySleepPrevention();
  applyAutoStart();
  createWindow();
  createTray();
  checkRunningFromTemp();

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
