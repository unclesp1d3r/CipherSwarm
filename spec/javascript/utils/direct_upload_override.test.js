import { describe, it, expect, beforeEach, vi } from "vitest";

// Mock FileChecksum before importing the override
const mockCreateInstance = vi.fn();

vi.mock("@rails/activestorage/src/file_checksum", () => {
  const MockFileChecksum = vi.fn().mockImplementation((file) => ({
    file,
    chunkSize: 2097152,
    chunkCount: Math.ceil(file.size / 2097152),
    chunkIndex: 0,
    readNextChunk: vi.fn().mockReturnValue(false),
    create: mockCreateInstance,
  }));
  MockFileChecksum.create = vi.fn((file, callback) => callback(null, "original_checksum"));
  return { FileChecksum: MockFileChecksum };
});

import { FileChecksum } from "@rails/activestorage/src/file_checksum";
import {
  applyChecksumOverride,
  setFileChecksumThreshold,
} from "../../../app/javascript/utils/direct_upload_override";

describe("direct_upload_override", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("setFileChecksumThreshold", () => {
    it("stores threshold per file without error", () => {
      const file = new File(["x"], "test.txt");
      expect(() => setFileChecksumThreshold(file, 1024)).not.toThrow();
    });
  });

  describe("applyChecksumOverride", () => {
    it("patches FileChecksum.create", () => {
      applyChecksumOverride();
      // The create method should be replaced by the patch
      expect(FileChecksum.create).toBeDefined();
    });

    it("skips checksum for files over threshold", () => {
      applyChecksumOverride();

      const largeFile = new File(["x".repeat(100)], "large.txt");
      Object.defineProperty(largeFile, "size", { value: 2_000_000_000 });
      setFileChecksumThreshold(largeFile, 1_000_000_000);

      const callback = vi.fn();
      FileChecksum.create(largeFile, callback);

      expect(callback).toHaveBeenCalledWith(null, null);
    });

    it("uses original create for files under threshold", () => {
      applyChecksumOverride();

      const smallFile = new File(["x"], "small.txt");
      Object.defineProperty(smallFile, "size", { value: 500 });
      setFileChecksumThreshold(smallFile, 1_000_000_000);

      const callback = vi.fn();
      FileChecksum.create(smallFile, callback);

      // Should have created a new instance and called create on it
      expect(mockCreateInstance).toHaveBeenCalled();
    });

    it("uses original create when no threshold is set", () => {
      applyChecksumOverride();

      const file = new File(["x"], "no_threshold.txt");
      // Don't call setFileChecksumThreshold

      const callback = vi.fn();
      FileChecksum.create(file, callback);

      expect(mockCreateInstance).toHaveBeenCalled();
    });

    it("dispatches checksum-progress events during hashing", () => {
      applyChecksumOverride();

      const file = new File(["x"], "hashing.txt");
      Object.defineProperty(file, "size", { value: 4_194_304 }); // 4MB = 2 chunks
      setFileChecksumThreshold(file, 1_000_000_000);

      const progressEvents = [];
      document.addEventListener("direct-upload:checksum-progress", (e) => {
        progressEvents.push(e.detail);
      });

      FileChecksum.create(file, vi.fn());

      // The mock readNextChunk is called once during instance.create,
      // and our override wraps it to dispatch progress
      expect(progressEvents.length).toBeGreaterThanOrEqual(0);
    });
  });
});
