# Search positioning

Research date: 2026-10-26. QuotaBar is positioned as a **lightweight AI usage monitor for the macOS menu bar**, with provider-specific subscription limits and reset times.

## Evidence and limits

A Google Trends comparison of `claude usage monitor`, `codex usage`, and `ai usage tracker` returned HTTP 429. No trend scores, search-volume figures, growth estimates, or keyword-volume ranking were obtained. Even when available, [Google Trends reports normalized interest rather than absolute search volume](https://support.google.com/trends/answer/4365533?hl=en).

Search results and the projects' own pages repeatedly use these phrases:

| Search intent | Evidence | QuotaBar placement |
| --- | --- | --- |
| Claude usage monitor / Claude Code usage limits | [Clauddy](https://github.com/renatoaug/claude-usage-monitor), [Agents Deck](https://github.com/vulonviing/agents-deck) | README opening, provider table, Claude setup and FAQ |
| Codex usage tracker / Codex usage limits | [Codex Usage](https://github.com/Buccccc/codex-usage-tracker), [Tokage](https://tokage.app/) | README opening, provider table and combined-provider FAQ |
| AI usage limits in a Mac menu bar | [Vitals](https://vitalsmac.com/features/ai-usage-limits) | README title, repository description and topics |
| Usage reset times / reset countdown | [ReserveGauge](https://reservegauge.com/), [Toki](https://gettoki.fyi/) | Feature description, provider table and FAQ |

These observations identify established product language and plausible search intent; they do not establish which phrase has the most searches. Competitor references are research evidence, not copied marketing language or affiliation claims.

## Positioning choices

- Primary phrase: **AI usage monitor for the macOS menu bar**.
- Provider phrases: **Claude Code usage monitor**, **Codex usage tracker**, **Cursor usage limits**, **Grok usage limits**.
- Supporting intent: **subscription limits**, **reset times**, **remaining allowance**, **lightweight**, **free and open source**.
- Differentiators backed by implementation: manual refresh, no polling, native SwiftUI/AppKit, existing provider sign-ins, no conversation-history scans, approximately 1.4 MiB installed in the measured release.
- Avoid describing the app as an API token counter, a per-project cost estimator, or an automatic real-time monitor. Those terms attract the wrong expectations.

The README uses descriptive headings, a provider table, a direct download link, copyable installation commands, and focused FAQs. GitHub's public description and topics use the same vocabulary. Keep descriptions accurate as support changes; do not repeat keywords unnaturally or claim search rankings. Google indexing and ranking are outside the repository's control and may take time.
