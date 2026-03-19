# Changelog

## [1.2.0] - 2026-03-22
### Added
- **Dynamic Paths (Portability)**: Replaced all hardcoded `C:\Program Files (x86)\...` paths with dynamic resolution using `Get-SteamInstallDir`. The app now works correctly regardless of where Steam is installed.
- **Enhanced Debugging**: Added `[INFO]` and `[ERROR]` levels to logs for better diagnostic clarity.
- **Robust Import Logic**: Added full `try-catch` blocks to file deployment (Import-Files) with detailed error reporting in the console.
- **Restart Steam Feature**: Added a dedicated `Restart` button on the Home page.
- **Auto-Refresh**: Identity lists and status are now automatically updated after switching accounts or clicking restart.
- **Process Accuracy**: Expanded Steam detection to include `steamwebhelper` and `SteamService` for more accurate status reporting.
### Fixed
- Fixed typo in log message: "Siganling" -> **"Signaling"**.
- Fixed background memory leak: The UI update timer is now explicitly stopped when the application is closed.
- Improved Steam path detection by caching the result (`$script:SteamExeCache`) and using more reliable registry lookups.

## [1.1.1] - 2026-03-22
...
