import { createContext, useContext } from "react";

/**
 * Which plans the flow's last step sells. Every page and component is shared
 * between this paywall and the weekly price-test arms
 * (`onboarding-flow-weekly-a` … `-d`); the lineup is the only thing that
 * differs besides the products themselves.
 *
 * - `yearly` — this paywall, the control: `yearly_5999_trial` against
 *   `monthly_899`, a "Save X%" badge on the annual row, and the `annual_39.99`
 *   exit offer on the first close.
 * - `weekly` — a test arm: a weekly plan against `monthly_899`, no badge and
 *   no exit offer. The first close closes.
 *
 * Declared by each paywall's `app/layout.tsx` rather than read off the
 * products, because product data is absent until the store answers (and for
 * good in the studio). Inferring the lineup from it would let a slow store
 * response briefly change what the control shows.
 */
export type Lineup = "yearly" | "weekly";

export const LineupContext = createContext<Lineup>("yearly");

export const useLineup = (): Lineup => useContext(LineupContext);
