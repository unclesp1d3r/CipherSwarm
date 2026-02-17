import {describe, it, expect, beforeEach, afterEach, vi} from "vitest";
import {application, registerController} from "../setup";
import HealthRefreshController from "../../../app/javascript/controllers/health_refresh_controller";

// Mock @hotwired/turbo - use vi.hoisted to handle Vitest's mock hoisting
const { mockVisit } = vi.hoisted(() => ({
  mockVisit: vi.fn()
}));

vi.mock("@hotwired/turbo", () => ({
  visit: mockVisit
}));

describe("HealthRefreshController", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();

    // Static test fixture
    document.body.textContent = "";
    const container = document.createElement("div");
    container.id = "health-dashboard";
    container.setAttribute("data-controller", "health-refresh");
    container.setAttribute("data-health-refresh-url-value", "/system_health");
    container.setAttribute("data-health-refresh-interval-value", "30");
    container.textContent = "Health Dashboard Content";
    document.body.appendChild(container);

    registerController("health-refresh", HealthRefreshController);
  });

  afterEach(() => {
    vi.useRealTimers();
    document.body.textContent = "";
  });

  function getElement() {
    return document.querySelector('[data-controller="health-refresh"]');
  }

  function getController() {
    const element = getElement();
    return application.getControllerForElementAndIdentifier(element, "health-refresh");
  }

  it("connects successfully", () => {
    const controller = getController();
    expect(controller).toBeTruthy();
  });

  it("has correct URL value", () => {
    const controller = getController();
    expect(controller.urlValue).toBe("/system_health");
  });

  it("has correct interval value", () => {
    const controller = getController();
    expect(controller.intervalValue).toBe(30);
  });

  it("triggers Turbo visit after interval elapses", () => {
    vi.advanceTimersByTime(30000);
    expect(mockVisit).toHaveBeenCalledTimes(1);
  });

  it("passes replace action to Turbo visit using configured URL", () => {
    vi.advanceTimersByTime(30000);
    expect(mockVisit).toHaveBeenCalledWith(
      expect.stringMatching(/^\/system_health\?_cb=\d+$/),
      {action: "replace"}
    );
  });

  it("does not trigger before interval elapses", () => {
    vi.advanceTimersByTime(29000);
    expect(mockVisit).not.toHaveBeenCalled();
  });

  it("triggers multiple refreshes over time", () => {
    vi.advanceTimersByTime(90000);
    expect(mockVisit).toHaveBeenCalledTimes(3);
  });

  it("stops polling on disconnect", () => {
    const controller = getController();
    controller.disconnect();
    vi.advanceTimersByTime(60000);
    expect(mockVisit).not.toHaveBeenCalled();
  });

  it("includes cache-buster parameter in URL", () => {
    vi.advanceTimersByTime(30000);
    const calledUrl = mockVisit.mock.calls[0][0];
    expect(calledUrl).toMatch(/\?_cb=\d+/);
  });

  it("uses configured URL value, not window.location.pathname", () => {
    // In jsdom, window.location.pathname defaults to "/"
    // The controller should use the configured data-health-refresh-url-value ("/system_health"),
    // not fall back to window.location.pathname ("/")
    vi.advanceTimersByTime(30000);
    const calledUrl = mockVisit.mock.calls[0][0];
    expect(calledUrl).toMatch(/^\/system_health/);
    expect(calledUrl).not.toEqual(expect.stringMatching(/^\/$|^\/\?/));
  });
});
