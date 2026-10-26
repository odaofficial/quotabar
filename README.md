# Oda Limits

A small native macOS menu bar view of usage allowances for Codex, Claude, Cursor, and Grok. It shows the values providers report, including unknown values and the time of the last successful check. It uses existing local sessions and does not change provider credentials.

Requires macOS 14 or later and Xcode/Swift 6 to build. The app has no third-party runtime packages. The repository is [MIT licensed](LICENSE).

## Download

The [latest release](https://github.com/odaofficial/oda-limits/releases/latest) includes an Apple silicon app for macOS 14+. Extract it, move **Oda Limits.app** to `~/Applications` or `/Applications`, and open it. The context-card icon appears in the menu bar. Usage checks run when you press Refresh; the app has no background polling, embedded browser, or always-running helper.

Release binaries are ad hoc signed for local use, not Apple-notarized. If macOS refuses to open the downloaded binary, build from source below or review it before using the macOS app-approval flow. Do not disable Gatekeeper globally.

## Build and install

```sh
swift test
./Scripts/package.sh
./Scripts/install.sh
open "$HOME/Applications/Oda Limits.app"
```

The first normal launch from `~/Applications` or `/Applications` requests macOS launch-at-login registration. Its current status and toggle are in Settings. If macOS requires approval, enable it in System Settings → General → Login Items. The app has no Dock icon. To remove it, disable launch at login in Settings, quit, and remove the app from `~/Applications`.

To preview synthetic usage without reading credentials, making requests, registering login, or changing preferences:

```sh
.build/release/OdaLimits --demo --show
```

To run a read-only live check with redacted output:

```sh
.build/release/OdaLimits --diagnostics
```

The diagnostic output includes provider name, plan, window labels, used percentages, reset times, and connection status. It does not print account IDs, response bodies, tokens, or email addresses. It never asks for Keychain access.

For a two-second startup check using synthetic data:

```sh
.build/release/OdaLimits --demo --smoke-test
```

This reports whether AppKit completed launch, created the status item, and hosted the popover. A normal `--smoke-test` also reports login-item status. To render the synthetic popover without reading sessions or changing preferences:

```sh
.build/release/OdaLimits --render-demo /tmp/oda-limits-light.png --appearance light
.build/release/OdaLimits --render-demo /tmp/oda-limits-dark.png --appearance dark
.build/release/OdaLimits --render-demo /tmp/oda-limits-settings.png --settings
.build/release/OdaLimits --render-demo /tmp/oda-limits-mixed.png --scenario mixed
.build/release/OdaLimits --render-demo /tmp/oda-limits-empty.png --scenario empty
.build/release/OdaLimits --render-demo /tmp/oda-limits-expanded.png --scenario expanded
.build/release/OdaLimits --render-demo /tmp/oda-limits-initial.png --scenario initial
```

The previews are opaque 420 × 660 point PNGs at 2× resolution. While the popover has keyboard focus, ⌘R refreshes, ⌘, opens Settings, ⌘Q quits, and Escape returns or dismisses.

## Provider setup

- **Codex:** Run `codex login`. The app reads `~/.codex/auth.json`, or `$CODEX_HOME/auth.json`, and asks the ChatGPT usage endpoint. Some Codex installs keep credentials only in Keychain; those sessions may require signing in through the CLI to create the file.
- **Claude:** Run `claude auth login`. The app reads `~/.claude/.credentials.json`, or `$CLAUDE_CONFIG_DIR/.credentials.json`. If needed, choose **Connect Claude Keychain** in the popover to allow the existing Claude Code Keychain entry. No prompt appears at startup.
- **Cursor:** Sign in to the Cursor desktop app. Oda Limits reads Cursor's local SQLite state in read-only mode.
- **Grok:** Run `grok login`. The app reads `$GROK_HOME/auth.json` or `~/.grok/auth.json`. Expired Grok sessions must be renewed by Grok CLI; Oda Limits cannot refresh them.

Sessions remain owned by their provider apps. Oda Limits never rotates tokens. If a provider session expires, sign in through that provider and refresh. Availability of these undocumented usage endpoints can change; an unrecognized or missing field appears as unknown instead of a fabricated zero.

See [Privacy and security](docs/PRIVACY.md) for data handling details.

## Verification and integration sources

See [verification notes](docs/VERIFICATION.md) for test coverage, observed resource use, and live integration limits. Grok requires a working Grok CLI login; its parser is fixture-tested in this release.

The implementation is original Swift code. The 0.2.0 panel follows the [macOS design skill](https://github.com/ceorkm/macos-design-skill/blob/main/SKILL.md). [Provider marks and licenses](docs/THIRD-PARTY.md) are recorded separately. Usage contracts were checked against [OpenAI Codex](https://github.com/openai/codex), [xAI Grok Build](https://github.com/xai-org/grok-build), and [CodexBar](https://github.com/steipete/CodexBar). Thanks to those projects for documenting their integration behavior. Provider names and marks belong to their respective owners; this app is not affiliated with the providers.
