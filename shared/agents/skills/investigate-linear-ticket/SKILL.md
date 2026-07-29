---
name: investigate-linear-ticket
description: Investigate one Linear ticket against live issue and repository evidence, reproduce or trace the reported behavior, and propose a focused fix, decision, or next step without implementing it. Use for read-only ticket investigations, “work on issue” launches from Linear into a local Codex task, bug reproduction, root-cause analysis, implementation planning, or recommendation-only triage.
---

# Investigate Linear Ticket

Investigate one ticket deeply enough that a human can decide what to do next. Treat the report and any linked pull request as claims to verify, not proof.

## Workflow

1. Resolve the exact Linear issue from the supplied identifier or URL. Fetch its current description, state, assignee, labels, attachments, relations, linked pull requests, and all relevant comments. Do not rely only on context copied into the launch prompt.
2. Resolve the current local task's exact technical thread ID from available task metadata. Attach `codex://threads/<thread-id>` to the issue as a native URL link titled `Local Codex task`, relying on issue-and-URL idempotency, then read it back. If Linear rejects the custom scheme, add one deduplicated comment containing `[Open local Codex task](codex://threads/<thread-id>)` and read it back. Never invent an ID.
3. Resolve the intended repository from the selected working directory and ticket evidence. Read the applicable repository instructions and inspect git status before deeper work. Preserve unrelated changes and do not treat a dirty checkout as current-default-branch evidence.
4. Reproduce or directly trace the reported behavior with the smallest trustworthy read-only method: an existing focused test, a minimal example that does not modify tracked files, an exact source-to-sink trace, or current logs and telemetry when authorized.
5. Inspect linked issues and pull requests when they materially affect the diagnosis. Re-read current heads, checks, review state, and relevant diffs instead of trusting summaries.
6. Separate established facts, plausible hypotheses, and missing evidence. Stop at the governing human decision when product semantics, public contracts, security, privacy, billing, migrations, or cross-repository coordination are unresolved.
7. Recommend exactly one primary outcome: a focused fix shape, a request for specific missing evidence, a product or architecture decision, acceptance or revision of a linked pull request, or a no-fix conclusion.

## Boundaries

- Keep the investigation read-only. Do not edit code, change Linear fields, post outcome comments, create branches, commit, push, open pull requests, or submit GitHub reviews.
- Treat the local-task backlink as the only authorized external write. If it cannot be created safely, report that limitation and continue the investigation.
- Do not spawn another Codex task.
- State unavailable connectors, incomplete pagination, stale local state, skipped checks, and unresolved assumptions explicitly.

## Output

Lead with the recommended outcome, then provide concise sections for reproduced behavior and evidence, mechanism or root cause, proposed fix or decision, focused validation, and blockers or uncertainty. Include the Linear issue and local task deep links.
