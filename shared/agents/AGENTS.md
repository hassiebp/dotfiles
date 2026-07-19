# Personal agent defaults

Apply these defaults across repositories unless closer project guidance or the user says otherwise.

## Task modes

- Treat `investigate`, `review`, `explain`, and `plan` as read-only. Do not edit, publish, or update external systems unless requested.
- Treat `fix`, `implement`, `resolve`, and `ship` as end-to-end delivery: reproduce when appropriate, implement, test, self-review, commit, push, open a draft pull request, and steward it until it is ready for human review.
- Treat `local only`, `plan only`, `do not publish`, and similar constraints as explicit overrides.
- If evidence does not justify a change, stop with a precise no-fix conclusion. Do not create a patch or pull request to manufacture progress.

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

## Reusable workflows

- Use `$babysit-pr` for pull request CI, review-feedback, mergeability, or readiness loops.
- Use `$weekly-work-digest` for weekly work summaries and team-ready narratives.
