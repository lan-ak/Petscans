import type { PropsWithChildren } from "react";
import { FlowLayout } from "../../onboarding-flow/app/layout";

/** The control's layout with the weekly lineup: no exit offer, no savings badge. */
export default function Layout({ children }: PropsWithChildren) {
  return <FlowLayout lineup="weekly">{children}</FlowLayout>;
}
