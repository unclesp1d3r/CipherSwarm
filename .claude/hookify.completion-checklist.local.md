---
name: completion-checklist
enabled: true
event: stop
action: warn
pattern: .*
---

✅ **Completion Checklist**

Before marking this work complete, verify:

**Testing:**

- [ ] Tests written for new functionality
- [ ] All tests passing: `just test` or `bundle exec rspec`
- [ ] System tests passing if UI changed: `just test-system`
- [ ] API tests passing if API changed: `just test-api`

**Code Quality:**

- [ ] RuboCop linting passing: `just lint` or `just check`
- [ ] Brakeman security scan clean: `just security`
- [ ] No debug code left (binding.pry, puts debugging)

**Documentation:**

- [ ] CHANGELOG.md updated if needed
- [ ] API documentation regenerated if endpoints changed: `just docs-api`
- [ ] Comments added for complex logic

**Database:**

- [ ] Migrations tested and reversible
- [ ] Schema.rb updated (auto-generated)
- [ ] No manual migration file creation

**Git:**

- [ ] Meaningful commit message
- [ ] No sensitive data in commits (.env, tokens, etc.)
- [ ] Branch up to date with main if needed

**For PRs:**

- [ ] PR description explains changes
- [ ] Tests cover edge cases
- [ ] No breaking changes (or documented)

*You can disable this checklist with `/hookify:configure` if not needed.*
