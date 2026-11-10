export const theme = () =>
  typeof localStorage === "undefined" ? "light" : (localStorage.getItem("theme") ?? "light");
