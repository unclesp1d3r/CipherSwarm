/*
 * SPDX-FileCopyrightText:  2024 UncleSp1d3r
 * SPDX-License-Identifier: MPL-2.0
 */

import { Controller } from "@hotwired/stimulus";
import * as tus from "tus-js-client";

// Connects to data-controller="direct-upload"
// Handles resumable file uploads via tus protocol (tusd Go sidecar) for files
// of any size (100+ GB). Supports auto-resume after network failure via
// localStorage fingerprinting.
export default class extends Controller {
  static targets = [
    "input",
    "progress",
    "progressBar",
    "status",
    "submit",
    "filename",
    "tusUploadUrl",
  ];
  static values = {
    endpoint: { type: String, default: "/uploads/" },
    chunkSize: { type: Number, default: 52428800 }, // 50 MB
  };

  connect() {
    this.upload = null;
    this._lastProgressUpdate = 0;
    this.boundHandleFileSelect = this.handleFileSelect.bind(this);
    this.inputTarget.addEventListener("change", this.boundHandleFileSelect);
  }

  disconnect() {
    this.inputTarget.removeEventListener("change", this.boundHandleFileSelect);
    if (this.upload) {
      this.upload.abort();
      this.upload = null;
    }
  }

  handleFileSelect() {
    const file = this.inputTarget.files[0];
    if (!file) return;

    // Abort any in-progress upload and clean up server-side partial
    if (this.upload) {
      this.upload.abort(true);
      this.upload = null;
    }

    this.showFilename(file);
    this.startUpload(file);
  }

  startUpload(file) {
    this.showStatus("Preparing\u2026");
    this.showProgressBar();
    this.submitTarget.disabled = true;

    this.upload = new tus.Upload(file, {
      endpoint: this.endpointValue,
      chunkSize: this.chunkSizeValue,
      retryDelays: [0, 1000, 3000, 5000, 10000, 20000, 30000, 60000],
      removeFingerprintOnSuccess: true,
      metadata: {
        filename: file.name,
        filetype: file.type || "application/octet-stream",
      },

      onProgress: (bytesUploaded, bytesTotal) => {
        // Throttle DOM updates to every 100ms for large files
        const now = Date.now();
        if (now - this._lastProgressUpdate < 100) return;
        this._lastProgressUpdate = now;

        const progress = (bytesUploaded / bytesTotal) * 100;
        this.updateProgressBar(progress);
        this.showStatus(`Uploading\u2026 ${Math.round(progress)}%`);
      },

      onSuccess: () => {
        this.updateProgressBar(100);
        this.progressBarTarget.classList.remove(
          "progress-bar-striped",
          "progress-bar-animated",
        );

        // Store the tus upload URL in the hidden field for form submission
        if (this.hasTusUploadUrlTarget && this.upload.url) {
          this.tusUploadUrlTarget.value = this.upload.url;
        }

        // Prevent double upload: remove name attribute so browser excludes
        // file from the multipart form POST. The file was already uploaded
        // via tus — the form only needs to send the tus URL.
        this.inputTarget.removeAttribute("name");

        this.showReadyStatus();
        this.submitTarget.disabled = false;
      },

      onError: (error) => {
        this.hideProgressBar();
        const message = error.message || "Unknown upload error";
        this.showStatus(
          `Upload failed: ${message}. Select the file again to retry.`,
        );
        this.statusTarget.classList.add("text-danger");
        this.submitTarget.disabled = false;
        this.upload = null;
      },
    });

    this.upload
      .findPreviousUploads()
      .then((previousUploads) => {
        if (!this.upload) return;
        if (previousUploads.length > 0) {
          this.upload.resumeFromPreviousUpload(previousUploads[0]);
          this.showStatus("Resuming upload\u2026");
        }
        this.upload.start();
      })
      .catch((error) => {
        this.hideProgressBar();
        const message = error?.message || "Failed to check for resumable uploads";
        this.showStatus(`Upload failed: ${message}. Select the file again to retry.`);
        this.statusTarget.classList.add("text-danger");
        this.submitTarget.disabled = false;
        this.upload = null;
      });
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

  showReadyStatus() {
    this.statusTarget.textContent = "";
    this.statusTarget.classList.remove("d-none", "text-danger");

    const icon = document.createElement("span");
    icon.className = "bi bi-check-circle-fill text-success me-1";
    icon.setAttribute("aria-hidden", "true");

    this.statusTarget.appendChild(icon);
    this.statusTarget.appendChild(
      document.createTextNode("Upload complete. Ready to submit."),
    );
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
