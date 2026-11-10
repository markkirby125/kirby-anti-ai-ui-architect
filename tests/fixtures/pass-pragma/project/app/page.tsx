import { Terminal } from "@/components/terminal";

export default function Page() {
  return (
    <main className="p-8">
      <Terminal lines={["$ make deploy", "ok"]} />
    </main>
  );
}
