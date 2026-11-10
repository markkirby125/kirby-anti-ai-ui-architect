"use client";
import { useEffect } from 'react';

export function Loop() {
  useEffect(() => {
    const calm = window.matchMedia('(prefers-reduced-motion: reduce)');
    if (calm.matches) return;
    let id = requestAnimationFrame(function t() { id = requestAnimationFrame(t); });
    return () => cancelAnimationFrame(id);
  }, []);
  return <canvas />;
}
