# ADR-002: Allow autonomous documentation maintenance by the agent

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-04-11 |
| Scope | Documentation operations |

## Context

The new docs system separates status, changelog, issues, and decisions.
To make that system useful in day-to-day work, the agent should not wait for explicit instructions every time a blocker, discrepancy, or status change is discovered during normal execution.

The repository owner wants this operational maintenance to include phase transitions as well, as long as those transitions are grounded in observed code and validation state rather than guesswork.

## Decision

By default, the agent may perform the following without separate user instruction:

1. Create or update issue files and the issue index when a real blocker, bug, or document inconsistency is confirmed.
2. Update `docs/STATUS.md` and, when appropriate, `docs/CHANGELOG.md` to reflect current progress, blockers, and important documentation changes.
3. Continuously inspect and maintain open issue status while related work is in progress.
4. Perform official phase transition work, including marking a phase complete, promoting the next phase, or changing the canonical phase state in handoff/status documentation, when the current repository state and validation evidence justify it.

## Rationale

- The cost of stale operational docs is high during active development.
- Issue and status maintenance are low-risk operational updates when based on directly observed repo state.
- Operational docs are most useful when they reflect the current repository truth without waiting for separate clerical prompts.
- Phase transitions can be automated safely if they are tied to observed implementation and validation evidence.

## Consequences

- The docs system becomes a living operational surface instead of a passive archive.
- `STATUS.md`, `CHANGELOG.md`, and `issues/` may change as part of normal implementation or review work.
- Phase completion and promotion may also be updated by the agent when evidence supports the change.
