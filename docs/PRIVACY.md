# Privacy and security

Oda Limits runs locally. It reads the current provider session only to make a read-only usage request to that provider's fixed HTTPS origin. Codex, Claude, Cursor, and Grok credentials are never copied into Oda Limits preferences or written to disk. It uses an ephemeral URLSession, limits responses to 512 KiB, and blocks redirects to another origin.

The app stores only enabled-provider toggles and the launch-at-login setup marker in macOS preferences. Usage snapshots stay in memory until the app quits. It sends no telemetry, analytics, prompts, or account changes. The diagnostic command omits credentials, account identifiers, response bodies, and email addresses. Provider requests can still be visible to the provider and to normal network infrastructure. Read-only usage endpoints are provider controlled and can change.

Claude Keychain access is requested only after pressing **Connect Claude Keychain**. The default query forbids authentication UI. The app does not refresh or alter provider-owned credentials. If a session expires, the provider app or CLI must renew it.
