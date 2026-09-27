# Disc Cursor

A minimalist, high-contrast Windows cursor scheme with disc geometry, static (`.cur`) and animated (`.ani`) files, and automated setup scripts.

---

## Preview Gallery

| Preview | State / Role | Cursor File | Description |
| :---: | :--- | :--- | :--- |
| ![Normal Select](png/disc-normal.png) | **Normal Select** | `disc-normal.cur` | Primary pointer |
| ![Help Select](png/disc-help.png) | **Help Select** | `disc-help.cur` | Contextual help |
| ![Working in Background](gif/disc-working.gif) | **Working in Background** | `disc-working.ani` | Background processing |
| ![Busy](gif/disc-busy.gif) | **Busy** | `disc-busy.ani` | System busy |
| ![Precision Select](png/disc-precision.png) | **Precision Select** | `disc-precision.cur` | Pixel-accurate crosshair |
| ![Text Select](png/disc-text.png) | **Text Select** | `disc-text.cur` | Text insertion (I-beam) |
| ![Handwriting](png/disc-handwriting.png) | **Handwriting** | `disc-handwriting.cur` | Pen and stylus input |
| ![Unavailable](png/disc-unavailable.png) | **Unavailable** | `disc-unavailable.cur` | Blocked or disabled actions |
| ![Vertical Resize](png/disc-vertical.png) | **Vertical Resize** | `disc-vertical.cur` | Up/down window sizing |
| ![Horizontal Resize](png/disc-horizontal.png) | **Horizontal Resize** | `disc-horizontal.cur` | Left/right window sizing |
| ![Diagonal Resize 1](png/disc-diagonal1.png) | **Diagonal Resize 1** | `disc-diagonal1.cur` | NW-to-SE window sizing |
| ![Diagonal Resize 2](png/disc-diagonal2.png) | **Diagonal Resize 2** | `disc-diagonal2.cur` | NE-to-SW window sizing |
| ![Move](png/disc-move.png) | **Move** | `disc-move.cur` | Four-directional movement |
| ![Alternate Select](png/disc-alternate.png) | **Alternate Select** | `disc-alternate.cur` | Secondary directional selection |
| ![Link Select](png/disc-link.png) | **Link Select** | `disc-link.cur` | Hyperlink pointer |
| ![Person Select](png/disc-person.png) | **Person Select** | `disc-person.cur` | People and contact tags |
| ![Location Select](png/disc-location.png) | **Location Select** | `disc-location.cur` | Map pins and locations |

---

## Features

- **Full Coverage**: Includes all 15 standard Windows cursor roles plus Windows 10/11 Person and Location selectors.
- **Fluid Animations**: Smooth disc spinners for background and busy states.
- **PowerShell Installer**: Registers the scheme and refreshes the shell in one command without rebooting.
- **Clean Uninstaller**: Restores default cursors and removes scheme assets.

---

## Installation

### Option 1: Download from Latest Release (Recommended)

1. Download the `.zip` from **[Releases](https://github.com/minzelli/disc-cursor/releases/latest)**.
2. Extract the archive.
3. Open PowerShell inside the extracted folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

*(Or right-click `install.ps1` and select **Run with PowerShell**).*

---

### Option 2: Clone with Git

Clone and install in one step:

```powershell
git clone https://github.com/minzelli/disc-cursor.git
cd disc-cursor
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### What the Installer Does

1. Verifies cursor assets against an internal manifest.
2. Copies cursors to `%LOCALAPPDATA%\Disc_Cursor_Scheme\cursor`.
3. Registers the `"Disc"` scheme under `HKCU:\Control Panel\Cursors\Schemes`.
4. Sets the active cursor scheme under `HKCU:\Control Panel\Cursors`.
5. Invokes `SPI_SETCURSORS` via `user32.dll` to apply changes immediately.

---

## Uninstallation

To restore defaults and remove assets, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\remove.ps1
```

### What the Uninstaller Does

1. Removes the `"Disc"` scheme from `HKCU:\Control Panel\Cursors\Schemes`.
2. Restores default cursors under `HKCU:\Control Panel\Cursors`.
3. Deletes `%LOCALAPPDATA%\Disc_Cursor_Scheme`.
4. Invokes `SPI_SETCURSORS` via `user32.dll` to apply changes immediately.

---

## Requirements

- **Operating System**: Windows 10/11
- **PowerShell**: Windows PowerShell 5.1 or PowerShell 7+

---

## License

This project is dedicated to the public domain under [Creative Commons Zero v1.0 Universal (CC0 1.0)](LICENSE). You may copy, modify, distribute, and perform the work, including commercially, without permission or attribution.