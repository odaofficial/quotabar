# Changelog

## 0.2.0 — 2026-10-26

- Usage checks are now manual only. Startup, wake, and provider visibility changes stay idle; background polling and countdown timers are removed.
- Redesigned the native panel with distinct light and dark surfaces, clear remaining-limit figures, and compact rows that fit all four providers.
- Added recognizable provider logos, a context-card menu bar icon, icon controls, and grouped settings with native switches.
- Added keyboard shortcuts: ⌘R refresh, ⌘, settings, ⌘Q quit, and Escape back/dismiss.
- Additional allowances and credits expand on demand; disclosure state survives scrolling.
- Claude's explicit Keychain connection action works immediately after a failed usage check, while preserving provider retry limits.

## 0.1.0 — 2026-10-26

- Initial native menu bar app for Codex, Claude, Cursor, and Grok, using existing local sessions and supporting launch at login.
