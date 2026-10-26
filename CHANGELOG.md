# Changelog

## 0.2.0 — 2026-10-26

- Renamed the app and source modules to QuotaBar. Existing preferences and launch-at-login identity are preserved during upgrade.
- Usage checks are now manual only. Startup, wake, and provider visibility changes stay idle; background polling and countdown timers are removed.
- Redesigned the native panel as a compact usage list: each allowance leads with the provider's used percentage and shows remaining percentage and reset time below.
- Claude's Max (20x) or Max (5x) plan is read from its existing credential metadata when available.
- Added recognizable provider logos, an original context/chat menu and app icon, icon controls, and grouped settings with native switches.
- Added keyboard shortcuts: ⌘R refresh, ⌘, settings, ⌘Q quit, and Escape back/dismiss.
- Additional allowances and credits expand on demand; disclosure state survives scrolling.
- Claude's explicit Keychain connection action works immediately after a failed usage check, while preserving provider retry limits.

## 0.1.0 — 2026-10-26

- Initial native menu bar app for Codex, Claude, Cursor, and Grok, using existing local sessions and supporting launch at login.
