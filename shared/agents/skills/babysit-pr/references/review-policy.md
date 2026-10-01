# Review feedback policy

The goal is correctness, not comment compliance. Every added line creates maintenance cost; require evidence that the benefit is worth that cost.

## Automated reviewer gate

Treat automated and bot-authored comments as advisory claims. Assess them using the same accept, decline, and clarify criteria below, but do not automatically implement, reply to, or resolve them unless direct evidence establishes an unequivocal bug or P0-level correctness, security, data-loss, or contract issue and the smallest correct fix is unambiguous. A severity label or confident wording from the bot is not evidence.

For every other bot comment, stop before mutation and give the user:

- an **implement**, **decline**, or **clarify** recommendation;
- the concrete code-path, test, or contract evidence supporting it;
- the realistic impact if left unchanged; and
- the maintenance cost, defensive complexity, or scope expansion the suggestion would introduce.

Wait for the user's decision. This gate applies even when the comment would otherwise be classified as accepted.

## Accept

Accept feedback when inspection or a focused reproduction shows one of these:

- reachable incorrect behavior or regression;
- security, privacy, authorization, or data-integrity risk;
- broken public or internal contract relied on by current callers;
- realistic failure handling required by the repository's existing architecture;
- missing test coverage for a concrete high-risk behavior changed by the PR;
- clear scope violation or accidental unrelated change.

## Decline

Decline feedback when it asks for:

- naming, wording, formatting, or structural preference already allowed by repository conventions;
- speculative handling for a state that cannot occur under current invariants;
- redundant guards already enforced at a boundary;
- defensive code that hides programmer errors or weakens type and schema guarantees;
- a new helper, abstraction, configuration option, or dependency without current reuse;
- broad refactoring unrelated to the PR's behavior;
- tests that merely restate implementation details or add no meaningful regression signal;
- complexity whose maintenance or behavioral cost exceeds the demonstrated risk.

Do not describe a comment as a nitpick without explaining the mechanism. State the invariant, existing protection, scope boundary, or tradeoff that makes the change unnecessary.

## Clarify

Ask for clarification only when a potentially material concern depends on missing product intent, an undocumented invariant, or behavior that cannot be derived from code and tests. Ask one narrow question and avoid speculative edits while waiting.

## Reply patterns

Keep replies direct and respectful:

- **Accepted:** `Good catch — this could cause <failure>. Fixed in <commit> and covered by <test/check>.`
- **Declined:** `I don't think we should add this here. <Invariant or existing boundary> already prevents <failure>, while the proposed guard would add <cost or hidden behavior>.`
- **Clarify:** `Can you confirm whether <specific behavior> is intended? The current contract guarantees <known behavior>, so I don't want to add <complexity> without that requirement.`

Reply with case-specific evidence rather than copying these sentences mechanically.
