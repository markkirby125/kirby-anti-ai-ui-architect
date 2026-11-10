export function MyCard({ title }: { title: string }) {
  return <article className="rounded-md border bg-card p-4 text-card-foreground">{title}</article>;
}
