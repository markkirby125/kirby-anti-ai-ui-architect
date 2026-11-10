import { motion } from "framer-motion";
import { useState } from "react";
export default function P() {
  const [a, b] = useState(0);
  return <motion.div className="bg-zinc-900" onClick={() => b(a + 1)} />;
}
