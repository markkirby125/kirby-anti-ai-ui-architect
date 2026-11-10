import { useRouter } from "next/navigation";

export default function Page() {
  const router = useRouter();
  return <main className="p-8">{typeof router}</main>;
}
