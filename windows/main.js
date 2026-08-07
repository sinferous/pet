const { app, BrowserWindow, ipcMain, screen } = require('electron');
const path = require('path');

// Disable hardware acceleration before ready to avoid visual glitches with transparency
app.disableHardwareAcceleration();

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 128,
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
  const initialX = Math.round(primaryDisplay.bounds.x + (width - 128) / 2);
  const initialY = Math.round(primaryDisplay.bounds.y + height - 320);
  mainWindow.setBounds({ x: initialX, y: initialY, width: 128, height: 320 });

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
        width: 128,
        height: 320
      });
    }
  });

  ipcMain.handle('get-cursor-position', () => {
    const point = screen.getCursorScreenPoint();
    return { x: point.x, y: point.y };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();

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
