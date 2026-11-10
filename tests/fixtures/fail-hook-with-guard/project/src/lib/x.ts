import { useState } from 'react';

export const ok = typeof window !== 'undefined';
export function useX() {
  return useState(0);
}
