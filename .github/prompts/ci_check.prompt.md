---
mode: agent
---

1. First, run `just ci-check` to identify any failures
2. Analyze the output to understand what specific checks are failing. If everything passes, you’re done.
3. Make minimal, targeted fixes to address ONLY the failing checks:
   - For formatting issues: run `just format`
   - For linting issues: fix the specific violations reported
   - For type checking issues: add missing type hints or fix type errors
   - For test failures: fix the failing tests or underlying code
   - For dependency issues: update pyproject.toml files as needed
4. After making fixes, run `just ci-check` again to verify all checks pass
5. If any checks still fail, repeat steps 2-4 until all checks pass
6. Provide a summary of what was fixed and confirm that `just ci-check` now passes completely

Keep changes minimal and focused - only fix what's actually causing the CI failures. Do not make unnecessary refactoring or style changes beyond what's required to pass the checks.
