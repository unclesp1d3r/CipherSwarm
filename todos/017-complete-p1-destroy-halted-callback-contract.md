---
status: complete
priority: p1
issue_id: '017'
tags: [code-review, correctness, soft-delete, active-record]
dependencies: []
origin_issue: '558'
triaged: 2026-04-19
---

# `destroy` Override Returns `self` Unconditionally, Dropping AR's Halted-Callback Contract

## Problem Statement

After the paranoia → discard migration (issue #558), the `destroy` override on `Campaign` and `Attack` unconditionally returns `self`:

```ruby
def destroy
  return self if discarded?
  with_transaction_returning_status do
    run_callbacks(:destroy) { discard }
  end
  self  # <-- always self, even on callback halt
end
```

ActiveRecord's contract is that `destroy` returns `false` (or the frozen record) when a `before_destroy` callback throws `:abort` or returns `false`. Paranoia preserved this. Our override silently drops the contract:

- Callers using `if record.destroy ... else flash error ...` will see a truthy return and proceed as if destroy succeeded, even when the callback halted the operation.
- `destroy!` downstream correctly raises because `discarded?` is `false` after the halt, but `destroy` is still a silent-failure foot-gun.

## Findings

- **Source**: ce:review run `20260419-191817-0c8476b9` — correctness-reviewer (`correctness-001`, conf 0.72), kieran-rails-reviewer (`kieran-rails-001`, conf 0.85). Cross-reviewer agreement.
- **Evidence**: `app/models/campaign.rb:106-112`, `app/models/attack.rb:131-137`.
- **Impact**: Any `before_destroy` callback (current or future) that halts destruction is silently swallowed for callers that check the return value. No observed production issue today because no current callback returns `:abort`, but the contract breakage is latent.

## Proposed Solutions

### Option A: Respect `with_transaction_returning_status` return value (Recommended)

```ruby
def destroy
  return self if discarded?
  result = with_transaction_returning_status do
    run_callbacks(:destroy) { discard }
  end
  result ? self : false
end
```

- **Pros**: Matches ActiveRecord's `destroy` contract exactly. `destroy!` logic still works because `destroy` returning `false` leaves `discarded?` false, triggering the `RecordNotDestroyed` raise.
- **Cons**: Slight behavior change for tests that do `expect { x.destroy }.to ...` against the return value. Need to verify no test relies on the always-self return.
- **Effort**: Small.
- **Risk**: Low, once paired with a regression test that halts a `before_destroy` and asserts the returned value.

### Option B: Leave as-is and document

- **Pros**: Zero behavior change.
- **Cons**: Contract drift is permanent and undetectable until a future `before_destroy` is added that expects the standard AR return.
- **Effort**: None.
- **Risk**: Medium — the next developer adding a `before_destroy` won't know their `:abort` is swallowed until they debug a production incident.

## Recommendation

Option A. The fix is three lines and aligns the model with ActiveRecord's documented contract.

**Note added during triage (2026-04-19):** The follow-up PR review (pr-review-toolkit) surfaced a related partial-cascade-rollback concern (silent-failure-hunter finding #3). When a child `Attack.destroy` callback throws `:abort` during a `Campaign.destroy` cascade, some children may already be discarded before the abort, and `with_transaction_returning_status` does NOT roll back because `:abort` doesn't raise. Consider extending this fix to also call `raise ActiveRecord::Rollback` inside the transaction when the destroy chain halts. Test coverage should include a child-abort scenario that asserts no partial state remains after a halted cascade.

## Test Plan

- Add a spec that stubs a `before_destroy` callback to throw `:abort`, then asserts:
  - `campaign.destroy` returns `false` (not `self`).
  - `campaign.reload.deleted_at` is still `nil`.
  - `campaign.destroy!` raises `ActiveRecord::RecordNotDestroyed`.
- Same for `Attack`.
- Verify all existing specs still pass.

## Related

- Origin: Issue [#558](https://github.com/unclesp1d3r/CipherSwarm/issues/558)
- Related: todo 016 (concern extraction — this fix should land in the concern once extracted).
