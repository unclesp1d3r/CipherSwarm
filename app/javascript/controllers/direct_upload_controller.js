/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import { Controller } from "@hotwired/stimulus";
import {
  applyChecksumOverride,
  setFileChecksumThreshold,
} from "../utils/direct_upload_override";

// Connects to data-controller="direct-upload"
// Shows two-phase upload progress for Active Storage direct uploads:
//   Phase 1: "Preparing..." — client-side checksum hashing (files < threshold)
//   Phase 2: "Uploading..."  — file transfer to storage service
// Handles errors with actionable messages and re-enabled submit for retry.
export default class extends Controller {
  static targets = [
    "input",
    "progress",
    "progressBar",
    "status",
    "submit",
    "phase",
    "filename",
  ];
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
    document.addEventListener(
      "direct-upload:checksum-progress",
      this.onChecksumProgress,
    );
  }

  disconnect() {
    this.element.removeEventListener(
      "direct-upload:initialize",
      this.onInitialize,
    );
    this.element.removeEventListener("direct-upload:start", this.onStart);
    this.element.removeEventListener("direct-upload:progress", this.onProgress);
    this.element.removeEventListener("direct-upload:error", this.onError);
    this.element.removeEventListener("direct-upload:end", this.onEnd);
    document.removeEventListener(
      "direct-upload:checksum-progress",
      this.onChecksumProgress,
    );
  }

  handleInitialize(event) {
    const file = event.detail.file;
    if (file) {
      setFileChecksumThreshold(file, this.checksumThresholdValue);
      this.showFilename(file);
    }

    this.showStatus("Preparing\u2026");
    this.submitTarget.disabled = true;
  }

  handleChecksumProgress(event) {
    const file = event.detail.file;
    if (!this.hasInputTarget || !this.inputTarget.files) return;
    if (!Array.from(this.inputTarget.files).includes(file)) return;

    const progress = event.detail.progress;
    this.showProgressBar();
    this.showPhase("Step 1 of 2");
    this.updateProgressBar(progress);
    this.showStatus(`Preparing\u2026 ${Math.round(progress)}%`);
  }

  handleStart() {
    this.showProgressBar();
    this.showPhase("Step 2 of 2");
    this.updateProgressBar(0);
    this.showStatus("Uploading\u2026 0%");
  }

  handleProgress(event) {
    const progress = event.detail.progress;
    this.updateProgressBar(progress);
    this.showStatus(`Uploading\u2026 ${Math.round(progress)}%`);
  }

  handleError(event) {
    event.preventDefault();
    const id = event.detail.id;
    this.erroredUploadIds.add(id);
    this.hideProgressBar();
    this.hidePhase();
    this.showStatus(
      `Upload failed: ${event.detail.error}. Click Submit to retry.`,
    );
    this.statusTarget.classList.add("text-danger");
    this.submitTarget.disabled = false;
  }

  handleEnd(event) {
    const id = event.detail.id;
    if (this.erroredUploadIds.has(id)) {
      this.erroredUploadIds.delete(id);
      return;
    }
    this.hidePhase();
    this.updateProgressBar(100);
    this.progressBarTarget.classList.remove(
      "progress-bar-striped",
      "progress-bar-animated",
    );
    this.showProcessingStatus();
  }

  // -- Private helpers --

  showProgressBar() {
    this.progressTarget.classList.remove("d-none");
  }

  hideProgressBar() {
    this.progressTarget.classList.add("d-none");
  }

  updateProgressBar(progress) {
    this.progressBarTarget.style.width = `${progress}%`;
    this.progressBarTarget.setAttribute(
      "aria-valuenow",
      Math.round(progress).toString(),
    );
  }

  showStatus(text) {
    this.statusTarget.textContent = text;
    this.statusTarget.classList.remove("d-none", "text-danger");
  }

  showProcessingStatus() {
    // Build spinner + text using safe DOM methods (no innerHTML)
    this.statusTarget.textContent = "";
    this.statusTarget.classList.remove("d-none", "text-danger");

    const spinner = document.createElement("span");
    spinner.className = "spinner-border spinner-border-sm me-1";
    spinner.setAttribute("role", "status");
    spinner.setAttribute("aria-hidden", "true");

    this.statusTarget.appendChild(spinner);
    this.statusTarget.appendChild(document.createTextNode("Processing\u2026"));
  }

  showPhase(text) {
    if (!this.hasPhaseTarget) return;
    this.phaseTarget.textContent = text;
    this.phaseTarget.classList.remove("d-none");
  }

  hidePhase() {
    if (!this.hasPhaseTarget) return;
    this.phaseTarget.classList.add("d-none");
  }

  showFilename(file) {
    if (!this.hasFilenameTarget) return;
    const size = this.formatFileSize(file.size);
    this.filenameTarget.textContent = `${file.name} (${size})`;
    this.filenameTarget.classList.remove("d-none");
  }

  formatFileSize(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1073741824) return `${(bytes / 1048576).toFixed(1)} MB`;
    return `${(bytes / 1073741824).toFixed(2)} GB`;
  }
}
