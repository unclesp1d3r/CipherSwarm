/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

// COMPATIBILITY NOTE: FileChecksum is NOT exported from @rails/activestorage's
// public ESM entrypoint (which only exports DirectUpload, start, etc.).
// We import from the internal source path. This is coupled to the package's
// internal file structure and may break on major activestorage upgrades.
// Pinned to @rails/activestorage 7.x / 8.x layout — verify after upgrades.
import { FileChecksum } from "@rails/activestorage/src/file_checksum";

/*
 * Patches FileChecksum.create to skip the client-side MD5 hash for files
 * exceeding a configurable threshold.
 *
 * WHY THIS EXISTS:
 * Active Storage computes an MD5 checksum of the entire file client-side
 * (SparkMD5, 2 MB chunks via FileReader) before the upload begins. For files
 * >10-20 GB this silently stalls the browser — no error, no network requests,
 * just a frozen submit button. See GitHub issue #747.
 *
 * HOW IT WORKS:
 * The patch stores threshold in a module-scoped WeakMap keyed by File object.
 * The Stimulus controller sets the threshold for each file before the upload
 * starts (via direct-upload:initialize). This avoids the global mutable
 * threshold problem where the last-connected controller wins.
 *
 * INTEGRITY TRADE-OFFS:
 * When checksum is skipped, `checksum` in `active_storage_blobs` will be NULL.
 * - Disk service: skips `ensure_integrity_of` when checksum is nil — no
 *   server-side digest verification for the upload.
 * - S3-compatible services: Content-MD5 header is omitted — S3 will not
 *   verify the upload digest, but the PUT will succeed.
 * - In both cases, corruption during transfer will NOT be detected.
 * - VerifyChecksumJob computes checksums post-upload for large files.
 */

const fileThresholds = new WeakMap();
let applied = false;

/**
 * Registers a checksum threshold for a specific file. Files larger than
 * thresholdBytes will skip client-side MD5 hashing.
 *
 * @param {File} file - The file to configure.
 * @param {number} thresholdBytes - Size threshold in bytes.
 */
export function setFileChecksumThreshold(file, thresholdBytes) {
  fileThresholds.set(file, thresholdBytes);
}

/**
 * Applies the checksum override patch to FileChecksum.create.
 * Safe to call multiple times — the patch is applied only once.
 * Threshold is resolved per-file from the WeakMap set by
 * setFileChecksumThreshold, so multiple controllers with different
 * thresholds on the same page work correctly.
 */
export function applyChecksumOverride() {
  if (applied) return;
  applied = true;

  FileChecksum.create = function (file, callback) {
    const threshold = fileThresholds.get(file);
    if (threshold != null && file.size > threshold) {
      callback(null, null);
      return;
    }

    // For files under threshold, wrap to emit hashing progress events.
    // We instantiate FileChecksum directly and override readNextChunk on
    // the instance to dispatch progress after each chunk is queued.
    const instance = new FileChecksum(file);
    const originalReadNextChunk = instance.readNextChunk.bind(instance);
    const totalChunks = instance.chunkCount;

    instance.readNextChunk = function () {
      const result = originalReadNextChunk();
      if (totalChunks > 0) {
        const progress = Math.min((instance.chunkIndex / totalChunks) * 100, 100);
        document.dispatchEvent(
          new CustomEvent("direct-upload:checksum-progress", {
            detail: { file, progress },
          }),
        );
      }
      return result;
    };

    instance.create(callback);
  };
}
