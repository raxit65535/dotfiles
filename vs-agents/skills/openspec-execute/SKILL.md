---
name: openspec-execute
description:
  Execute OpenSpec task plans in phased waves with explicit checkpoints
---

# OpenSpec Execute Skill

Use this skill after planning is approved and you want controlled execution.

## Workflow

1. Read tasks and dependency order from the OpenSpec change.
2. Group independent tasks into waves.
3. Execute one wave at a time.
4. Capture decisions, assumptions, and blockers after each wave.
5. Re-plan if blockers change scope.

## Operating Rules

- Do not start coding before task understanding is clear.
- Track task status as work progresses.
- Stop and escalate if requirements conflict.
- End each wave with validation evidence.

## Wave Summary Format

- Wave goal
- Tasks completed
- Validation status
- Decisions made
- Remaining blockers
