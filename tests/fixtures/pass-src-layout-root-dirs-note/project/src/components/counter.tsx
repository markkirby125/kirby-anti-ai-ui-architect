// Small interactive island.
"use client";

import { useState } from "react";
import { motion } from "motion/react";

export function Counter() {
  const [n, setN] = useState(0);
  return (
    <motion.button
      layout
      className="rounded-md bg-primary px-3 py-1.5 text-primary-foreground"
      onClick={() => setN((v) => v + 1)}
    >
      Reviewed {n}
    </motion.button>
  );
}
