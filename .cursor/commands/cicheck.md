# CI Check

Run `just ci-check` and analyze any failures or warnings. If there are any issues, fix them and run the command again. Continue this process until `just ci-check` passes completely without any failures or warnings. Focus on:

1. Linting errors (RuboCop)
2. Test failures (RSpec)
3. Formatting issues (RuboCop)
4. Security issues (Brakeman)
5. ERB template issues (ERB Lint)

After each fix, re-run `just ci-check` to verify the changes resolved the issues. Only stop when all checks pass successfully.
