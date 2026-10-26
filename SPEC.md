# Oda Limits

## Objective and scope
A personal, open-source, native macOS menu bar utility for the user's Codex, Claude, Cursor, and Grok subscriptions. One icon opens four compact cards with authoritative usage, remaining allowance, reset countdown and local reset date, plan, credit/spend details where supplied, connection/freshness status, refresh, and provider dashboard links. Launch at login is enabled on first installed launch, with a visible toggle to disable it. One current account per installed provider; no multi-account management in v0.1.

The user authorized building and installing this utility and creating a public repository under odaofficial. The implementation is separate from the Oda application checkout. Repository: https://github.com/odaofficial/oda-limits. Product name: Oda Limits. Bundle identifier: org.odaofficial.limits. MIT license, copyright Oda contributors.

## Architecture and resource budget
Swift 6 / SwiftPM, macOS 14+, AppKit status item and SwiftUI popover. Only system frameworks: Foundation, AppKit, SwiftUI, Security, ServiceManagement, SQLite3 as needed. No third-party packages, embedded browser, node runtime, cloud service, analytics, LLM calls, background subprocess daemon or history scans.

Use existing local provider sessions read-only. Prefer direct authenticated read-only HTTP usage endpoints over launching provider CLIs. Never refresh or modify provider-owned tokens. If expired, display concrete sign-in instructions and let the provider refresh its own credentials. Read credentials off the main thread; Keychain prompting only through explicit user action. Credentials only in memory; no secret or identifying response bodies in logs, tests, docs, diagnostics, Git, command arguments, or URLs. No credential import UI or copying of tokens into app preferences. Network requests go only to each provider's fixed HTTPS origin; reject redirects to other origins. Ephemeral URLSession with bounded request timeout and response size. Handle 401/403/429, Retry-After/backoff, non-JSON and changed response contracts honestly.

Poll every five minutes with timer tolerance; no polling while asleep, no concurrent refresh loops. Manual refresh throttled to avoid accidental hammering. Reset text updates at minute granularity only while popover is visible. No per-second timers. Target installed app <10 MB, idle CPU <0.5%, idle physical memory <100 MB on this Mac; measure and report actuals, never claim an unmeasured budget.

## Interface
Single monochrome gauge status icon, no Dock icon, normal popover dismissed outside. Compact 400–440 px wide popover, constrained height with scroll when needed. Clear light/dark native presentation; no decorative hero content. Header title + refresh button + loading state. Cards ordered Codex, Claude, Cursor, Grok, labeled remaining percentage (and a used amount if available), windows with labels from provider data, bars, next reset and absolute reset tooltip, plan, extras only when known. Unknown values stay unknown, missing windows do not become 0%. Past resets say awaiting refresh, never assumed fully reset. Last success stays visibly stale after refresh failure but is discarded if account changes. Labels and controls must be accessible.

Footer shows last check, five-minute refresh policy, Settings, Quit. Settings have launch-at-login status/toggle, enabled-provider toggles, open source link, and provider-specific setup help/dashboard. If no login available, useful connection instructions with the existing CLI/app login command. Never open login dialogs at startup. Claude has explicit Connect/Allow Keychain action if needed. Login registration must run only from installed app and reflect actual SMAppService status including requiresApproval.

## Implementation slices
1. Foundation data models, sanitization, parsers and semantic tests using synthetic fixtures. Include Codex extra rate buckets, Claude session/weekly/model limits and extra usage, Cursor plan/on-demand pools, Grok weekly pool and reported reset extras. Match verified current contracts; don't invent endpoints or units.
2. Native adapters and credential reads, fetch orchestration, errors and bounded backoff. Add an opt-in diagnostics command with redacted summaries (provider, plan, window names/percent/reset, status); diagnostics must never prompt Keychain or dump raw replies.
3. AppKit/SwiftUI interface and settings, supported login item, no Dock icon, icons, build/package/install scripts.
4. Independent review and fixes, offline tests, actual live app and provider verification, resource sampling, README and privacy/security docs, public push and release zip.

## Structure and commands
- Package.swift, Sources/OdaLimitsCore (models/parsers/providers), Sources/OdaLimits (UI/main), Tests/OdaLimitsCoreTests, Scripts, docs.
- swift test
- swift build -c release
- ./Scripts/package.sh (dist/Oda Limits.app; ad hoc sign locally)
- ./Scripts/install.sh (~/Applications/Oda Limits.app, no sudo, preserving other apps)
- .build/release/OdaLimits --diagnostics (read-only live smoke test; redacted output)
- app executable --demo --show (synthetic data; no credentials/network/login-registration/preferences writes)

Use simple Swift structs and explicit nullable fields, small helpers, no generic provider plugin framework. Example: struct UsageWindow { let title: String; let usedPercent: Double?; let resetsAt: Date? }. Decoder does not promote missing/invalid data to successful zero usage. Snapshot timestamps correspond to actual retrieval.

## Testing and acceptance
Meaningful Swift Testing/XCTest tests protect parser contracts, percentages/units, absent and malformed fields, null dates, multiple windows, stale/past-reset display, auth failure without body leakage, and credential-format selection using synthetic/temp data only. Do not query real credentials in unit tests. Verify release build, app signing/bundle metadata, live adapter outcomes, menu bar/popover via native UI, actual login registration, and measured footprint/CPU. If auth requires user input, say precisely which connection remains incomplete; don't label unsupported/live-unverified providers working.

## Boundaries
Always preserve user work and credentials, be truthful about data provenance/age, keep licensing attribution for reused upstream code, use parameterized SQLite read-only queries and no shell credential commands in app. Never publish machine paths, personal IDs, email addresses, usage screenshots or credentials without need. Public screenshots/demo must use synthetic data. No buying, subscription changes, or sending prompts. Do not add auto-update services or binaries/dependencies to git. User authorization is sufficient for the build, public repo publication, local installation and requested startup setting; no extra approval gates for routine choices.
