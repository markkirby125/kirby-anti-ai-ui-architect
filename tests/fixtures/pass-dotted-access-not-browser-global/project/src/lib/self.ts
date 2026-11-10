export class Shell {
  window = { scrollY: 0 };
  navigator = { userAgent: "" };
  y() { return this.window.scrollY + this.navigator.userAgent.length; }
}
