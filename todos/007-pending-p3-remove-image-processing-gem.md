---
status: pending
priority: p3
issue_id: '007'
tags: [code-review, dependencies, cleanup]
dependencies: ['005']
---

# Evaluate image_processing Gem Usage

## Problem Statement

The `image_processing` gem (~> 1.14) is in the Gemfile but no code in `app/` or `lib/` directly uses `ImageProcessing`, `MiniMagick`, or `Vips`. The grep hits on models like `hash_list.rb` are for Active Storage's `representation` and `variant` methods which implicitly require image_processing. Since CipherSwarm handles wordlists, rule files, and hash lists (not images), this gem and its native dependencies (libvips/ImageMagick) are likely unnecessary overhead in the Docker image.

## Findings

- **Source**: dependency usage analysis
- **Evidence**: `grep -rl "ImageProcessing\|MiniMagick\|Vips" app/ lib/` returns 0 direct hits. Indirect usage via Active Storage `variant`/`representation` found in models.
- **Impact**: Unnecessary native library in Docker image (~50MB), unused dependency

## Proposed Solutions

### Option A: Remove after Active Storage migration complete

- Depends on todo #005 (Active Storage cleanup)
- Once AS is fully removed, image_processing can go too
- **Effort**: Trivial (after #005)
- **Risk**: None

### Option B: Remove now, test for breakage

- Remove gem, run full test suite
- If Active Storage variants aren't used for display, it will pass
- **Effort**: Small
- **Risk**: Low — easy to revert

## Technical Details

- **Affected files**: `Gemfile`, Dockerfile (native deps)
- **Depends on**: #005 (Active Storage cleanup)
