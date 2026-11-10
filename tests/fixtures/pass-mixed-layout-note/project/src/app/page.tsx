import { useState } from 'react';

export default function Ignored() {
  const [n] = useState(0);
  return <i>{n}</i>;
}
