import {describe, it, expect, beforeEach, afterEach, vi} from "vitest";
import {application, registerController} from "../setup";
import ToastController from "../../../app/javascript/controllers/toast_controller";

// Mock Bootstrap Toast
const mockShow = vi.fn();
const mockDispose = vi.fn();

vi.mock("bootstrap", () => ({
  Toast: vi.fn().mockImplementation(function (element, options) {
    this.element = element;
    this.options = options;
    this.show = mockShow;
    this.dispose = mockDispose;
    return this;
  })
}));

describe("ToastController", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    // Note: This is a static test fixture, not user-controlled input
    document.body.innerHTML = `
      <div class="toast"
           data-controller="toast"
           data-toast-autohide-value="true"
           data-toast-delay-value="5000"
           role="alert">
        <div class="toast-body">Test message</div>
        <button type="button" data-bs-dismiss="toast">Close</button>
      </div>
    `;

    registerController("toast", ToastController);
  });

  afterEach(() => {
    document.body.innerHTML = "";
  });

  function getToastElement() {
    return document.querySelector('[data-controller="toast"]');
  }

  function getController() {
    const element = getToastElement();
    return application.getControllerForElementAndIdentifier(element, "toast");
  }

  it("connects successfully", () => {
    const controller = getController();
    expect(controller).toBeTruthy();
  });

  it("shows the toast on connect", () => {
    expect(mockShow).toHaveBeenCalledTimes(1);
  });

  it("has default autohide value of true", () => {
    const controller = getController();
    expect(controller.autohideValue).toBe(true);
  });

  it("has default delay value of 5000", () => {
    const controller = getController();
    expect(controller.delayValue).toBe(5000);
  });

  it("removes element from DOM when hidden.bs.toast fires", () => {
    const element = getToastElement();
    expect(document.body.contains(element)).toBe(true);

    element.dispatchEvent(new Event("hidden.bs.toast"));

    expect(document.body.contains(element)).toBe(false);
  });

  it("disposes toast on disconnect", () => {
    const controller = getController();
    controller.disconnect();
    expect(mockDispose).toHaveBeenCalledTimes(1);
  });

  it("supports multiple toasts displayed simultaneously", () => {
    // Add a second toast to the DOM using safe DOM methods
    const secondToast = document.createElement("div");
    secondToast.classList.add("toast");
    secondToast.setAttribute("data-controller", "toast");
    secondToast.setAttribute("data-toast-autohide-value", "true");
    secondToast.setAttribute("data-toast-delay-value", "5000");
    secondToast.setAttribute("role", "alert");
    const toastBody = document.createElement("div");
    toastBody.classList.add("toast-body");
    toastBody.textContent = "Second message";
    secondToast.appendChild(toastBody);
    document.body.appendChild(secondToast);

    // Re-register to connect the new element
    registerController("toast", ToastController);

    const toasts = document.querySelectorAll('[data-controller="toast"]');
    expect(toasts.length).toBe(2);
    // Both toasts should have triggered show
    expect(mockShow).toHaveBeenCalledTimes(2);
  });
});
