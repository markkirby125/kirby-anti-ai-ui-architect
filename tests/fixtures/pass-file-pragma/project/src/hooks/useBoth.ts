// verify-ui-ignore-file UI001 (only imported by client components)
import { useState, useEffect } from 'react';

export function useBoth() {
  const [a] = useState(0);
  useEffect(() => {}, []);
  return a;
}
