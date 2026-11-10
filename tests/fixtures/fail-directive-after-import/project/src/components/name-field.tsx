import { useState } from 'react';
'use client';

export function NameField() {
  const [name, setName] = useState('');
  return (
    <input
      className="rounded-md border border-input bg-background px-3 py-2"
      value={name}
      onChange={(e) => setName(e.target.value)}
      placeholder="Your name"
    />
  );
}
