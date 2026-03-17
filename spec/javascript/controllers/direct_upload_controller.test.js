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
        <div class="progress d-none" data-direct-upload-target="progress">
          <div class="progress-bar" data-direct-upload-target="progressBar"
               style="width: 0%" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100"></div>
        </div>
        <p data-direct-upload-target="status"></p>
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
    return application.getControllerForElementAndIdentifier(getForm(), "direct-upload");
  }

  function dispatch(eventName, detail = {}) {
    const event = new CustomEvent(eventName, { detail, bubbles: true, cancelable: true });
    getForm().querySelector("input[type=file]").dispatchEvent(event);
    return event;
  }

  it("connects successfully", () => {
    expect(getController()).toBeTruthy();
  });

  describe("handleInitialize", () => {
    it("sets status to Preparing and resets error state", () => {
      const status = document.querySelector('[data-direct-upload-target="status"]');
      status.classList.add("text-danger");

      dispatch("direct-upload:initialize", { file: new File(["x"], "test.txt"), id: 1 });

      expect(status.textContent).toBe("Preparing\u2026");
      expect(status.classList.contains("text-danger")).toBe(false);
    });

    it("registers file threshold via setFileChecksumThreshold", () => {
      const file = new File(["x"], "test.txt");
      dispatch("direct-upload:initialize", { file, id: 1 });

      expect(setFileChecksumThreshold).toHaveBeenCalledWith(file, 1073741824);
    });
  });

  describe("handleStart", () => {
    it("shows progress bar, disables submit, shows Uploading", () => {
      dispatch("direct-upload:start", { id: 1 });

      const progress = document.querySelector('[data-direct-upload-target="progress"]');
      const submit = document.querySelector('[data-direct-upload-target="submit"]');
      const status = document.querySelector('[data-direct-upload-target="status"]');

      expect(progress.classList.contains("d-none")).toBe(false);
      expect(submit.disabled).toBe(true);
      expect(status.textContent).toBe("Uploading\u2026");
    });
  });

  describe("handleProgress", () => {
    it("updates progress bar width and aria-valuenow", () => {
      dispatch("direct-upload:progress", { progress: 42.7, id: 1 });

      const bar = document.querySelector('[data-direct-upload-target="progressBar"]');
      expect(bar.style.width).toBe("42.7%");
      expect(bar.getAttribute("aria-valuenow")).toBe("43");
    });
  });

  describe("handleError", () => {
    it("hides progress, shows error, re-enables submit", () => {
      dispatch("direct-upload:start", { id: 1 });
      const event = dispatch("direct-upload:error", { error: "Network timeout", id: 1 });

      const progress = document.querySelector('[data-direct-upload-target="progress"]');
      const submit = document.querySelector('[data-direct-upload-target="submit"]');
      const status = document.querySelector('[data-direct-upload-target="status"]');

      expect(progress.classList.contains("d-none")).toBe(true);
      expect(status.textContent).toBe("Network timeout");
      expect(status.classList.contains("text-danger")).toBe(true);
      expect(submit.disabled).toBe(false);
      expect(event.defaultPrevented).toBe(true);
    });
  });

  describe("handleEnd", () => {
    it("shows Processing when no error occurred", () => {
      dispatch("direct-upload:end", { id: 1 });

      const status = document.querySelector('[data-direct-upload-target="status"]');
      expect(status.textContent).toBe("Processing\u2026");
    });

    it("skips Processing for errored upload IDs", () => {
      dispatch("direct-upload:error", { error: "fail", id: 42 });
      dispatch("direct-upload:end", { id: 42 });

      const status = document.querySelector('[data-direct-upload-target="status"]');
      expect(status.textContent).toBe("fail");
    });
  });

  describe("handleChecksumProgress", () => {
    it("shows hashing progress for matching file", () => {
      const file = new File(["content"], "wordlist.txt");

      // Simulate file selection by setting input.files
      const input = document.querySelector('[data-direct-upload-target="input"]');
      Object.defineProperty(input, "files", { value: [file], writable: false });

      document.dispatchEvent(
        new CustomEvent("direct-upload:checksum-progress", {
          detail: { file, progress: 55 },
        }),
      );

      const progress = document.querySelector('[data-direct-upload-target="progress"]');
      const bar = document.querySelector('[data-direct-upload-target="progressBar"]');
      const status = document.querySelector('[data-direct-upload-target="status"]');
      const submit = document.querySelector('[data-direct-upload-target="submit"]');

      expect(progress.classList.contains("d-none")).toBe(false);
      expect(bar.style.width).toBe("55%");
      expect(status.textContent).toBe("Preparing\u2026 55%");
      expect(submit.disabled).toBe(true);
    });

    it("ignores checksum progress for non-matching file", () => {
      const file = new File(["content"], "other.txt");

      document.dispatchEvent(
        new CustomEvent("direct-upload:checksum-progress", {
          detail: { file, progress: 50 },
        }),
      );

      const progress = document.querySelector('[data-direct-upload-target="progress"]');
      expect(progress.classList.contains("d-none")).toBe(true);
    });
  });

  describe("disconnect", () => {
    it("removes all event listeners", () => {
      const controller = getController();
      controller.disconnect();

      // After disconnect, events should not update the DOM
      dispatch("direct-upload:start", { id: 1 });
      const submit = document.querySelector('[data-direct-upload-target="submit"]');
      expect(submit.disabled).toBe(false);
    });
  });
});
