import type { PropsWithChildren } from "react";
import { Chrome } from "../../onboarding-flow/components/Chrome";

/** No close button on the plans step. See `onboarding-flow/components/Chrome.tsx`. */
export default function Layout({ children }: PropsWithChildren) {
  return <Chrome dismissible={false}>{children}</Chrome>;
}
