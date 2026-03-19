# Steam Lua Manager

A simple, graphical tool written in PowerShell to manage Steam execution and quickly import manifest and Lua script files.

## Features

- **Steam Management**: Quickly **Start**, **Stop**, or **Restart** your Steam client. Includes options for a graceful shutdown (with customizable wait time) and forcing close if Steam hangs.
- **File Import**: 
  - Import `.manifest` files seamlessly to the Steam `depotcache` directory (`C:\Program Files (x86)\Steam\depotcache`).
  - Import `.lua` scripts directly to the Steam `stplug-in` directory (`C:\Program Files (x86)\Steam\config\stplug-in`).
- **Auto-Detection**: Automatically locates your `steam.exe` installation via Registry keys and fallback common directories. Custom paths can also be browsed manually.
- **Quick Actions**: Handy shortcuts to open commonly used Steam directories (`depotcache`, `config`, `stplug-in`), copy the Steam path, or save the action log.
- **Always on top**: Option to keep the manager window above all other applications.

## Requirements

- Windows PowerShell 5.1 or later.
- Steam installed on your machine.

## How to Use

### Using the GUI
The easiest way to use this tool is via the graphical user interface.
1. Right-click on `steam-lua-gui.ps1`.
2. Select **Run with PowerShell**.
3. Use the interface to perform imports or restart Steam.

### Using the Command Line
If you prefer a headless operation or want to integrate it into other scripts, you can use the core script `steam-lua.ps1`.
```powershell
# Allowed actions: Start, Stop, Restart
.\steam-lua.ps1 -Action "Restart"
```

## Troubleshooting & Permissions

If you receive an error about scripts being disabled on your system, you need to update your PowerShell Execution Policy. Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Changelog

For recent changes and updates, please refer to the [CHANGELOG.md](CHANGELOG.md) file.

## License

This project is licensed under the terms described in the [LICENSE](LICENSE) file.
