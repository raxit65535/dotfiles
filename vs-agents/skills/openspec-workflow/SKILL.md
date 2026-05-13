---
name: openspec-workflow
description:
  Structured OpenSpec workflow for planning and shipping non-trivial work
---

# OpenSpec Workflow

Use this skill when work is cross-cutting, risky, or larger than a quick fix.

## Trigger Conditions

- Multi-file or multi-service change
- Data model, migration, or API contract impact
- New integration boundaries
- Coordinated rollout needed

## Workflow

1. Clarify scope and constraints.
2. Create or update OpenSpec proposal and tasks in the target repo.
3. Confirm assumptions and acceptance criteria before coding.
4. Implement in small phases and update task status as work progresses.
5. Close with explicit validation evidence and residual risks.

## Minimum Proposal Sections

- Summary
- Motivation
- Proposed solution
- Alternatives considered
- Impact and risk
- Task plan
- Validation and rollout

## Output Checklist

- Explicit in-scope and out-of-scope
- Acceptance criteria tied to tests/checks
- Risks and mitigations listed
- Rollout and rollback approach
