/*
 * Copyright (c) 2026 Ledgerline Ltd.
 * Licensed under the MIT License.
 */

'use client';

import { MotionConfig } from "motion/react";
import type { ReactNode } from "react";

export function Providers({ children }: { children: ReactNode }) {
  return <MotionConfig reducedMotion="user">{children}</MotionConfig>;
}
