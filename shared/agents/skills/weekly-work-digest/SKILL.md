---
name: weekly-work-digest
description: Gather recent work from Codex task history, memory, GitHub, Linear, and relevant repositories, then produce a concise team-ready weekly update. Use for weekly reviews, standup preparation, end-of-week summaries, an itemized work list, a two-minute spoken story, or identifying the highest-impact work and remaining blockers.
---

# Weekly work digest

Build one evidence-backed weekly narrative that works both as a short spoken update and a detailed reference. Do not require follow-up prompts to obtain alternate formats.

## Determine the window

- Default to the current work week in the user's timezone.
- State exact start and end dates.
- Exclude older work unless it materially changed during the window.

## Gather evidence

Use available sources in this order:

1. Codex task history and durable memory for investigations, designs, support work, and unpublished outcomes.
2. GitHub for authored PRs, commits, review state, and current merged/open/closed status.
3. Linear for assigned issues, status changes, comments, and project context.
4. Local repositories only to resolve ambiguity or verify current branch state.

Verify drift-prone state live. Do not describe a PR as open, merged, green, or blocked solely from memory.

Deduplicate the same outcome across sources. Separate shipped work, in-flight work, investigations with no patch, and operational/support contributions.

## Select the money pieces

Choose at most three themes using:

- user or customer impact;
- architectural or operational leverage;
- amount of ambiguity resolved;
- breadth across the product or SDK surface;
- meaningful shipped or near-shipped outcome.

Do not let a large count of tiny PRs displace a smaller number of consequential themes.

## Produce all formats

Always return, in this order:

1. **Two-minute story:** approximately 200 to 280 spoken words, organized as one coherent narrative rather than a chronology.
2. **Three money pieces:** one compact bullet per theme, including outcome and impact.
3. **Topic appendix:** item-by-item list grouped by topic, with links and current state where useful.
4. **Attention next week:** only decisions, blockers, conflicts, unsigned commits, failing CI, or important follow-ups that still require the user.

Read [references/output-contract.md](references/output-contract.md) when producing a scheduled digest or a version intended to paste directly into a team update.

## Quality bar

- Lead with outcomes and mechanisms, not activity counts.
- Distinguish merged, open, closed, blocked, and no-fix results.
- Include meaningful non-code work such as incident analysis, support conclusions, documentation, outreach, and design decisions.
- Prefer three memorable phrases over a long exhaustive opening.
- Keep the spoken story understandable without links; put details and links in the appendix.
