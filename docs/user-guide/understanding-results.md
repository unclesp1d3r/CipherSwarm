# Understanding Results

This guide covers how to view, interpret, and export cracking results in CipherSwarm v2.

---

## Table of Contents

- [Viewing Cracked Hashes](#viewing-cracked-hashes)
- [Understanding Hash Types](#understanding-hash-types)
- [Interpreting Attack Results](#interpreting-attack-results)
- [Progress Tracking](#progress-tracking)
- [Exporting Data](#exporting-data)
- [Recent Cracks Feed](#recent-cracks-feed)
- [Result Analysis](#result-analysis)
- [Security Considerations](#security-considerations)

---

## Viewing Cracked Hashes

### From the Dashboard

The dashboard provides a quick overview of cracking activity:

- **Recently Cracked** status card shows the number of hashes cracked in the last 24 hours
- This count is scoped to your currently selected project
- Click the card to navigate to detailed results

### From a Campaign

1. Navigate to **Campaigns** and select your campaign
2. The campaign page shows overall progress and recent activity
3. Click the **Hash List** name to view the full hash list with results
4. Cracked hashes display their plaintext values alongside the original hash

### From a Hash List

1. Navigate to **Hash Lists** in the top menu
2. Select the hash list you want to view
3. The hash list page shows:
   - Total hash count
   - Number cracked vs uncracked
   - Completion percentage
   - Individual hash entries with their status

### Filtering Results

Use the filter controls on the hash list page:

- **All**: Show all hashes (cracked and uncracked)
- **Cracked**: Show only hashes that have been cracked
- **Uncracked**: Show only hashes that remain uncracked
- **Search**: Search by hash value or plaintext

---

## Understanding Hash Types

CipherSwarm supports the same hash types as hashcat. Here are the most commonly encountered types:

| Hash Type | Mode  | Example Format                                 |
| --------- | ----- | ---------------------------------------------- |
| MD5       | 0     | `5f4dcc3b5aa765d61d8327deb882cf99`             |
| SHA-1     | 100   | `5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8`     |
| SHA-256   | 1400  | `5e884898da28047151d0e56f8dc6292773603d0d6...` |
| NTLM      | 1000  | `a4f49c406510bdcab6824ee7c30fd852`             |
| bcrypt    | 3200  | `$2a$05$LhayLxezLhK1LhWvKxCyLOj0j...`          |
| WPA       | 22000 | `WPA*02*...`                                   |

The hash type is set when creating a hash list and determines how hashcat processes the hashes.

For a full list of supported hash types, refer to the [hashcat documentation](https://hashcat.net/wiki/doku.php?id=example_hashes).

---

## Interpreting Attack Results

### Success Rate

The success rate indicates the percentage of hashes cracked by a specific attack:

```
Success Rate = (Hashes Cracked by Attack / Total Hashes in List) x 100
```

Typical success rates vary by attack type and hash complexity:

- **Dictionary attacks**: 30-60% for common password sets
- **Rule-based attacks**: 50-80% when combined with good wordlists
- **Mask attacks**: Variable, depends on pattern accuracy
- **Brute force**: Eventually 100% if keyspace is feasible, but very slow

### Time to Crack

Each cracked hash records when it was found. This helps you understand:

- Which attacks are most effective for your hash types
- How quickly easy passwords fall vs complex ones
- Whether your attack strategy is well-ordered

### Attack Attribution

When viewing cracked hashes, you can see which attack cracked each hash. This helps refine future attack strategies:

- If dictionary attacks crack most hashes, focus on better wordlists
- If rule attacks add significant cracks, invest in comprehensive rule files
- If mask attacks succeed, similar patterns likely exist in remaining hashes

---

## Progress Tracking

### Campaign Completion Percentage

The campaign progress bar shows overall completion across all attacks:

```
Overall Progress = Sum of (Attack Progress x Attack Weight) / Total Weight
```

Each attack contributes based on its keyspace size relative to the total campaign keyspace.

### Attack Progress Indicators

Individual attacks show:

- **Progress Percentage**: Keyspace processed vs total keyspace
- **Speed**: Current hash rate (hashes per second)
- **ETA**: Estimated time remaining based on current speed
- **Tasks**: Number of active, completed, and pending tasks

### ETA Calculations

ETA estimates are based on:

- Current aggregate hash rate across all agents working on the attack
- Remaining keyspace to process
- Historical performance data

ETAs become more accurate over time as the system collects more data points. Early estimates may fluctuate significantly.

---

## Exporting Data

CipherSwarm supports multiple export formats for cracking results.

### CSV Export

Exports cracked hashes as comma-separated values:

```csv
hash,plaintext,cracked_at
5f4dcc3b5aa765d61d8327deb882cf99,password,2026-01-15T10:30:00Z
e10adc3949ba59abbe56e057f20f883e,123456,2026-01-15T10:31:00Z
```

### TSV Export

Exports cracked hashes as tab-separated values:

```tsv
hash	plaintext	cracked_at
5f4dcc3b5aa765d61d8327deb882cf99	password	2026-01-15T10:30:00Z
```

### Hashcat Format Export

Exports in hashcat-compatible format (hash:plaintext):

```
5f4dcc3b5aa765d61d8327deb882cf99:password
e10adc3949ba59abbe56e057f20f883e:123456
```

### How to Export

1. Navigate to the hash list results view
2. Click the **Export** button
3. Select the desired format from the dropdown
4. The file downloads to your browser automatically

### Bulk Export

For large hash lists:

- Exports are generated server-side
- A download link is provided when the export is ready
- Large exports may take a few moments to prepare

---

## Recent Cracks Feed

CipherSwarm V2 includes a real-time recent cracks feed that appears on campaign and dashboard pages.

### How It Works

- Newly cracked hashes appear in the feed as they are discovered
- Updates are delivered via Turbo Streams (no page refresh needed)
- Each entry shows the plaintext value, timestamp, and which attack found it
- The feed is rate-limited to prevent notification overload during high-speed cracking

### Toast Notifications

In addition to the feed, toast notifications appear when new hashes are cracked:

- **Individual Toasts**: Show details for single cracks
- **Batch Toasts**: Aggregate when multiple hashes are cracked rapidly (e.g., "5 new hashes cracked")
- Toasts auto-dismiss after a few seconds

### Disabling Notifications

If toast notifications are distracting:

- Notifications respect your browser's notification settings
- Individual toast notifications can be dismissed by clicking the close button

---

## Result Analysis

### Understanding Password Patterns

After cracking a significant number of hashes, review the plaintext values for patterns:

- **Common passwords**: Indicates weak password policies
- **Variations of the same word**: Suggests predictable mutations
- **Sequential patterns** (123456, abcdef): Indicates very weak passwords
- **Company-specific terms**: May indicate targeted password choices

### Identifying Remaining Challenges

Uncracked hashes after multiple attack phases may indicate:

- Truly random passwords
- Unusual character sets or long passwords
- Hash types with high computational cost (e.g., bcrypt with high work factor)
- Passwords not in your wordlists or covered by your rules

### Planning Follow-Up Attacks

Based on results analysis:

1. If many variations of common words were cracked, use more aggressive rules
2. If short passwords dominate, extend brute force length ranges
3. If company-specific terms appear, create custom targeted wordlists
4. If mask attacks succeed with specific patterns, create more masks targeting similar patterns

---

## Security Considerations

Cracked passwords are sensitive data. Handle them responsibly.

### Access Control

- Results are scoped to projects - only authorized users can view them
- Export functionality is available to project members
- Audit logs track who accesses and exports results

### Data Handling

- Do not share cracked passwords outside authorized channels
- Delete exports from local machines after they have been used
- Follow your organization's data handling policies
- Consider encrypting exported files before transmission

### Reporting

When reporting cracking results:

- Report aggregate statistics (percentages, patterns) rather than individual passwords
- Redact or hash plaintext values in reports shared broadly
- Focus on policy recommendations rather than specific passwords
- Document findings in compliance with your organization's security policies

---

## Related Guides

- [Campaign Management](campaign-management.md) - Managing the campaigns that produce results
- [Attack Configuration](attack-configuration.md) - Configuring attacks for better results
- [Performance Optimization](optimization.md) - Improving cracking speed
- [FAQ](faq.md) - Common questions about results and exports
