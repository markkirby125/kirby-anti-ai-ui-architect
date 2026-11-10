import { useEffect, useState } from "react";

export default function Home() {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    document.title = open ? "Filters open" : "Inventory";
  }, [open]);
  return (
    <main className="p-8">
      <button className="rounded-md bg-primary px-3 py-1.5" onClick={() => setOpen(!open)}>
        {open ? "Hide" : "Show"} filters
      </button>
    </main>
  );
}
