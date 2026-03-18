import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { application, registerController } from "../setup";

// Mock tus-js-client
const mockStart = vi.fn();
const mockAbort = vi.fn();
const mockFindPreviousUploads = vi.fn().mockResolvedValue([]);
const mockResumeFromPreviousUpload = vi.fn();

vi.mock("tus-js-client", () => ({
  Upload: vi.fn().mockImplementation((file, options) => {
    const instance = {
      file,
      options,
      url: null,
      start: mockStart,
      abort: mockAbort,
      findPreviousUploads: mockFindPreviousUploads,
      resumeFromPreviousUpload: mockResumeFromPreviousUpload,
    };
    // Store reference so tests can trigger callbacks
    vi.mocked(instance).start.mockImplementation(() => {
      // Simulate starting - controller code calls start() after findPreviousUploads
    });
    return instance;
  }),
}));

import DirectUploadController from "../../../app/javascript/controllers/direct_upload_controller";
import * as tus from "tus-js-client";

describe("DirectUploadController", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockFindPreviousUploads.mockResolvedValue([]);

    // Note: This is a static test fixture, not user-controlled input
    document.body.innerHTML = `
      <form data-controller="direct-upload" data-direct-upload-endpoint-value="/uploads/" data-direct-upload-chunk-size-value="52428800">
        <input type="file" data-direct-upload-target="input" />
        <input type="hidden" data-direct-upload-target="tusUploadUrl" />
        <div class="d-none mt-2" data-direct-upload-target="progress">
          <div class="d-flex justify-content-end mb-1">
            <small class="text-body-secondary d-none" data-direct-upload-target="filename"></small>
          </div>
          <div class="progress">
            <div class="progress-bar progress-bar-striped progress-bar-animated"
                 data-direct-upload-target="progressBar"
                 style="width: 0%" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100"></div>
          </div>
        </div>
        <p class="form-text d-none" data-direct-upload-target="status"></p>
        <button type="submit" data-direct-upload-target="submit">Submit</button>
      </form>
    `;

    registerController("direct-upload", DirectUploadController);
  });

  afterEach(() => {
    document.body.innerHTML = "";
  });

  function getController() {
    const form = document.querySelector('[data-controller="direct-upload"]');
    return application.getControllerForElementAndIdentifier(form, "direct-upload");
  }

  function simulateFileSelect(fileName = "test.txt", size = 1024) {
    const file = new File(["x"], fileName);
    Object.defineProperty(file, "size", { value: size });
    const input = document.querySelector('[data-direct-upload-target="input"]');
    Object.defineProperty(input, "files", { value: [file], configurable: true });
    input.dispatchEvent(new Event("change"));
    return file;
  }

  function getTusOptions() {
    return tus.Upload.mock.calls[0]?.[1];
  }

  it("connects successfully", () => {
    expect(getController()).toBeTruthy();
  });

  describe("handleFileSelect", () => {
    it("creates a tus upload with correct endpoint and chunk size", () => {
      simulateFileSelect();

      expect(tus.Upload).toHaveBeenCalledTimes(1);
      const options = getTusOptions();
      expect(options.endpoint).toBe("/uploads/");
      expect(options.chunkSize).toBe(52428800);
    });

    it("displays filename with human-readable size", () => {
      simulateFileSelect("wordlist.txt", 5368709120); // 5 GB

      const filename = document.querySelector(
        '[data-direct-upload-target="filename"]',
      );
      expect(filename.textContent).toMatch(/wordlist\.txt/);
      expect(filename.textContent).toMatch(/5\.00 GB/);
    });

    it("disables submit button and shows preparing status", () => {
      simulateFileSelect();

      const submit = document.querySelector(
        '[data-direct-upload-target="submit"]',
      );
      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );
      expect(submit.disabled).toBe(true);
      expect(status.textContent).toBe("Preparing\u2026");
    });

    it("shows progress bar", () => {
      simulateFileSelect();

      const progress = document.querySelector(
        '[data-direct-upload-target="progress"]',
      );
      expect(progress.classList.contains("d-none")).toBe(false);
    });

    it("calls findPreviousUploads and start", async () => {
      simulateFileSelect();

      // Wait for the promise chain
      await Promise.resolve();

      expect(mockFindPreviousUploads).toHaveBeenCalled();
      expect(mockStart).toHaveBeenCalled();
    });

    it("sets removeFingerprintOnSuccess to true", () => {
      simulateFileSelect();
      const options = getTusOptions();
      expect(options.removeFingerprintOnSuccess).toBe(true);
    });

    it("aborts existing upload when re-selecting a file", () => {
      simulateFileSelect("first.txt");
      simulateFileSelect("second.txt");

      expect(mockAbort).toHaveBeenCalledWith(true);
      expect(tus.Upload).toHaveBeenCalledTimes(2);
    });
  });

  describe("onProgress callback", () => {
    it("updates progress bar and status text", () => {
      simulateFileSelect();

      const options = getTusOptions();
      options.onProgress(42000, 100000);

      const bar = document.querySelector(
        '[data-direct-upload-target="progressBar"]',
      );
      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );
      expect(bar.style.width).toBe("42%");
      expect(bar.getAttribute("aria-valuenow")).toBe("42");
      expect(status.textContent).toBe("Uploading\u2026 42%");
    });
  });

  describe("onSuccess callback", () => {
    it("sets progress to 100% and re-enables submit", () => {
      simulateFileSelect();

      const uploadInstance = tus.Upload.mock.results[0].value;
      uploadInstance.url = "http://localhost:3000/uploads/abc123";

      const options = getTusOptions();
      options.onSuccess();

      const bar = document.querySelector(
        '[data-direct-upload-target="progressBar"]',
      );
      const submit = document.querySelector(
        '[data-direct-upload-target="submit"]',
      );
      const hidden = document.querySelector(
        '[data-direct-upload-target="tusUploadUrl"]',
      );

      expect(bar.style.width).toBe("100%");
      expect(bar.classList.contains("progress-bar-striped")).toBe(false);
      expect(submit.disabled).toBe(false);
      expect(hidden.value).toBe("http://localhost:3000/uploads/abc123");
    });

    it("shows ready status with check icon", () => {
      simulateFileSelect();

      const options = getTusOptions();
      options.onSuccess();

      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );
      expect(status.textContent).toContain("Upload complete");
      expect(status.querySelector(".bi-check-circle-fill")).toBeTruthy();
    });

    it("removes file input name attribute to prevent double upload", () => {
      const input = document.querySelector(
        '[data-direct-upload-target="input"]',
      );
      input.setAttribute("name", "word_list[file]");

      simulateFileSelect();
      const options = getTusOptions();
      options.onSuccess();

      expect(input.hasAttribute("name")).toBe(false);
    });
  });

  describe("onError callback", () => {
    it("hides progress bar, shows error, re-enables submit", () => {
      simulateFileSelect();

      const options = getTusOptions();
      options.onError(new Error("Network timeout"));

      const progress = document.querySelector(
        '[data-direct-upload-target="progress"]',
      );
      const submit = document.querySelector(
        '[data-direct-upload-target="submit"]',
      );
      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );

      expect(progress.classList.contains("d-none")).toBe(true);
      expect(status.textContent).toContain("Upload failed: Network timeout");
      expect(status.classList.contains("text-danger")).toBe(true);
      expect(submit.disabled).toBe(false);
    });
  });

  describe("resume", () => {
    it("resumes from previous upload when available", async () => {
      const previousUpload = { uploadUrl: "http://localhost/uploads/prev123" };
      mockFindPreviousUploads.mockResolvedValue([previousUpload]);

      simulateFileSelect();
      await Promise.resolve();

      expect(mockResumeFromPreviousUpload).toHaveBeenCalledWith(previousUpload);
    });
  });

  describe("disconnect", () => {
    it("aborts in-progress upload", () => {
      simulateFileSelect();
      const controller = getController();
      controller.disconnect();
      expect(mockAbort).toHaveBeenCalled();
    });
  });
});
