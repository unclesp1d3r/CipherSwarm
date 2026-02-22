import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { application, registerController } from "../setup";
import SelectController from "../../../app/javascript/controllers/select_controller";

const mockDestroy = vi.fn();

vi.mock("tom-select", () => ({
  default: vi.fn().mockImplementation(function (element, options) {
    this.element = element;
    this.options = options;
    this.destroy = mockDestroy;
    return this;
  })
}));

// Get mock constructor reference after hoisting
const { default: TomSelect } = await import("tom-select");

describe("SelectController", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    // Note: This is a static test fixture, not user-controlled input
    document.body.innerHTML = `
      <select data-controller="select">
        <option value="0">0 (MD5)</option>
        <option value="1000">1000 (NTLM)</option>
      </select>
    `;

    registerController("select", SelectController);
  });

  afterEach(() => {
    document.body.innerHTML = "";
  });

  function getSelectElement() {
    return document.querySelector('[data-controller="select"]');
  }

  function getController() {
    const element = getSelectElement();
    return application.getControllerForElementAndIdentifier(element, "select");
  }

  it("connects and initializes TomSelect", () => {
    const controller = getController();
    expect(controller).toBeTruthy();
    expect(TomSelect).toHaveBeenCalledTimes(1);
  });

  it("passes default options to TomSelect", () => {
    expect(TomSelect).toHaveBeenCalledWith(
      getSelectElement(),
      expect.objectContaining({
        allowEmptyOption: false,
        plugins: ['dropdown_input'],
        maxOptions: 100
      })
    );
  });

  it("does not reinitialize on duplicate connect", () => {
    const controller = getController();
    controller.connect();
    expect(TomSelect).toHaveBeenCalledTimes(1);
  });

  it("destroys TomSelect on disconnect", () => {
    const controller = getController();
    controller.disconnect();
    expect(mockDestroy).toHaveBeenCalledTimes(1);
  });

  it("clears reference on disconnect", () => {
    const controller = getController();
    controller.disconnect();
    expect(controller.select).toBeNull();
  });

  it("handles disconnect when no TomSelect instance exists", () => {
    const controller = getController();
    controller.select = null;
    expect(() => controller.disconnect()).not.toThrow();
    expect(mockDestroy).not.toHaveBeenCalled();
  });

  it("respects custom allowEmpty value", async () => {
    vi.clearAllMocks();
    // Note: This is a static test fixture, not user-controlled input
    document.body.innerHTML = `
      <select data-controller="select" data-select-allow-empty-value="true">
        <option value="">-- Select --</option>
        <option value="0">0 (MD5)</option>
      </select>
    `;

    await Promise.resolve();

    expect(TomSelect).toHaveBeenCalledWith(
      expect.any(HTMLSelectElement),
      expect.objectContaining({ allowEmptyOption: true })
    );
  });

  it("respects custom maxOptions value", async () => {
    vi.clearAllMocks();
    // Note: This is a static test fixture, not user-controlled input
    document.body.innerHTML = `
      <select data-controller="select" data-select-max-options-value="50">
        <option value="0">0 (MD5)</option>
      </select>
    `;

    await Promise.resolve();

    expect(TomSelect).toHaveBeenCalledWith(
      expect.any(HTMLSelectElement),
      expect.objectContaining({ maxOptions: 50 })
    );
  });

  it("handles TomSelect initialization failure gracefully", () => {
    const controller = getController();
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});

    // Simulate failure on next connect attempt
    controller.select = null;
    controller._initFailed = false;
    TomSelect.mockImplementationOnce(() => { throw new Error("init failed"); });

    controller.connect();

    expect(consoleError).toHaveBeenCalledWith(
      expect.stringContaining("[SelectController]"),
      expect.any(Error)
    );
    expect(controller.select).toBeFalsy();
    expect(controller._initFailed).toBe(true);

    consoleError.mockRestore();
  });

  it("does not retry after initialization failure", () => {
    const controller = getController();
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});

    // Simulate a failed init
    controller.select = null;
    controller._initFailed = false;
    TomSelect.mockImplementationOnce(() => { throw new Error("init failed"); });
    controller.connect();

    TomSelect.mockClear();

    // Subsequent connect() should be blocked by _initFailed flag
    controller.connect();
    expect(TomSelect).not.toHaveBeenCalled();

    consoleError.mockRestore();
  });

  it("resets _initFailed on disconnect allowing fresh attempt", () => {
    const controller = getController();

    controller._initFailed = true;
    controller.disconnect();

    expect(controller._initFailed).toBe(false);
  });
});
