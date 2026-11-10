import { SiteHeader } from '@/components/site-header';

export default function Home() {
  return (
    <main className="mx-auto max-w-2xl p-8">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      <SiteHeader />
    </main>
  );
}
