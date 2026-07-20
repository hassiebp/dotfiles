# BabysitPR state model

Use deterministic GitHub fields for state and use model judgment only to classify the meaning of comments or failures.

## Readiness predicate

`READY_FOR_HUMAN_REVIEW` requires all of the following:

- PR is open and not blocked by its draft policy.
- Head is mergeable and has no conflict.
- Required checks are complete and green.
- No active changes-requested review remains.
- No unresolved thread is waiting on the author.
- No remediation run is active for the current head.
- No human product, security, or architectural decision is outstanding.

Approval is not required. Human approval happens after readiness.

## Thread classification

| State | Meaning | Action |
| --- | --- | --- |
| Resolved or outdated | Finished | Ignore |
| Reviewer wrote last | Author may owe a change, decline, or clarification | Apply the review policy |
| Author accepted and fixed | Addressed | Reply with evidence; resolve only when authorized |
| Author declined with rationale | Waiting for reviewer | Do not change code merely to clear the thread |
| Author asked for clarification | Waiting for reviewer | Do not act |
| Reviewer replied after author | Author may owe work again | Reclassify from evidence |
| Bot-only | Depends on configured bot policy | Ignore or classify explicitly |
| Product, architecture, or security decision | Human judgment required | Notify and stop |

## CI classification

- Treat assertion, type, lint, format, build, or deterministic test failures caused by the diff as code-actionable.
- Treat cancelled, skipped, rate-limited, runner-lost, node-down, timeout-only, and provider-outage results as infrastructure until evidence shows otherwise.
- Never quarantine or weaken a test because it failed once.
- Require repeated or otherwise direct evidence before declaring a test flaky.

## Idempotency and limits

Key remediation by `repository + PR + head SHA + blocker fingerprint`.

- Allow at most two automated code-change attempts for one blocker fingerprint and head SHA.
- Do not run two writers against the same PR head.
- Reclassify whenever the head SHA changes.
- Remove an automation-owned readiness label whenever the predicate becomes false.
- Never let an agent apply the readiness label based solely on its own prose assessment; re-read GitHub state first.

Use `ready-for-human-review` as the automation-owned label. If it is missing and label management is authorized, create it once with color `0E8A16` and description `Automation-verified: CI green, mergeable, and no unresolved author-side work.`
