import type { PropsWithChildren } from "react";
import { Chrome } from "../components/Chrome";

/** The soft variant: the plans step has a close button. See `Chrome`. */
export default function Layout({ children }: PropsWithChildren) {
  return <Chrome>{children}</Chrome>;
}
