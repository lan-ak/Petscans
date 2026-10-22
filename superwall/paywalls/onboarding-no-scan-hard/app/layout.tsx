import type { PropsWithChildren } from "react";
import { Chrome } from "../../onboarding-no-scan/components/Chrome";

/** No close button on the plans step. See `onboarding-no-scan/components/Chrome.tsx`. */
export default function Layout({ children }: PropsWithChildren) {
  return <Chrome dismissible={false}>{children}</Chrome>;
}
