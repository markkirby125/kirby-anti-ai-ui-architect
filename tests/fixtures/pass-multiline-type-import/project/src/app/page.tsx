import type {
  ThemeProviderProps,
} from "next-themes";

export default function Home(props: { theme?: ThemeProviderProps["theme"] }) {
  return <main className="p-8">{props.theme}</main>;
}
