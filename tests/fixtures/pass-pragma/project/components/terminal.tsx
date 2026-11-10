// The terminal mock must stay dark in both themes, so raw palette is intended.
// verify-ui-ignore UI003
const frame = "bg-zinc-900 rounded-md p-4 font-mono text-sm";
const gutter = "bg-slate-800 px-2"; // verify-ui-ignore UI003

export function Terminal({ lines }: { lines: string[] }) {
  return (
    <pre className={frame}>
      {lines.map((l, i) => (
        <code key={i} className="block">
          <span className={gutter}>{i + 1}</span> {l}
        </code>
      ))}
    </pre>
  );
}
