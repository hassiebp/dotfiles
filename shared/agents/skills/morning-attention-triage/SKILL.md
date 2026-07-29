---
name: morning-attention-triage
description: Gather live start-of-day signals from Pylon, Linear, Slack, and GitHub and rank only work needing the user's immediate attention. Use for morning triage, daily focus lists, personal inbox review, urgent support or issue review, and teammate pull-request or review-request triage.
---

# Morning Attention Triage

Build a short, evidence-backed queue that lets the user start work immediately. Treat this as read-only triage: inspect live state, but do not reply, edit, assign, change status, approve, merge, push, or otherwise mutate any system.

## Workflow

1. Resolve the current user's identity in each connected system. Use the source-specific connector tools and the relevant installed Linear, Slack notification-triage, GitHub, and babysit-pr skills when available.
2. Check all four sources concurrently where tool calls allow it. Use current live data rather than memory or an earlier digest.
3. Open enough context for every likely priority to identify the requester, current owner, latest state, commitment or blocker, and exact next action.
4. Deduplicate related signals across systems. A Slack message about a Linear issue or pull request is one work item, not several.
5. Rank by urgency and user obligation, then return no more than ten actionable items.
6. State any coverage gap explicitly. Never imply that an unavailable inbox or connector was checked.

## Source checks

### Pylon

- Review issues assigned to the user in `new` or `waiting_on_you`, plus recent unassigned issues with credible production impact.
- Expand full messages for candidates involving customer promises, security or privacy, HIPAA, cloud or deployment failures, regressions, or Sev-1 through Sev-3 bugs.
- Rank a concrete customer commitment or `waiting_on_you` state above a generic fresh ticket.
- Exclude newsletters, marketing, spam, duplicates, and low-signal feature requests unless they contain a time-bound obligation.

### Linear

- Review issues assigned to the user, urgent items, active high-priority work, newly assigned work, and fresh triage items that directly involve the user.
- Look for overdue commitments, teammate requests, blockers, incidents, and recent status or comment changes.
- Inspect the Linear Inbox or notifications when the connector exposes them. If it does not, report that limitation and do not substitute an unauthenticated browser view as confirmed coverage.

### Slack

- Follow the Slack notification-triage workflow: resolve the user, then inspect recent direct messages, group direct messages, exact mentions, thread replies, and explicit asks.
- Search with enough variants to avoid treating one query as complete coverage. Use timestamps, surrounding thread context, and permalinks.
- Prioritize direct asks, promises the user made, customer or production blockers, and messages waiting specifically on the user.
- Treat FYIs, broad channel chatter, bot notifications, and already-resolved threads as skim or ignore items.

### GitHub

- Inspect the user's open pull requests for live checks, mergeability, requested changes, unresolved review threads, and author-side blockers.
- Find open pull requests where review is requested from the user, limited to organization repositories and teammates. Prefer verified organization membership or clear internal-team context; exclude bots and random external contributors. If teammate status is uncertain, omit the item or label the uncertainty.
- Distinguish clean review-ready pull requests from drafts, red CI, conflicts, and pull requests where the author still owes work.
- Use the babysit-pr state model for readiness, but remain read-only during this triage.

## Ranking

Order the combined queue using these rules:

1. Overdue customer commitments and active production, security, privacy, HIPAA, or data-integrity problems.
2. Explicit requests where another person is blocked on the user.
3. The user's pull requests that need a small author action to become reviewable or mergeable.
4. Clean teammate pull requests awaiting the user's review.
5. Important but non-urgent active work.

Demote stale backlog, speculative feature requests, FYIs, drafts or failing teammate pull requests whose author owes the next action, bot noise, marketing, and unrelated open-source requests.

## Output contract

Start with the current date and a one-sentence recommendation for the day's focus. Then use these sections:

### Today's priority queue

List five to ten items at most. For each item include:

- a priority label (`P0`, `P1`, or `P2`) and concise title;
- source and direct link;
- why it needs attention now, grounded in current evidence;
- the exact next action for the user;
- owner or requester and any deadline or elapsed waiting time that matters.

### Teammate reviews

Separate review-ready teammate pull requests from those blocked on their authors. Omit the section if there are none.

### Worth skimming

Include only context likely to affect today's decisions. Keep it brief.

### Can ignore for now

Summarize filtered noise by category rather than listing every item.

### Coverage

Say which of Pylon, Linear, Slack, and GitHub were checked successfully and identify partial or unavailable surfaces. Keep raw search logs and exhaustive inventories out of the answer.

If nothing needs immediate attention, say so plainly and name the best proactive focus from active work instead of manufacturing urgency.
