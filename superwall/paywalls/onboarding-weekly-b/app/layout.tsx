import type { PropsWithChildren } from "react";
import { Chrome } from "../../onboarding-flow/components/Chrome";
import { LineupContext } from "../../onboarding-flow/lib/lineup";

/** The control's chrome with the weekly lineup: no savings badge. */
export default function Layout({ children }: PropsWithChildren) {
  return (
    <LineupContext.Provider value="weekly">
      <Chrome>{children}</Chrome>
    </LineupContext.Provider>
  );
}
