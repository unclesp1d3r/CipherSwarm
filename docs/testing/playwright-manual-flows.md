# Playwright Manual Testing Flows

This document lists the manual UI flows tested via Playwright during development sessions. These can be repeated to verify functionality.

## Campaign & Attack Workflows

### 1. View Campaign Details

- Navigate to Campaigns list
- Click on a campaign to view details
- Verify campaign information displays correctly
- Verify attack list renders (stepper component)

### 2. Add Attack to Campaign

- Navigate to an existing campaign
- Click "Add Attack" button
- Select attack type (Dictionary, Mask, Hybrid, etc.)
- Fill in attack parameters:
  - Name
  - Word list selection (for dictionary attacks)
  - Mask selection (for mask attacks)
  - Rule list selection (optional)
- Submit the form
- Verify attack appears in campaign's attack list
- Verify estimated complexity displays correctly

### 3. View Attack Details

- Navigate to campaign with attacks
- Click on an attack to view details
- Verify attack configuration displays correctly

## Resource Management Workflows

### 4. Word List Upload & Processing

- Navigate to Word Lists
- Upload a new word list file
- Verify file uploads successfully
- Verify Sidekiq processes the file (line count calculated)
- Verify complexity/line count displays in list

### 5. Mask List Upload & Processing

- Navigate to Mask Lists
- Upload a new mask list file (.hcmask)
- Verify file uploads successfully
- Verify Sidekiq calculates complexity value
- Verify complexity displays in list

### 6. Rule List Upload & Processing

- Navigate to Rule Lists
- Upload a new rule list file (.rule)
- Verify file uploads successfully
- Verify Sidekiq counts lines
- Verify line count displays in list

### 7. Hash List Upload & Processing

- Navigate to Hash Lists
- Create new hash list with file
- Select hash type
- Verify file uploads successfully
- Verify hash items are created (ProcessHashListJob)
- Verify completion status shows "X / Y" format

## UI Component Verification

### 8. Attack Stepper Display

- Navigate to campaign with multiple attacks
- Verify stepper component renders correctly
- Verify attack status indicators display
- Verify error states show modal trigger for failed attacks

### 9. Bootstrap Icons

- Verify icons render throughout the application
- Check navigation icons
- Check action button icons
- Check status indicator icons

## Multi-Tenant Authorization Testing

These flows verify project-based resource isolation between users. They require admin access to set up users and projects.

### 10. Admin Setup: Create Projects and Users

- Log in as admin
- Navigate to Admin page
- **Create Project Alpha:**
  - Click "New Project"
  - Name: "Project Alpha"
  - Submit
- **Create User 1 (alice):**
  - Click "New User"
  - Name: alice, Email: <alice@example.com>, Password: password
  - Submit
  - Unlock user (click unlock button in user row)
  - Navigate to Default Project > Edit > Add alice to project
- **Create User 2 (bob):**
  - Click "New User"
  - Name: bob, Email: <bob@example.com>, Password: password
  - Submit
  - Unlock user (click unlock button in user row)
  - Navigate to Project Alpha > Edit > Add bob to project
- Log out as admin

### 11. User 1 (Alice): Create Resources on Default Project

- Log in as alice (password: password)
- **Word List:** Tools > Word Lists > New
  - Name: "Alice Top Passwords"
  - File: `spec/fixtures/word_lists/top-passwords.txt`
  - Project: Default Project (checked)
  - Submit, verify success
- **Rule List:** Tools > Rule Lists > New
  - Name: "Alice Dive Rules"
  - File: `spec/fixtures/rule_lists/dive.rule`
  - Project: Default Project (checked)
  - Submit, verify success
- **Mask List:** Tools > Mask Lists > New
  - Name: "Alice RockYou Masks"
  - File: `spec/fixtures/mask_lists/rockyou-1-60.hcmask`
  - Project: Default Project (checked)
  - Submit, verify success
- **Hash List:** Hash Lists > New
  - Name: "Alice MD5 Hashes"
  - File: `spec/fixtures/hash_lists/example_hashes.txt`
  - Hash Type: 0 (MD5)
  - Project: Default Project
  - Submit, verify success
- **Campaign:** Activity > New Campaign
  - Name: "Alice MD5 Campaign"
  - Hash List: Alice MD5 Hashes (auto-selected)
  - Submit, verify success
- **Attack:** Click "Add Dictionary Attack" on campaign
  - Name: "Alice Dictionary Attack"
  - Word List: Alice Top Passwords (auto-selected)
  - Rule List: Alice Dive Rules
  - Submit, verify attack appears in campaign
- Log out as alice

### 12. User 2 (Bob): Create Resources on Project Alpha

- Log in as bob (password: password)
- Verify Activity page shows no campaigns (blank slate)
- **Word List:** Tools > Word Lists > New
  - Name: "Bob Top Passwords"
  - File: `spec/fixtures/word_lists/top-passwords.txt`
  - Project: Project Alpha (checked)
  - Verify only "Project Alpha" appears as project option (not Default Project)
  - Submit, verify success
- **Rule List:** Tools > Rule Lists > New
  - Name: "Bob Dive Rules"
  - File: `spec/fixtures/rule_lists/dive.rule`
  - Project: Project Alpha (checked)
  - Submit, verify success
- **Mask List:** Tools > Mask Lists > New
  - Name: "Bob RockYou Masks"
  - File: `spec/fixtures/mask_lists/rockyou-1-60.hcmask`
  - Project: Project Alpha (checked)
  - Submit, verify success
- **Hash List:** Hash Lists > New
  - Name: "Bob SHA1 Hashes"
  - File: `spec/fixtures/hash_lists/example_hashes.txt`
  - Hash Type: 100 (SHA1) — use a different type than Alice for distinction
  - Project: Project Alpha
  - Submit, verify success
- **Campaign:** Activity > New Campaign
  - Name: "Bob SHA1 Campaign"
  - Hash List: Bob SHA1 Hashes (auto-selected)
  - Submit, verify success
- **Attack:** Click "Add Dictionary Attack" on campaign
  - Name: "Bob Dictionary Attack"
  - Word List: Bob Top Passwords (auto-selected)
  - Rule List: Bob Dive Rules
  - Verify only Bob's resources appear in dropdowns (not Alice's)
  - Submit, verify attack appears in campaign
- Log out as bob

### 13. Verify Resource Isolation

- Log in as alice (password: password)
- **Activity:** Verify only "Alice MD5 Campaign" appears (no "Bob SHA1 Campaign")
- **Word Lists:** Verify only "Alice Top Passwords" appears (no "Bob Top Passwords")
- **Rule Lists:** Verify only "Alice Dive Rules" appears (no "Bob Dive Rules")
- **Mask Lists:** Verify only "Alice RockYou Masks" appears (no "Bob RockYou Masks")
- **Hash Lists:** Verify only "Alice MD5 Hashes" appears (no "Bob SHA1 Hashes")
- All resources should show "Default Project" as the project
- Log out as alice

## Prerequisites for Testing

Before running these flows:

1. **Start Development Server**

   ```bash
   just dev
   ```

2. **Start Sidekiq** (for background job processing)

   ```bash
   just sidekiq
   ```

3. **Seed Data** (if needed)

   ```bash
   bin/rails db:seed
   ```

4. **Sample Files** — Use the fixture files in `spec/fixtures/` for uploads:

   - `spec/fixtures/word_lists/top-passwords.txt` — Word list
   - `spec/fixtures/rule_lists/dive.rule` — Rule list
   - `spec/fixtures/mask_lists/rockyou-1-60.hcmask` — Mask list
   - `spec/fixtures/hash_lists/example_hashes.txt` — Hash list
   - `spec/fixtures/hash_lists/hashcat_example0.txt` — Hash list (alternative)
   - `spec/fixtures/files/test_mask_file.hcmask` — Mask file (alternative)
   - `spec/fixtures/cracker_binaries/hashcat.7z` — Cracker binary

## Notes

- Admin-created users are locked by default and must be unlocked before they can log in

- If a user's password doesn't work after Docker rebuild, reset it via Rails runner:

  ```bash
  docker exec csdev-web-1 bin/rails runner 'u = User.find_by(name: "alice"); u.update(password: "password", password_confirmation: "password")'
  ```

- Word list complexity shows as "0" or "pending" until Sidekiq processes the file

- Mask list complexity is calculated from mask patterns (can be very large numbers)

- Hash list shows "importing..." until ProcessHashListJob completes

- ERB strict locals require proper magic comments: `<%# locals: (var:) -%>`
