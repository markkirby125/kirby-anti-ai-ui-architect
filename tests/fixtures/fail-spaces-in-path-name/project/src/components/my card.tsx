import { useState } from 'react';

export function MyCard() {
  const [open, setOpen] = useState(false);
  return (
    <div className="rounded-[var(--radius)] bg-card p-4">
      <button type="button" onClick={() => setOpen(!open)}>
        {open ? 'Hide' : 'Show'} details
      </button>
    </div>
  );
}
