// Member access on a local object is not a browser global, even when the property shares the name.
type Bag = Record<string, any>;
export function read(obj: Bag, a?: Bag) {
  const m = obj.matchMedia("(min-width: 40rem)");
  const t = obj.document.title;
  const n = obj.navigator.ready;
  const s = obj.sessionStorage;
  const l = obj.localStorage.length;
  const z = a?.window.innerWidth;
  return { m, t, n, s, l, z };
}
