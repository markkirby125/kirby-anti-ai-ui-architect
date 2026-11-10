// shadcn-owned primitive: raw palette is allowed under components/ui/
export function Card({ children }: { children: React.ReactNode }) {
  return <div className="bg-zinc-900 text-zinc-50 rounded-md">{children}</div>;
}
