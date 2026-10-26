# Verification — QuotaBar 0.2.0

Verified on Apple silicon, macOS 26.5, Swift 6.3.3. Measurements are short local samples, not guarantees across Macs or provider responses.

- **30 synthetic behavior tests pass.** Coverage includes provider response contracts, missing/malformed data, credential expiry and selection, used/remaining percentages and tiny nonzero values, currency units, retry bounds, and account changes. New fixtures cover Claude Max 5x/20x, generic and contradictory metadata, and 9%/71% used versus 91%/29% remaining.
- Independent review approved code at `d3c2d411`, including plan metadata tied to the fetch credential, used-progress semantics, effective 429 retry times, first-check failure versus stale data, typed Keychain permission actions, login migration, resource packaging, and local keyboard-monitor lifetime.
- Release packaging and `codesign --verify --strict` pass for the packaged and installed app. Version 0.2.0, build 3; `LSUIElement` remains true. The installed app contains only the QuotaBar executable, with no obsolete executable or icon left by the rename.
- Installed startup probe: `launch=ok statusItem=ok hostingView=ok size=410x630 checks=0 login=On`. Startup makes no usage checks. Source review confirms no polling/countdown timers or startup/wake/provider-toggle fetches.
- Installed app-owned keyboard probe: `anchor=true shown=true window=true appActive=true keyWindow=true settings=true escapeBack=true escapeDismiss=true`. It sends synthetic events through AppKit to the actual local monitor, with sample data and no provider requests.
- Actual SwiftUI views were rendered as opaque 820×1260 PNGs and inspected in light, dark, settings, mixed/stale/unknown/zero, initial, empty, expanded, first-check failure, and Keychain-permission states. All four providers and primary reset times fit in the connected summary. [Light](images/usage-light.png), [dark](images/usage-dark.png), and [settings](images/settings.png) previews contain only synthetic data. Offscreen native switches can render inactive gray; their on/off knob positions remain visible.
- Installed footprint: **1,388 KiB (about 1.4 MiB)**. Cold idle panel-closed samples reported **0.0% CPU**, about **39.5 MiB RSS**, and **11.2 MiB physical footprint** (11.7 MiB peak reported by macOS `sample`). No TCP sockets were open. Opening the panel and fetching usage may increase memory; these figures do not mean zero memory or permanent zero CPU.
- Launch-at-login remains On through `SMAppService`; macOS background-task registration points to `QuotaBar.app`. The old installed app path is gone. The original bundle identifier is intentionally retained to preserve preferences and registration identity. No logout/reboot was performed.

## Live provider check

An explicit, one-off diagnostic check of the installed build returned live Codex, Claude and Cursor usage. Claude correctly reported Max (20x), with session and all-model weekly usage. It required no additional request for plan metadata. Grok did not have a working local sign-in and remains fixture-tested. No authentic quota values, account identities, credentials or live screenshots are saved in this repository.

The application does not repeat that diagnostic on startup or in the background. Routine checks require the user's Refresh or Connect action.

## Reproduce

```sh
swift test
./Scripts/package.sh
./Scripts/install.sh
"$HOME/Applications/QuotaBar.app/Contents/MacOS/QuotaBar" --smoke-test
"$HOME/Applications/QuotaBar.app/Contents/MacOS/QuotaBar" --interaction-smoke-test
.build/release/QuotaBar --render-demo /tmp/quotabar-light.png --appearance light
.build/release/QuotaBar --render-demo /tmp/quotabar-dark.png --appearance dark
.build/release/QuotaBar --render-demo /tmp/quotabar-settings.png --settings
.build/release/QuotaBar --render-demo /tmp/quotabar-mixed.png --scenario mixed
.build/release/QuotaBar --render-demo /tmp/quotabar-expanded.png --scenario expanded
.build/release/QuotaBar --render-demo /tmp/quotabar-initial.png --scenario initial
.build/release/QuotaBar --render-demo /tmp/quotabar-failed.png --scenario failed
.build/release/QuotaBar --render-demo /tmp/quotabar-keychain.png --scenario keychain
```

A normal installed smoke test can register launch at login, like a normal launch, but never fetches usage. Add `--demo` to avoid system preference changes. The interaction probe always uses demo data. `--diagnostics` explicitly performs live provider checks without Keychain prompts or raw response logging.

## Boundaries and implementation notes

Native desktop automation timed out earlier in this task. Native rendering and the app-owned probe cover layout, startup, focus, Settings and Escape; they do not establish end-to-end mouse or VoiceOver coverage of every control.

`NSApplication.delegate` is weak: keep it alive for `app.run()`. Defer initial popover display until the status item attaches to its window. Keep the event monitor local to this key popover and remove it on close. Initialize disclosure state once so scrolling does not reset it.

The first installed `SMAppService` status may be `.notFound`; register it on first launch. On rename, re-register an already-enabled login item at the new location without turning an explicit Off back on. Retain a migration marker if registration fails so a later launch can retry. Replacing bundle Contents during installation avoids old executable/resource files surviving a directory merge.

Provider usage endpoints are undocumented contracts. Missing values stay unknown and unrecognized responses are rejected. Claude plan metadata can lag subscription changes until the provider refreshes the local sign-in. Explicit manual checks still respect 429 cooldowns, and the displayed retry time matches the actual enforced cooldown.

The GitHub workflow uses the standard Intel macOS 15 runner after ARM jobs failed to acquire runners. AppKit image caches are main-actor isolated so both the older CI SDK and the local SDK compile without suppressing concurrency checks. Local runtime verification covers Apple silicon.
