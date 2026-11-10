export function SiteHeader() {
  return (
    <header className="sticky top-0 bg-zinc-900 px-4 py-3 text-white">
      <nav className="flex gap-2">
        <a href="/docs" className="rounded px-2 py-1 dark:hover:bg-slate-800/50">
          Docs
        </a>
      </nav>
    </header>
  );
}
