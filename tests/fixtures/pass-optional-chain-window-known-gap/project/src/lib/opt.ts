// Pins a documented limit (04_verify.md, Accepted limits), not intended behaviour:
// UI001 does not see optional chaining or bracket access on a browser global.
export const width = () => window?.innerWidth ?? 0;
export const height = () => window["innerHeight"];
