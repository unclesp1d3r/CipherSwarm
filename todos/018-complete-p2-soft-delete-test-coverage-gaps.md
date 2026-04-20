---
status: complete
priority: p2
issue_id: '018'
tags: [code-review, testing, soft-delete, coverage]
dependencies: []
origin_issue: '558'
triaged: 2026-04-19
---

# Soft-Delete Test Coverage Gaps

## Problem Statement

After the paranoia → discard migration (issue #558), the `describe "soft delete"` blocks in `spec/models/campaign_spec.rb` and `spec/models/attack_spec.rb` cover the core contract (destroy sets `deleted_at`, `.kept`/`.discarded` scopes, `discarded?`/`kept?` predicates, direct-child cascade). Several follow-on scenarios remain untested.

## Findings

- **Source**: ce:review run `20260419-191817-0c8476b9` — testing-reviewer (multiple findings).
- **Evidence**:
  - `test-001` (conf 0.85): `destroy!` raise branch — no test forces `discard` to fail and asserts the `RecordNotDestroyed` raise.
  - `test-002` (conf 0.80): Idempotent-destroy test only checks `deleted_at` unchanged; does not verify callbacks are suppressed on the second call.
  - `test-003` (conf 0.90): Full Campaign → Attack → Task cascade chain — no test creates a `Task` under an `Attack` under a `Campaign` and asserts `Task.unscoped` rows are physically gone after `campaign.destroy`.
  - `test-004` (conf 0.75): `CampaignsController#destroy` and `AttacksController#destroy` call `destroy!` but no request spec exercises DELETE and asserts the record is discarded, hidden from default queries, and returns 404 on subsequent show.
- **Impact**: These gaps won't break today's behavior but leave regressions in adjacent code (controller changes, Task schema changes, callback additions) undetectable until production.

## Proposed Solutions

Add the missing scenarios to the respective spec files.

### Tests to add

1. **Full cascade chain (Campaign → Attack → Task):**

   ```ruby
   it "hard-deletes transitively-associated tasks when the campaign is discarded" do
     attack = create(:dictionary_attack, campaign: campaign)
     task = create(:task, attack: attack)
     expect { campaign.destroy }.to change { Task.unscoped.exists?(task.id) }.from(true).to(false)
   end
   ```

2. **Callback suppression on double-destroy** (prove `return self if discarded?` short-circuits callbacks):

   - Stub a `before_destroy` callback counter, call `destroy` twice, assert the callback ran exactly once.

3. **`destroy!` raise path** (prove the raise is reachable):

   - Stub `discard` to return `false`, call `destroy!`, assert `ActiveRecord::RecordNotDestroyed` is raised.

4. **Request-spec DELETE coverage** (if `spec/requests/campaigns_spec.rb` / `spec/requests/attacks_spec.rb` don't already cover it):

   - Authenticated project user can destroy → response 302 or turbo_stream, record's `deleted_at` is set, subsequent index/show excludes the record.
   - Unauthenticated user cannot destroy.
   - Non-project user cannot destroy (authorization parity).

### Tests NOT to add in this todo

- Counter-cache / undiscard scenarios — todo's dependency is latent (see adversarial finding `adversarial-1`). Defer until a restoration feature is actually planned.
- `.discarded` chain composition tests — covered by todo 019 (`.discarded` scope idiom review).

## Recommendation

Add cascade chain (1), `destroy!` raise (3), and request-spec DELETE coverage (4) first — they protect real contract surfaces. Callback suppression (2) is lower priority because it's a micro-detail unlikely to regress silently.

**Additions from 2026-04-19 triage (follow-up PR review findings):**

- **5. `attack.hash_list` via discarded Campaign** — `Attack.has_one :hash_list, through: :campaign` combined with `default_scope -> { kept }` on Campaign means `attack.hash_list` returns `nil` when the Attack's Campaign is soft-deleted. Downstream, `attack.hash_mode` delegates through `hash_list` and will `NoMethodError`. Add a spec that discards a Campaign, reloads an Attack via `Attack.unscoped.find`, and asserts behavior of `.hash_list` and `.hash_mode`. Catches a real bug for any background job or admin tool iterating `Attack.unscoped`.
- **6. `User.has_many :campaigns, dependent: :restrict_with_error`** — post-discard, `user.campaigns` returns `[]` (filtered by default_scope) while the underlying FK rows still exist, so an admin UI could offer to delete a user and then get blocked by `RecordNotDestroyed`. Add a spec asserting `user.campaigns.count` after discard vs. `user.destroy` behavior.
- **7. After today's counter-cache fix (PR #864 commit `08e29cd`):** add an assertion that `campaign.attacks_count` decrements by one on `attack.destroy`. The regression test was added inline in the counter-cache fix commit — confirm it's preserved when the concern is extracted (todo 016).

## Test Plan

- `just ci-check` green with the new tests.
- New tests document specific scenarios that future refactors (todo 016 concern extraction, todo 017 contract fix) must preserve.

## Related

- Origin: Issue [#558](https://github.com/unclesp1d3r/CipherSwarm/issues/558)
- Related: todo 016 (concern extraction — tests should be moved/shared), todo 017 (halted-callback contract fix — adds a new spec class for the `:abort` path).
