'use client';

import { useEffect, useRef } from 'react';

export function Starfield() {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    const ctx = canvas?.getContext('2d');
    if (!canvas || !ctx) return;
    let frame = 0;
    let id = 0;
    const draw = () => {
      frame += 1;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.fillRect((frame * 2) % canvas.width, 40, 2, 2);
      id = requestAnimationFrame(draw);
    };
    id = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(id);
  }, []);
  return <canvas ref={ref} width={640} height={160} className="w-full" aria-hidden="true" />;
}
