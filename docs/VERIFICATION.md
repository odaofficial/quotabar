# Verification — v0.2.0

Verified on Apple silicon, macOS 26.5, Swift 6.3.3. Measurements are short local samples, not guarantees across all Macs or provider responses.

- 27 synthetic behavior tests pass, covering provider JSON contracts, malformed/unknown responses, credential selection and expiry, percentages/currency units, retry bounds, and account-change state. The provider parser/client sources are unchanged in this release.
- Independent code review approved implementation commit `6f3ef18`, including manual-only fetching, connection throttling, disclosure state, accessibility labels, keyboard monitor lifetime, and asset packaging.
- Release packaging succeeds. `codesign --verify --strict` passes for both the packaged and installed ad hoc signed app; version is 0.2.0, build 2, and `LSUIElement` remains true.
- Installed lifecycle probe reports `launch=ok statusItem=ok hostingView=ok size=420x660 checks=0 login=On`. Normal startup creates no usage checks. Source inspection confirms there are no polling/countdown timers or startup/wake/provider-toggle fetch calls.
- Installed app-owned keyboard probe reports `anchor=true shown=true window=true appActive=true keyWindow=true settings=true escapeBack=true escapeDismiss=true`. It delivers synthetic events through AppKit to the actual local monitor. It uses sample data and makes no usage requests.
- Native SwiftUI views were rendered as opaque 840×1320 PNGs and visually inspected in light, dark, settings, mixed error/unknown/zero, empty, expanded-details, and initial manual-refresh states. All four providers and their main reset times fit in the default summary. See [light](images/usage-light.png), [dark](images/usage-dark.png), and [settings](images/settings.png) previews; all contain synthetic data.
- The packaged app rendered provider logos with its SwiftPM build resource bundle temporarily unavailable, confirming the installed assets are self-contained. License notices ship in the bundle.
- Installed app: 1,564 KiB (about 1.5 MiB). Cold idle samples with the panel closed reported 0.0% CPU and 39.5–42.1 MiB RSS. macOS `sample` reported an 11.7 MiB physical footprint (11.9 MiB peak), excluding shared resident pages. No TCP sockets were open in the idle sample. Opening the panel and checking usage can increase memory use; the figures are not a claim of zero memory or permanent zero CPU.
- Native desktop automation could not inspect the app because the tool timed out. Native renders and the app-owned keyboard probe cover layout, startup, key-window focus, Settings, and Escape; they do not claim end-to-end mouse/VoiceOver verification of every control.
- Launch-at-login status was checked through `SMAppService`; no logout/reboot was performed. Existing preference choices are preserved.

## Provider integration evidence

The v0.1.0 live checks returned real Codex, Claude, and Cursor usage through existing local sessions. This visual/manual-refresh release did not repeat live provider requests automatically. Grok remains fixture-tested; a working Grok CLI login is needed for a live result. No account identities, authentic quotas, or credentials are stored in this repository.

## Reproduce

```sh
swift test
./Scripts/package.sh
./Scripts/install.sh
"$HOME/Applications/Oda Limits.app/Contents/MacOS/OdaLimits" --smoke-test
"$HOME/Applications/Oda Limits.app/Contents/MacOS/OdaLimits" --interaction-smoke-test
.build/release/OdaLimits --render-demo /tmp/oda-limits-light.png --appearance light
.build/release/OdaLimits --render-demo /tmp/oda-limits-dark.png --appearance dark
.build/release/OdaLimits --render-demo /tmp/oda-limits-settings.png --settings
.build/release/OdaLimits --render-demo /tmp/oda-limits-mixed.png --scenario mixed
.build/release/OdaLimits --render-demo /tmp/oda-limits-expanded.png --scenario expanded
.build/release/OdaLimits --render-demo /tmp/oda-limits-initial.png --scenario initial
```

Normal installed smoke testing can register launch at login, like a normal app launch, but does not fetch usage. Add `--demo` to avoid changing system preferences. The interaction probe always uses demo data. A live diagnostic check is available through the explicit `--diagnostics` command.

## Implementation notes

`NSApplication.delegate` is weak. Keep the delegate alive explicitly for the whole `app.run()` lifetime. Initial popover display is deferred briefly so the new status item has attached to its window. The keyboard monitor is local to the key popover and is removed when it closes.

Use eager layout for the four provider cards and initialize disclosure state once. Reapplying the initial value in a lazy card's `onAppear` reset expanded details when scrolling.

On a first installation, `SMAppService.mainApp.status` can be `.notFound`. Attempt initial registration for both `.notFound` and `.notRegistered`; preserve the preference marker so a later choice to disable startup remains respected.

Provider usage endpoints are not a stable public cross-provider API. Optional values remain unknown, empty/unrecognized responses are rejected, and fixture coverage should be updated when schemas change. Explicit manual checks still honor provider 429 retry limits.
