export const isBrowser = typeof window !== 'undefined' && window.innerWidth > 0;

export function width() {
  if (typeof window !== 'undefined') {
    return window.innerWidth;
  }
  return 0;
}
