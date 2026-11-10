"use client";
import { useEffect } from 'react';

export function Loop() {
  useEffect(() => {
    const dark = window.matchMedia('(prefers-color-scheme: dark)');
    let id = requestAnimationFrame(function t() { id = requestAnimationFrame(t); });
    return () => cancelAnimationFrame(id);
  }, []);
  return <canvas />;
}
