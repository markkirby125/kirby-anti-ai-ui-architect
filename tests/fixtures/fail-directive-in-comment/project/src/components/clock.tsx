// TODO: add 'use client' here before shipping
/* "use client" */
import { useEffect, useState } from 'react';

export function Clock() {
  const [now, setNow] = useState('');
  useEffect(() => {
    const id = setInterval(() => setNow(new Date().toLocaleTimeString()), 1000);
    return () => clearInterval(id);
  }, []);
  return <p className="text-sm text-muted-foreground">{now}</p>;
}
