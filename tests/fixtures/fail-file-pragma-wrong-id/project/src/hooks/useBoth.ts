// verify-ui-ignore-file UI002
import { useState } from 'react';

export function useBoth() {
  const [a] = useState(0);
  return a;
}
