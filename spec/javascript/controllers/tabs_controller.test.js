import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { application, registerController } from "../setup";
import TabsController from "../../../app/javascript/controllers/tabs_controller";

describe("TabsController", () => {
  beforeEach(() => {
    // Note: This is a static test fixture, not user-controlled input
    document.body.innerHTML = `
      <div data-controller="tabs" data-tabs-active-value="0">
        <button data-tabs-target="tab" data-action="click->tabs#switch" aria-selected="false">Tab 1</button>
        <button data-tabs-target="tab" data-action="click->tabs#switch" aria-selected="false">Tab 2</button>
        <button data-tabs-target="tab" data-action="click->tabs#switch" aria-selected="false">Tab 3</button>
        <div data-tabs-target="panel" class="tab-pane active" aria-hidden="false">Content 1</div>
        <div data-tabs-target="panel" class="tab-pane d-none" aria-hidden="true">Content 2</div>
        <div data-tabs-target="panel" class="tab-pane d-none" aria-hidden="true">Content 3</div>
      </div>
    `;

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

  it("shows first panel on connect with active class", () => {
    const panels = getPanels();
    expect(panels[0].classList.contains("d-none")).toBe(false);
    expect(panels[0].classList.contains("active")).toBe(true);
    expect(panels[0].getAttribute("aria-hidden")).toBe("false");
    expect(panels[1].classList.contains("d-none")).toBe(true);
    expect(panels[1].classList.contains("active")).toBe(false);
    expect(panels[1].getAttribute("aria-hidden")).toBe("true");
  });

  it("switches to clicked tab via switch action", () => {
    const tabs = getTabs();
    const panels = getPanels();

    // Click second tab
    tabs[1].click();

    // Second tab should now be active
    expect(tabs[0].classList.contains("active")).toBe(false);
    expect(tabs[0].getAttribute("aria-selected")).toBe("false");
    expect(tabs[1].classList.contains("active")).toBe(true);
    expect(tabs[1].getAttribute("aria-selected")).toBe("true");

    // Second panel should be visible and active
    expect(panels[0].classList.contains("d-none")).toBe(true);
    expect(panels[0].classList.contains("active")).toBe(false);
    expect(panels[0].getAttribute("aria-hidden")).toBe("true");
    expect(panels[1].classList.contains("d-none")).toBe(false);
    expect(panels[1].classList.contains("active")).toBe(true);
    expect(panels[1].getAttribute("aria-hidden")).toBe("false");
  });

  it("adds active class to active panel and removes from inactive panels", () => {
    const panels = getPanels();

    // First panel starts active
    expect(panels[0].classList.contains("active")).toBe(true);
    expect(panels[1].classList.contains("active")).toBe(false);
    expect(panels[2].classList.contains("active")).toBe(false);

    // Switch to third tab
    const tabs = getTabs();
    tabs[2].click();

    // Third panel should have active, others should not
    expect(panels[0].classList.contains("active")).toBe(false);
    expect(panels[1].classList.contains("active")).toBe(false);
    expect(panels[2].classList.contains("active")).toBe(true);
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

  it("showTab alias delegates to switch", () => {
    const controller = getController();
    const tabs = getTabs();
    const panels = getPanels();

    // Call showTab directly as an alias test
    const event = { preventDefault: () => {}, currentTarget: tabs[2] };
    controller.showTab(event);

    expect(controller.activeValue).toBe(2);
    expect(panels[2].classList.contains("active")).toBe(true);
    expect(panels[2].classList.contains("d-none")).toBe(false);
  });
});
