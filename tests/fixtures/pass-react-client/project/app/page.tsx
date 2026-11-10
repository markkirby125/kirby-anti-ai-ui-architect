import * as motion from "motion/react-client";

// Server component: motion/react-client ships its own client boundary.
export default function Page() {
  return (
    <main className="p-8">
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="rounded-md bg-muted p-6"
      >
        Shipment 4471 cleared customs.
      </motion.div>
    </main>
  );
}
