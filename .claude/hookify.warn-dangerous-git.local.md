---
name: warn-dangerous-git
enabled: true
event: bash
action: warn
pattern: git\s+push\s+.*(-f|--force).*\s+(main|master)|git\s+push\s+.*\s+(main|master).*(-f|--force)
---

🚨 **Dangerous Git Operation Detected!**

You're attempting to force push to a main branch (main or master).

**Why this is dangerous:**

- Rewrites shared history
- Can lose other developers' work
- Breaks anyone who has pulled the branch
- Violates standard Git workflows

**What you probably want:**

1. **If you need to update your branch:**

   ```bash
   git pull --rebase origin main
   git push
   ```

2. **If you need to fix a commit:**

   ```bash
   # Create a new commit instead
   git revert <commit-hash>
   ```

3. **If working on a feature branch:**

   ```bash
   # Force push to your feature branch is fine
   git push --force origin feature-branch-name
   ```

**Only force push to main/master if:**

- You have explicit team approval
- This is a personal repository
- You understand the consequences

**Safer alternatives:**

- Use feature branches for development
- Create new commits instead of amending
- Use `git revert` to undo changes
- Coordinate with team before history rewrites
