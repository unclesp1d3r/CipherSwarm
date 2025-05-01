// HTMX Toast Notifications
document.body.addEventListener("showMessage", function (evt) {
  const toast = document.createElement("div");
  toast.className = `p-4 mb-4 rounded-md toast-enter ${
    evt.detail.type === "error"
      ? "bg-red-100 text-red-700"
      : "bg-green-100 text-green-700"
  }`;
  toast.textContent = evt.detail.message;

  const container = document.getElementById("toast-container");
  container.appendChild(toast);

  // Trigger enter animation
  requestAnimationFrame(() => {
    toast.classList.remove("toast-enter");
    toast.classList.add("toast-enter-active");
  });

  // Remove toast after delay
  setTimeout(() => {
    toast.classList.remove("toast-enter-active");
    toast.classList.add("toast-exit");
    requestAnimationFrame(() => {
      toast.classList.add("toast-exit-active");
      setTimeout(() => toast.remove(), 200);
    });
  }, 5000);
});

// Progress Bar Updates
document.body.addEventListener("updateProgress", function (evt) {
  const progressBar = document.querySelector(
    `#progress-${evt.detail.id} .progress-bar-fill`
  );
  if (progressBar) {
    progressBar.style.width = `${evt.detail.progress}%`;
  }
});

// Modal Management
document.body.addEventListener("showModal", function (evt) {
  const modal = document.querySelector(`#${evt.detail.id}`);
  if (modal) {
    modal.classList.remove("modal-exit", "modal-exit-active");
    modal.classList.add("modal-enter");
    requestAnimationFrame(() => {
      modal.classList.remove("modal-enter");
      modal.classList.add("modal-enter-active");
    });
  }
});

document.body.addEventListener("hideModal", function (evt) {
  const modal = document.querySelector(`#${evt.detail.id}`);
  if (modal) {
    modal.classList.remove("modal-enter-active");
    modal.classList.add("modal-exit");
    requestAnimationFrame(() => {
      modal.classList.add("modal-exit-active");
      setTimeout(() => modal.remove(), 200);
    });
  }
});

// Form Validation
document.body.addEventListener("validateForm", function (evt) {
  const form = evt.detail.form;
  const isValid = form.checkValidity();

  if (!isValid) {
    evt.preventDefault();

    // Show validation messages
    Array.from(form.elements).forEach((element) => {
      if (!element.validity.valid) {
        element.classList.add("border-red-500");

        // Add error message
        const errorDiv = document.createElement("div");
        errorDiv.className = "text-red-500 text-sm mt-1";
        errorDiv.textContent = element.validationMessage;
        element.parentNode.appendChild(errorDiv);
      }
    });

    // Trigger error toast
    const event = new CustomEvent("showMessage", {
      detail: {
        type: "error",
        message: "Please check the form for errors",
      },
    });
    document.body.dispatchEvent(event);
  }
});

// Confirmation Dialogs
document.body.addEventListener("confirm", function (evt) {
  const message = evt.detail.message || "Are you sure you want to proceed?";
  if (!confirm(message)) {
    evt.preventDefault();
  }
});

// Auto-refresh
function setupAutoRefresh(selector, interval) {
  const element = document.querySelector(selector);
  if (element && element.hasAttribute("hx-get")) {
    setInterval(() => {
      element.setAttribute("hx-trigger", "load");
      htmx.process(element);
    }, interval);
  }
}

// Setup auto-refresh for active elements
document.addEventListener("DOMContentLoaded", function () {
  // Auto-refresh agent statuses every 30 seconds
  setupAutoRefresh("#agents-table", 30000);

  // Auto-refresh task progress every 5 seconds
  setupAutoRefresh("#tasks-table", 5000);
});
