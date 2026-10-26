# Native panel redesign — 0.2.0

## Intent and constraints

Make Oda Limits feel like a carefully made macOS menu bar utility. The user's selected [macOS design skill](https://github.com/ceorkm/macos-design-skill/blob/main/SKILL.md) supplies the visual and interaction principles. Apply the patterns relevant to a small read-only utility: system typography, native material, progressive disclosure, accessible controls, keyboard shortcuts, and independently considered light/dark surfaces. Search, drag-and-drop, fake window chrome, and onboarding flows do not help four subscription summaries.

Keep native SwiftUI/AppKit, macOS 14+, zero dependencies, authentication, startup registration, provider contracts, and all account-switch/backoff protections. Usage is fetched only when the user presses Refresh or explicitly connects Claude; opening the app, waking the Mac, and switching providers never fetch. No countdown or polling timer runs in the background. No network or credential access in demo rendering. No continuous animations. Honor Reduce Motion and Increase Contrast using semantic colors and system materials.

## Composition

- Panel: 420 × 660 points, a native popover with system material around solid readable content. Shared dimension constants keep host, view, and renderer aligned.
- Header: a small original menu-context mark, 20-point semibold Oda Limits title, 12-point secondary subtitle. Trailing 28-point icon buttons for Refresh and Settings with hover/pressed/focus feedback and tooltip shortcut hints. Refresh spinner appears only while fetching. A modest SAMPLE badge distinguishes synthetic renders.
- Content: 16-point side padding, 8-point gaps, four provider sections. All four providers must fit in the default synthetic summary at 660 points; additional detail scrolls. Use small recognizable provider marks, 13-point semibold names, subdued plan labels, a dashboard button, and a disclosure chevron. No large accent backgrounds.
- Allowances: first two independent quota windows appear side by side, with label, a 22-point monospaced-digit remaining percentage, a thin system-accent progress track, and an 11-point reset countdown. Single-window providers use the width well without oversized percentages. Never combine independent quotas. Unknown is text without a filled meter; zero remaining remains zero. Low remaining can use semantic warning color plus text, never color alone.
- Details: per-provider chevron expands other windows, all extras in wrapping/full-width label-value rows, exact update time, and any additional account information already supplied. A compact available-reset summary for Codex remains in its default card when provided. Preserve full values in accessibility/help. Expanded content must scroll and not truncate extras.
- State: before the first check, cards say “Click Refresh to check usage.” Login/error copy must be actionable and readable; retained data is explicitly Stale. Staleness must remain visible when detail is collapsed. Preserve Claude's Connect action. Empty enabled-provider list explains how to choose providers with a Settings action.
- Footer: subdued check time and manual-refresh status on left, compact icon Quit on right with shortcut tooltip. Do not suggest successful freshness based solely on a failed check. Demo says Sample data.
- Settings replaces the content with a cohesive native page: matching header/back control, grouped launch-at-login row, grouped four provider switches, concise per-provider connection help, keyboard hints, and source link. Use actual confirmed login status; demo never changes system settings.

## Behavior and implementation

Keep sources in Sources/OdaLimits; reusable tiny styling components may live in a new NativeStyle.swift. Core provider code is outside this slice. Use 4/8/12/16/24 spacing, 8-point cards and 6-point controls, subtle 0.5-point edges, semantic foreground and system accent. Use system native vibrancy for real popovers and deterministic opaque backdrops for offscreen preview. Do not add decorative blur to text surfaces.

Add working local shortcuts while the popover is key: Command-R refresh, Command-comma Settings, Command-Q Quit, Escape returns from Settings or dismisses the popover. Give controls accessibility labels, tooltips, and standard focus behavior. Short 150–250 ms disclosure/settings transitions only, disabled under Reduce Motion. Do not install global key monitors.

Extend synthetic CLI rendering with --appearance light|dark, --settings, --scenario mixed|empty|expanded|initial (default remains connected sample). Mixed must exercise unknown quota, stale data, and missing login; initial shows the first-open manual-refresh prompt. Rendering must not read disk credentials and should produce an opaque 2× PNG of the actual SwiftUI content, not a mockup. Version 0.2.0 (bundle build 2).

## Verification and delivery

1. Build/test existing Swift package and package a signed local app. Add behavior tests only for new nontrivial pure logic, not visual implementation details.
2. Inspect actual rendered light, dark, settings, mixed, empty, and expanded panels. Default must show all four providers and all reset countdowns without clipping. No authentic account data in screenshots.
3. Separate code review examines data preservation, shortcut lifecycle, accessibility, preview isolation, and performance regressions; builder fixes material findings.
4. Install and run the rebuilt app; confirm menu item/hosting view/startup status via runtime probes. Measure installed size and idle CPU/RSS. Target ≤2 MiB installed, idle CPU approximately 0%, no added persistent wakeups.
5. Publish reviewed source and 0.2.0 release in odaofficial/oda-limits; retain concise verification notes, preview, and design-source attribution. Clean task build caches after delivery.

Commands: `swift test`, `./Scripts/package.sh`, `.build/release/OdaLimits --render-demo /tmp/oda-limits-light.png --appearance light`, `.build/release/OdaLimits --demo --smoke-test`.
