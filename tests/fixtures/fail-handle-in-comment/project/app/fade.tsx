"use client";

import { motion } from "motion/react";

export function Fade() {
  return <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>Hello</motion.div>;
}
