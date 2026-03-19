# Changelog

## [1.3.0] - 2026-03-22
### Added
- **Production Caching**: Steam paths (`Get-SteamInstallDir`) are now queried once and cached (`$script:SteamDirCache`), eliminating redundant registry checks and improving performance.
- **Action Blocking (Anti-spam)**: Critical actions like Start, Stop, and Switch Account now disable their respective buttons during operation to prevent multi-click bugs and race conditions.
- **User Feedback**: Added explicit confirmation logs after successful operations (e.g., "Account switch completed.").
- **Early Filtering**: Drag & Drop now filters files *before* attempting processing, immediately discarding non `.lua` or `.manifest` files.
### Fixed
- Fixed silent path failures: Quick Access buttons (Depot, Config, etc.) now check `Test-Path` before launching, logging a clean error instead of failing silently.
- Fixed log prefixes: Refined the `Write-Log` regex (`^(Error|FAILED)`) to prevent accidental false-positives for message formatting.
- Fixed potential timing issue on Account Switch by ensuring a clean full stop before starting with the new identity.

## [1.2.0] - 2026-03-22
...
