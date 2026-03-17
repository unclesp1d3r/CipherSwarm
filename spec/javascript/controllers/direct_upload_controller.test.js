import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { application, registerController } from "../setup";

// Mock the override module — we only test the controller's event handling
vi.mock("../../../app/javascript/utils/direct_upload_override", () => ({
  applyChecksumOverride: vi.fn(),
  setFileChecksumThreshold: vi.fn(),
}));

import DirectUploadController from "../../../app/javascript/controllers/direct_upload_controller";
import { setFileChecksumThreshold } from "../../../app/javascript/utils/direct_upload_override";

describe("DirectUploadController", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    // Note: This is a static test fixture, not user-controlled input
    document.body.innerHTML = `
      <form data-controller="direct-upload" data-direct-upload-checksum-threshold-value="1073741824">
        <input type="file" data-direct-upload-target="input" data-direct-upload-url="/uploads" />
        <div class="d-none" data-direct-upload-target="progress">
          <div class="d-flex justify-content-between align-items-center mb-1">
            <small class="text-body-secondary d-none" data-direct-upload-target="phase"></small>
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

  function getForm() {
    return document.querySelector('[data-controller="direct-upload"]');
  }

  function getController() {
    return application.getControllerForElementAndIdentifier(
      getForm(),
      "direct-upload",
    );
  }

  function dispatch(eventName, detail = {}) {
    const event = new CustomEvent(eventName, {
      detail,
      bubbles: true,
      cancelable: true,
    });
    getForm().querySelector("input[type=file]").dispatchEvent(event);
    return event;
  }

  it("connects successfully", () => {
    expect(getController()).toBeTruthy();
  });

  describe("handleInitialize", () => {
    it("shows status, disables submit, and resets error state", () => {
      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );
      status.classList.add("text-danger");

      dispatch("direct-upload:initialize", {
        file: new File(["x"], "test.txt"),
        id: 1,
      });

      expect(status.textContent).toBe("Preparing\u2026");
      expect(status.classList.contains("text-danger")).toBe(false);
      expect(status.classList.contains("d-none")).toBe(false);
      expect(
        document.querySelector('[data-direct-upload-target="submit"]').disabled,
      ).toBe(true);
    });

    it("registers file threshold via setFileChecksumThreshold", () => {
      const file = new File(["x"], "test.txt");
      dispatch("direct-upload:initialize", { file, id: 1 });

      expect(setFileChecksumThreshold).toHaveBeenCalledWith(file, 1073741824);
    });

    it("displays filename with size", () => {
      const file = new File(["x".repeat(5000)], "wordlist.txt");
      dispatch("direct-upload:initialize", { file, id: 1 });

      const filename = document.querySelector(
        '[data-direct-upload-target="filename"]',
      );
      expect(filename.textContent).toMatch(/wordlist\.txt/);
      expect(filename.classList.contains("d-none")).toBe(false);
    });
  });

  describe("handleStart", () => {
    it("shows progress bar with phase label and Uploading status", () => {
      dispatch("direct-upload:start", { id: 1 });

      const progress = document.querySelector(
        '[data-direct-upload-target="progress"]',
      );
      const phase = document.querySelector(
        '[data-direct-upload-target="phase"]',
      );
      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );

      expect(progress.classList.contains("d-none")).toBe(false);
      expect(phase.textContent).toBe("Step 2 of 2");
      expect(status.textContent).toBe("Uploading\u2026 0%");
    });
  });

  describe("handleProgress", () => {
    it("updates progress bar and status text with percentage", () => {
      dispatch("direct-upload:progress", { progress: 42.7, id: 1 });

      const bar = document.querySelector(
        '[data-direct-upload-target="progressBar"]',
      );
      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );

      expect(bar.style.width).toBe("42.7%");
      expect(bar.getAttribute("aria-valuenow")).toBe("43");
      expect(status.textContent).toBe("Uploading\u2026 43%");
    });
  });

  describe("handleError", () => {
    it("hides progress, shows actionable error, re-enables submit", () => {
      dispatch("direct-upload:start", { id: 1 });
      const event = dispatch("direct-upload:error", {
        error: "Network timeout",
        id: 1,
      });

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
      expect(status.textContent).toBe(
        "Upload failed: Network timeout. Click Submit to retry.",
      );
      expect(status.classList.contains("text-danger")).toBe(true);
      expect(submit.disabled).toBe(false);
      expect(event.defaultPrevented).toBe(true);
    });
  });

  describe("handleEnd", () => {
    it("shows Processing with spinner when no error occurred", () => {
      dispatch("direct-upload:end", { id: 1 });

      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );
      expect(status.textContent).toBe("Processing\u2026");
      expect(status.querySelector(".spinner-border")).toBeTruthy();
    });

    it("sets progress bar to 100% and removes animation", () => {
      dispatch("direct-upload:end", { id: 1 });

      const bar = document.querySelector(
        '[data-direct-upload-target="progressBar"]',
      );
      expect(bar.style.width).toBe("100%");
      expect(bar.classList.contains("progress-bar-striped")).toBe(false);
      expect(bar.classList.contains("progress-bar-animated")).toBe(false);
    });

    it("skips Processing for errored upload IDs", () => {
      dispatch("direct-upload:error", { error: "fail", id: 42 });
      dispatch("direct-upload:end", { id: 42 });

      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );
      expect(status.textContent).toContain("Upload failed: fail");
    });
  });

  describe("handleChecksumProgress", () => {
    it("shows hashing progress with phase label for matching file", () => {
      const file = new File(["content"], "wordlist.txt");

      const input = document.querySelector(
        '[data-direct-upload-target="input"]',
      );
      Object.defineProperty(input, "files", { value: [file], writable: false });

      document.dispatchEvent(
        new CustomEvent("direct-upload:checksum-progress", {
          detail: { file, progress: 55 },
        }),
      );

      const progress = document.querySelector(
        '[data-direct-upload-target="progress"]',
      );
      const bar = document.querySelector(
        '[data-direct-upload-target="progressBar"]',
      );
      const status = document.querySelector(
        '[data-direct-upload-target="status"]',
      );
      const phase = document.querySelector(
        '[data-direct-upload-target="phase"]',
      );

      expect(progress.classList.contains("d-none")).toBe(false);
      expect(bar.style.width).toBe("55%");
      expect(status.textContent).toBe("Preparing\u2026 55%");
      expect(phase.textContent).toBe("Step 1 of 2");
    });

    it("ignores checksum progress for non-matching file", () => {
      const file = new File(["content"], "other.txt");

      document.dispatchEvent(
        new CustomEvent("direct-upload:checksum-progress", {
          detail: { file, progress: 50 },
        }),
      );

      const progress = document.querySelector(
        '[data-direct-upload-target="progress"]',
      );
      expect(progress.classList.contains("d-none")).toBe(true);
    });
  });

  describe("disconnect", () => {
    it("removes all event listeners", () => {
      const controller = getController();
      controller.disconnect();

      dispatch("direct-upload:start", { id: 1 });
      const submit = document.querySelector(
        '[data-direct-upload-target="submit"]',
      );
      expect(submit.disabled).toBe(false);
    });
  });
});
