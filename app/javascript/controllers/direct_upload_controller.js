/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import { Controller } from "@hotwired/stimulus";
import { applyChecksumOverride, setFileChecksumThreshold } from "../utils/direct_upload_override";

// Connects to data-controller="direct-upload"
// Shows upload progress for Active Storage direct uploads.
export default class extends Controller {
  static targets = ["input", "progress", "progressBar", "status", "submit"];
  static values = {
    checksumThreshold: { type: Number, default: 1073741824 }, // 1 GB in bytes
  };

  connect() {
    applyChecksumOverride();

    this.erroredUploadIds = new Set();
    this.onInitialize = this.handleInitialize.bind(this);
    this.onStart = this.handleStart.bind(this);
    this.onProgress = this.handleProgress.bind(this);
    this.onError = this.handleError.bind(this);
    this.onEnd = this.handleEnd.bind(this);

    this.onChecksumProgress = this.handleChecksumProgress.bind(this);

    this.element.addEventListener("direct-upload:initialize", this.onInitialize);
    this.element.addEventListener("direct-upload:start", this.onStart);
    this.element.addEventListener("direct-upload:progress", this.onProgress);
    this.element.addEventListener("direct-upload:error", this.onError);
    this.element.addEventListener("direct-upload:end", this.onEnd);
    // Checksum progress is dispatched on document (FileChecksum has no input ref)
    document.addEventListener("direct-upload:checksum-progress", this.onChecksumProgress);
  }

  disconnect() {
    this.element.removeEventListener("direct-upload:initialize", this.onInitialize);
    this.element.removeEventListener("direct-upload:start", this.onStart);
    this.element.removeEventListener("direct-upload:progress", this.onProgress);
    this.element.removeEventListener("direct-upload:error", this.onError);
    this.element.removeEventListener("direct-upload:end", this.onEnd);
    document.removeEventListener("direct-upload:checksum-progress", this.onChecksumProgress);
  }

  handleInitialize(event) {
    // Register the threshold for this specific file so the checksum override
    // can make per-file decisions (scoped, not global).
    const file = event.detail.file;
    if (file) {
      setFileChecksumThreshold(file, this.checksumThresholdValue);
    }

    // Don't hide progress bar — it may already be showing from checksum phase
    this.statusTarget.textContent = "Preparing\u2026";
    this.statusTarget.classList.remove("text-danger");
  }

  handleChecksumProgress(event) {
    // Only react if this controller's input has the file being hashed
    const file = event.detail.file;
    if (!this.hasInputTarget || !this.inputTarget.files) return;
    if (!Array.from(this.inputTarget.files).includes(file)) return;

    const progress = event.detail.progress;
    this.progressTarget.classList.remove("d-none");
    this.submitTarget.disabled = true;
    this.progressBarTarget.style.width = `${progress}%`;
    this.progressBarTarget.setAttribute("aria-valuenow", Math.round(progress).toString());
    this.statusTarget.textContent = `Preparing\u2026 ${Math.round(progress)}%`;
  }

  handleStart() {
    this.progressTarget.classList.remove("d-none");
    this.progressBarTarget.style.width = "0%";
    this.progressBarTarget.setAttribute("aria-valuenow", "0");
    this.submitTarget.disabled = true;
    this.statusTarget.textContent = "Uploading\u2026";
    this.statusTarget.classList.remove("text-danger");
  }

  handleProgress(event) {
    const progress = event.detail.progress;
    this.progressBarTarget.style.width = `${progress}%`;
    this.progressBarTarget.setAttribute("aria-valuenow", Math.round(progress).toString());
  }

  handleError(event) {
    event.preventDefault();
    const id = event.detail.id;
    this.erroredUploadIds.add(id);
    this.progressTarget.classList.add("d-none");
    this.statusTarget.textContent = event.detail.error;
    this.statusTarget.classList.add("text-danger");
    this.submitTarget.disabled = false;
  }

  handleEnd(event) {
    const id = event.detail.id;
    if (this.erroredUploadIds.has(id)) {
      this.erroredUploadIds.delete(id);
      return;
    }
    this.statusTarget.textContent = "Processing\u2026";
  }
}
