---
name: warn-sensitive-files
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: (\.env|\.env\.|credentials|secrets|\.pem|\.key|\.cert|master\.key|config/credentials)
---

🔐 **Sensitive File Edit Detected!**

You're editing a file that may contain secrets or credentials.

**Security reminders:**

1. **Never commit secrets to version control**

   - API keys, passwords, tokens should never be in Git history
   - Use environment variables or Rails credentials instead

2. **Verify .gitignore:**

   - Ensure this file is in `.gitignore`
   - Check: `git check-ignore -v <filename>`

3. **Rails credentials (preferred approach):**

   ```bash
   # Edit encrypted credentials
   EDITOR=vim bin/rails credentials:edit

   # For environment-specific
   EDITOR=vim bin/rails credentials:edit --environment production
   ```

4. **Environment variables (alternative):**

   - Store in `.env` (gitignored)
   - Use `dotenv` gem for development
   - Set in production environment (Heroku, AWS, etc.)

5. **If using .env files:**

   - Include `.env*` in .gitignore (except `.env.example`)
   - Never commit actual secrets
   - Use `.env.example` with dummy values as template

**Current gitignore check:** Run: `git check-ignore -v .env`

If not ignored, add to `.gitignore`:

```
.env
.env.local
.env.*.local
```

**After editing:**

- [ ] Confirm file is gitignored
- [ ] Never commit actual secrets
- [ ] Use dummy values in examples
- [ ] Document required environment variables
