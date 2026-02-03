![Demo](https://raw.githubusercontent.com/kozaaaaczx/steam-lua/main/assets/maingif.gif)

# Steam Lua

A simple tool to manage Steam and import manifest/lua files.

## Features
- Start / Stop / Restart Steam
- Import multiple files at once
  - .manifest → C:\Program Files (x86)\Steam\depotcache
  - .lua → C:\Program Files (x86)\Steam\config\stplug-in
- Dark theme, resizable window

## Download
- Latest release (portable EXE):
  - https://github.com/kozaaaaczx/steam-lua/releases

## Changelog
See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Screenshots
![Main window](https://raw.githubusercontent.com/kozaaaaczx/steam-lua/main/assets/main.png)

## Requirements
- Windows with PowerShell 5.1+
- Administrator privileges (the EXE requests admin at launch)

## Usage
### Option A: EXE (recommended)
1) Download `SteamLua.exe` from Releases.
2) Run as Administrator (UAC prompt is expected).
3) If SmartScreen appears, click “More info” → “Run anyway”.

### Option B: Run from source (scripts)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File ".\steam-lua-gui.ps1"
```
Run PowerShell as Administrator if you plan to import files to Program Files.

### What each button does
- **Start**: launches Steam if it is not running.
- **Stop**: tries graceful shutdown, then force-closes leftover Steam processes after ~12s.
- **Restart**: Stop → Start.
- **Import**: copies selected files to Steam folders (requires Administrator):
  - Select one or more `.manifest` files → copies to `C:\Program Files (x86)\Steam\depotcache`.