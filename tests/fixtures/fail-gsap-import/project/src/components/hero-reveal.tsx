'use client';

import { useEffect, useRef } from 'react';
import gsap from 'gsap';

export function HeroReveal() {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const ctx = gsap.context(() => {
      gsap.from(ref.current, { opacity: 0, y: 12, duration: 0.4 });
    });
    return () => ctx.revert();
  }, []);
  return (
    <div ref={ref} className="rounded-[var(--radius)] bg-muted p-6">
      Welcome back.
    </div>
  );
}
