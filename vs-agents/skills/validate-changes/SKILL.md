---
name: validate-changes
description: Standard validation checklist before declaring work complete
---

# Validate Changes Skill

Use this skill before marking implementation complete.

## Validation Checklist

1. Lint passes.
2. Typecheck/build passes where applicable.
3. Relevant tests pass.
4. Diff scope is limited to intended files.
5. Risks and assumptions are documented.

## If Validation Fails

1. Read errors fully.
2. Fix root causes, not symptoms.
3. Re-run validation.
4. Repeat until green.

## Completion Format

- Validation commands run
- Pass/fail per stage
- Outstanding risk items
