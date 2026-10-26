# Verification — v0.1.0

Verified on Apple silicon, macOS 26.5, Swift 6.3.3. Measurements are a short local sample, not a guarantee across all Macs or provider responses.

- 27 synthetic behavior tests pass, covering provider JSON contracts, malformed/unknown responses, credential selection and expiry, percentages/currency units, retry bounds, and account-change state.
- Independent code review completed. A temporary mutation of percentage validation caused the intended regression test to fail; the mutation was restored.
- Release packaging succeeds. `codesign --verify --strict` passes for the ad hoc signed app; `LSUIElement` is true.
- Installed app lifecycle smoke test reports `launch=ok statusItem=ok hostingView=ok size=420x620 login=On`.
- Codex, Claude, and Cursor adapters returned real usage windows through existing local sessions. Account identities, actual quotas, and credentials are not stored in this repository.
- Grok is tested with synthetic contract fixtures. The available local session required a fresh `grok login`, so a successful live Grok result is not claimed for this release.
- The synthetic native view was rendered and inspected. Interactive click testing through the desktop automation tool was unavailable (native app inspection timed out, including Finder); the lifecycle test and native render cover startup and layout, not every interactive flow.
- App bundle: about 1.1 MiB. Three idle samples over ten seconds reported 0.0% CPU and about 48 MiB RSS. macOS `sample` reported a 14.4 MiB physical footprint, excluding shared resident pages. This was a short sample with the app running normally; workload and OS caching change memory use.

## Reproduce

```sh
swift test
./Scripts/package.sh
./Scripts/install.sh
"$HOME/Applications/Oda Limits.app/Contents/MacOS/OdaLimits" --smoke-test
.build/release/OdaLimits --diagnostics
.build/release/OdaLimits --demo --smoke-test
.build/release/OdaLimits --render-demo /tmp/oda-limits-preview.png
```

Normal installed smoke testing can register launch at login and read existing provider sessions, just like a normal app launch. Add `--demo` for a synthetic check without those effects. Launch-at-login registration was checked through `SMAppService`; a full logout/reboot was not performed.

## Implementation notes

`NSApplication.delegate` is weak. Keep the delegate alive explicitly for the whole `app.run()` lifetime, including release builds. A compile-only check did not catch the original missing initialization.

On a first installation, `SMAppService.mainApp.status` can be `.notFound`. Attempt initial registration for both `.notFound` and `.notRegistered`; restricting the call to `.notRegistered` prevented startup registration on the test Mac. The existing preference marker preserves a later choice to disable startup.

Provider usage endpoints are not a stable public cross-provider API. Optional values remain unknown, empty or unrecognized responses are rejected, and fixture coverage should be updated when provider schemas change.
