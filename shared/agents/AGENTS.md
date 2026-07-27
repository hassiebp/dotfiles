# Personal agent defaults

Apply these defaults across repositories unless closer project guidance or the user says otherwise.

## Task modes

- Treat `investigate`, `review`, `explain`, and `plan` as read-only. Do not edit, publish, or update external systems unless requested.
- Treat `fix`, `implement`, `resolve`, and `ship` as end-to-end delivery: reproduce when appropriate, implement, test, self-review, commit, push, open a draft pull request, and steward it until it is ready for human review.
- Treat `local only`, `plan only`, `do not publish`, and similar constraints as explicit overrides.
- If evidence does not justify a change, stop with a precise no-fix conclusion. Do not create a patch or pull request to manufacture progress.

## Visual communication

- Bias strongly toward visual explanations. For complex workflows, architecture, state transitions, event sequences, branching decisions, or interactions across multiple components or systems, lead with an appropriate Mermaid diagram.
- Choose the smallest diagram that explains the relationship: flowcharts for workflows and decisions, sequence diagrams for interactions, state diagrams for lifecycles, and graphs for dependencies or ownership.
- Keep diagram labels concise and quote Mermaid labels containing punctuation. Follow the diagram with only the prose needed to explain implications, tradeoffs, or next actions.
- Do not add a diagram to a simple fact, one-step action, or short answer where it would not improve understanding.

## Definition of done for published work

- Follow the closest repository instructions for validation and contribution conventions.
- Keep the diff focused and preserve unrelated user changes.
- Run the smallest trustworthy validation set, then self-review the final diff.
- After opening or updating a pull request, inspect its live checks and unresolved review threads.
- Fix code-caused CI failures. Evaluate review feedback independently: implement proven correctness, security, or contract issues, but decline nitpicks, speculative defensive code, unrelated refactors, and unjustified complexity with a concise rationale.
- Do not hand back merely because CI is still running. Continue monitoring when the current harness supports follow-ups or scheduled task heartbeats.
- Stop when the pull request is green and waiting on a human, or when blocked on a human decision, permissions, external infrastructure, or an unsafe operation.
- Never merge, approve, close, force-push, weaken protections, or quarantine a test without clear evidence and authority.

## External closeout

- When implementation starts from a Linear issue and external writes were requested or clearly included in the delivery workflow, post a concise evidence-backed update with the pull request and verification results, then read it back.
- Draft public or social communication such as Slack and upstream-project messages unless sending was explicitly requested.
- Report skipped checks and remaining blockers plainly.

## Langfuse pull requests

- Before opening a pull request targeting a repository in the Langfuse GitHub organization, resolve its corresponding Linear issue.
- Reuse an existing issue only when it represents the same change; otherwise create a new issue in the appropriate Linear team before publishing the pull request.
- Ensure the issue records durable context: the motivation and impact, current behavior or evidence, intended solution or shape of the fix, relevant scope, non-goals, and tradeoffs, plus validation, rollout, and follow-up details when applicable. Enrich a thin existing issue before linking it.
- Link the Linear issue in the pull request description and attach or link the pull request from the Linear issue. Read back both sides to verify the cross-link.
- Do not publish a Langfuse pull request without a corresponding Linear issue unless the user explicitly overrides this requirement. If Linear is unavailable, stop and report the blocker instead of silently omitting the issue.

## Reusable workflows

- Use `$babysit-pr` for pull request CI, review-feedback, mergeability, or readiness loops.
- Use `$linear-triage-quick-fixes` for scheduled sweeps of the current user's assigned Linear issues in Triage or Todo; reproduce bugs in fresh per-ticket tasks, ship only bounded quick fixes, independently validate linked community pull requests, and recommend next steps.
- Use `$weekly-work-digest` for weekly work summaries and team-ready narratives.
