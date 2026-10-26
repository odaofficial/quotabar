# QuotaBar — native panel revision, 0.2.0

## Outcome

A tiny native macOS menu utility for Codex, Claude, Cursor and Grok. The product is **QuotaBar**, independent of the hosting organization. Apply the user-selected Apple Design skill (local apple-design/SKILL.md, based on Apple's interface talks) and the earlier [macOS design skill](https://github.com/ceorkm/macos-design-skill/blob/main/SKILL.md). Translate principles to SwiftUI/AppKit, never add a web runtime. Familiar provider usage conventions, immediate feedback, restrained native typography, functional translucency, clear hierarchy, and accessibility are the priorities.

## Composition

Replace the previous dashboard of four large rounded cards and oversized remaining percentages. Use a compact, unified native usage list with subtle inset separators between provider sections. Panel 410 × 630 points, shared sizing constants. All four providers and primary windows fit in the connected sample; expanded details scroll.

- Header approximately 52 points: original context/chat stack mark, QuotaBar in 17-point semibold system type, trailing 28-point Refresh and Settings icon controls. No subtitle. Sample renders carry a small SAMPLE indicator.
- Content side inset 18 points. Each section starts with a recognizable 22-point monochrome provider logo, plan label (13-point medium, preserving spelling), and dashboard/disclosure icons. Provider name remains in help, accessibility, and Settings. A small neutral “Plan unavailable” label is acceptable only when a connected response lacks trustworthy plan metadata.
- Each quota is a full-width row: 12–13-point label on left and **9% used** on right in semibold monospaced digits; thin used-progress meter below; secondary 11-point **91% remaining** on left and clock + reset countdown on right. Two quotas stack vertically, never giant side-by-side tiles. Used progress is blue/system accent normally, accessible warning at ≥80%, red at ≥95%, with numeric labels conveying meaning independently of color.
- Claude labels are **Session limit** and **Weekly · all models**, matching provider vocabulary. Keep other provider labels tied to actual periods. Unknown usage is text with no filled bar. Tiny nonzero percentages remain nonzero in both display directions. Exact reset timestamp is available in help.
- Additional windows, extras and exact fetched time expand under their provider, preserving state. Codex's free-reset count is visible compactly when supplied. Do not combine independent quotas.
- Footer is quiet: manual check time or initial instruction, plus Quit icon. Failed refresh must visibly show stale data. Avoid duplicate captions and excessive pill badges.
- Settings has matching toolbar with Back, grouped login and provider switches, connection guidance, shortcuts and source link. Full provider names are useful here. No onboarding or unrelated controls.

## Interaction and accessibility

Native source-anchored NSPopover; system material in toolbar with readable solid content. Respect Reduce Transparency with solid chrome, Increased Contrast with defined edges and clear text, Reduce Motion with static transitions. Disclosure uses a critically damped spring (response 0.3, damping 1) only on deliberate interaction. Press feedback is immediate; hover/focus visible. No idle animation or countdown timer.

Command-R refresh, Command-comma Settings, Command-Q Quit, Escape back/dismiss, with local key monitor only while this popover is key. Remove the silent generic 30-second manual-refresh rejection: every eligible click begins refresh and provides feedback. Retain overlap exclusion and provider Retry-After/429 cooldown. A blocked provider clearly says when to retry; never promise an automatic retry.

## Accuracy

The model's percentages already mean USED. Add explicitly named used/remaining display helpers; do not invert provider values in primary labels or bar fill. Synthetic fixture: Claude 9% and 71% used => 91% and 29% remaining. Format whole values without unnecessary .0; preserve very small nonzero values with up to three decimals. Missing values never become zero.

Claude credentials already contain subscriptionType and rateLimitTier. Carry a validated optional plan label with the exact credential used to fetch usage. Recognized, consistent max + default_claude_max_20x => Max (20x); max + default_claude_max_5x => Max (5x); generic max => Max; pro => Pro. Unknown/contradictory tiers must not invent specificity. Prefer recognized credential plan over missing/generic usage plan; this metadata may lag plan changes until provider re-login. Same parser for file and Keychain; no additional network request or credential logging. Keep account-identity protections before cooldown and after response. Test plan mapping and 9/71 used semantics with synthetic credentials.

## Branding and installation

Rename package, modules, source/test paths, executable, app, app icon and all visible/public strings to QuotaBar / QuotaBarCore. Rename OdaMark to QuotaMark and draw a recognizable original overlapping context/chat icon with a subtle message tail at menu-bar scale. Use that motif for the app icon as well. Use odaofficial/quotabar for future source links and documentation. Keep provider trademarks and existing license notices.

Retain the legacy bundle identifier org.odaofficial.limits ONLY as a private compatibility detail, preserving preferences and login-item identity; document why in source. Installed target is ~/Applications/QuotaBar.app. Install script can move the old app into the new path before replacing its contents, when new path absent. One-time login-location migration must re-register an already-enabled login item at its new location, preserving explicit Off. Never leave an old running process, two menu icons or an obsolete startup target. Root handles actual install and verifies launch registration. Version 0.2.0 build 3.

## Constraints and proof

Manual-only network/credential work: startup, panel opening, wake and toggles never fetch. No recurring timers, persistent cache, extra framework dependencies, or background workers. Initial message asks for Refresh; Claude Connect remains explicit. Preserve all existing provider, retry, identity and resource-bundle protections.

Update real SwiftUI offscreen rendering at 2× with light, dark, settings, mixed, empty, expanded and initial scenarios; demo never reads credentials or changes preferences/login. Connected demo includes Max (20x), 9%/71% used. Review actual pixels before installing. Tests must cover consequential new logic, not UI structure trivia. Separate review follows stable build. Runtime keyboard/smoke probes verify the installed binary; verify zero startup checks, login status/location, installed footprint and idle CPU. Public screenshots contain only synthetic data. Remove build caches after delivery.
