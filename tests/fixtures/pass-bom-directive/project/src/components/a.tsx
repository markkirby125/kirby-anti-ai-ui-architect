"use client";
import { useState } from "react";
export function A() {
  const [x] = useState(0);
  return <p>{x}</p>;
}
