import { Button } from "@/components/ui/button";
import { Counter } from "@/components/counter";

export default function Page() {
  return (
    <main className="mx-auto max-w-3xl p-8">
      <h1 className="text-3xl font-semibold tracking-tight">Quarterly ledger</h1>
      <p className="mt-2 text-muted-foreground">Reconciled 4 hours ago.</p>
      <section className="mt-6 rounded-md bg-muted p-4">
        <Counter />
      </section>
      <Button className="mt-6">Export CSV</Button>
    </main>
  );
}
