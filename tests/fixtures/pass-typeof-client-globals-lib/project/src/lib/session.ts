export const draft = () =>
  typeof sessionStorage === "undefined" ? "" : (sessionStorage.getItem("draft") ?? "");
