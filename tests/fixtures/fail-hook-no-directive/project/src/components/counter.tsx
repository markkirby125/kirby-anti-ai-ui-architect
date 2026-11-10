import { useState } from 'react';

export function Counter() {
  const [count, setCount] = useState(0);
  return (
    <button
      type="button"
      className="rounded-md bg-primary px-3 py-1 text-primary-foreground"
      onClick={() => setCount(count + 1)}
    >
      Count: {count}
    </button>
  );
}
