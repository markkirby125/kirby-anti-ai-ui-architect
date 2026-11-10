import type { ReactNode } from 'react';
import type { ThemeProviderProps } from "next-themes";
import type { Variants } from "motion/react";
export type { DialogProps } from 'vaul';
import './globals.css';

export const themeDefaults: Partial<ThemeProviderProps> = { attribute: 'class' };
export const fade: Variants = { hidden: { opacity: 0 } };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-background text-foreground">{children}</body>
    </html>
  );
}
