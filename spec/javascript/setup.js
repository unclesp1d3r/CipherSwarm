import { Application } from "@hotwired/stimulus";

const application = Application.start();

export { application };

export function registerController(name, controller) {
  application.register(name, controller);
  return application;
}
