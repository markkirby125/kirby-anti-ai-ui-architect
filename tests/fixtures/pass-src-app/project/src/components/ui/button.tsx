import * as React from "react";
import { cn } from "@/lib/utils";

export function Button({ className, ...props }: React.ComponentProps<"button">) {
  return (
    <button
      data-slot="button"
      className={cn(
        "inline-flex items-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:bg-primary/90",
        className,
      )}
      {...props}
    />
  );
}
