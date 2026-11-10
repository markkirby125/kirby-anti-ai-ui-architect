import * as React from "react";
import { cn } from "@/lib/utils";

export function Card({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("rounded-lg border bg-card text-card-foreground", className)} {...props} />;
}

export function CardMuted({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("rounded-lg bg-muted p-4", className)} {...props} />;
}
