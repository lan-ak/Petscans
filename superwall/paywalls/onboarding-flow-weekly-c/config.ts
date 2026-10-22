import { definePaywall } from "superwall/config";

/**
 * Weekly price test, arm C. Same pages as `onboarding-flow` (275901), the
 * control, which this directory re-exports route for route; only the
 * products and the lineup differ. The test design, the split and how to read
 * it are in `docs/weekly-price-test.md`.
 *
 * Kept self-contained rather than importing the control's config: the CLI
 * loads `config.ts` with Node, outside the bundler, so a shared base file
 * would be one more thing that has to resolve on every machine that pushes.
 */
export default definePaywall({
  name: "Onboarding — Full Flow · Weekly C",

  /**
   *   primary    weekly_599         $5.99/wk, no trial, no intro offer
   *   secondary  monthly_899        $8.99/mo, no trial, as on the control
   *
   * No `tertiary`: the weekly arms have no exit offer.
   */
  products: {
    primary: "weekly_599",
    secondary: "monthly_899",
  },

  // As the control, less the trial reminder: nothing here has a trial.
  presentation: { style: "fullscreen" },
  transition: "shift",
  featureGating: "nonGated",
  onDeviceCacheEnabled: true,
  scrollEnabled: false,
  background: { light: "#f0f9f4", dark: "#1a1f1c" },
});
