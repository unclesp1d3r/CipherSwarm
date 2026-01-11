import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { application, registerController } from "../setup";
import TabsController from "../../../app/javascript/controllers/tabs_controller";

describe("TabsController", () => {
  beforeEach(() => {
    // Set up DOM fixture before registering/connecting the controller
    // Note: This is a static test fixture, not user-controlled input
    document.body.innerHTML = `
      <div data-controller="tabs" data-tabs-active-value="0">
        <button data-tabs-target="tab" data-action="click->tabs#showTab" aria-selected="false">Tab 1</button>
        <button data-tabs-target="tab" data-action="click->tabs#showTab" aria-selected="false">Tab 2</button>
        <button data-tabs-target="tab" data-action="click->tabs#showTab" aria-selected="false">Tab 3</button>
        <div data-tabs-target="panel" class="active" aria-hidden="false">Content 1</div>
        <div data-tabs-target="panel" class="d-none" aria-hidden="true">Content 2</div>
        <div data-tabs-target="panel" class="d-none" aria-hidden="true">Content 3</div>
      </div>
    `;

    // Register the controller
    registerController("tabs", TabsController);
  });

  afterEach(() => {
    document.body.innerHTML = "";
  });

  function getController() {
    const element = document.querySelector('[data-controller="tabs"]');
    return application.getControllerForElementAndIdentifier(element, "tabs");
  }

  function getTabs() {
    return document.querySelectorAll('[data-tabs-target="tab"]');
  }

  function getPanels() {
    return document.querySelectorAll('[data-tabs-target="panel"]');
  }

  it("connects successfully", () => {
    const controller = getController();
    expect(controller).toBeTruthy();
  });

  it("has default active value of 0", () => {
    const controller = getController();
    expect(controller.activeValue).toBe(0);
  });

  it("sets first tab as active on connect", () => {
    const tabs = getTabs();
    expect(tabs[0].classList.contains("active")).toBe(true);
    expect(tabs[0].getAttribute("aria-selected")).toBe("true");
    expect(tabs[1].classList.contains("active")).toBe(false);
    expect(tabs[1].getAttribute("aria-selected")).toBe("false");
  });

  it("shows first panel on connect", () => {
    const panels = getPanels();
    expect(panels[0].classList.contains("d-none")).toBe(false);
    expect(panels[0].getAttribute("aria-hidden")).toBe("false");
    expect(panels[1].classList.contains("d-none")).toBe(true);
    expect(panels[1].getAttribute("aria-hidden")).toBe("true");
  });

  it("switches to clicked tab", () => {
    const tabs = getTabs();
    const panels = getPanels();

    // Click second tab
    tabs[1].click();

    // Second tab should now be active
    expect(tabs[0].classList.contains("active")).toBe(false);
    expect(tabs[0].getAttribute("aria-selected")).toBe("false");
    expect(tabs[1].classList.contains("active")).toBe(true);
    expect(tabs[1].getAttribute("aria-selected")).toBe("true");

    // Second panel should be visible
    expect(panels[0].classList.contains("d-none")).toBe(true);
    expect(panels[0].getAttribute("aria-hidden")).toBe("true");
    expect(panels[1].classList.contains("d-none")).toBe(false);
    expect(panels[1].getAttribute("aria-hidden")).toBe("false");
  });

  it("updates aria attributes when switching tabs", () => {
    const tabs = getTabs();
    const panels = getPanels();

    // Click third tab
    tabs[2].click();

    // Check aria-selected on tabs
    expect(tabs[0].getAttribute("aria-selected")).toBe("false");
    expect(tabs[1].getAttribute("aria-selected")).toBe("false");
    expect(tabs[2].getAttribute("aria-selected")).toBe("true");

    // Check aria-hidden on panels
    expect(panels[0].getAttribute("aria-hidden")).toBe("true");
    expect(panels[1].getAttribute("aria-hidden")).toBe("true");
    expect(panels[2].getAttribute("aria-hidden")).toBe("false");
  });

  it("updates activeValue when switching tabs", () => {
    const controller = getController();
    const tabs = getTabs();

    expect(controller.activeValue).toBe(0);

    tabs[1].click();
    expect(controller.activeValue).toBe(1);

    tabs[2].click();
    expect(controller.activeValue).toBe(2);
  });
});
