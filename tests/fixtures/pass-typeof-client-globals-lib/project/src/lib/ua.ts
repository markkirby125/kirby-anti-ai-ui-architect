export const ua = () =>
  typeof navigator === "undefined" ? "" : navigator.userAgent;
