import { definePaywall } from "superwall/config";

/**
 * The hard in-app paywall: a rebuild of "In-App 1 [Design your trial] [Hard]"
 * (174002), which campaign 65702 presents on `analysis_complete` from the
 * third scan on.
 *
 * It has no close button, the same as the dashboard original. The user has
 * already scanned twice, so the headline says "Keep using", not "Try".
 *
 * Changes from the original, each one a bug in the dashboard version:
 *
 * - The trial row read `trialPeriodMonthlyPrice` ($1.00) while the CTA read
 *   `trialPeriodPrice` ($0.99). Both now read the price that is charged.
 * - When the user wasn't eligible for the intro, the second row sold the tertiary
 *   `monthly_3.99` labelled "/year". It sold a $3.99 monthly next to the
 *   $8.99 one. That row is now the same monthly as the eligible state's, so
 *   `tertiary` is gone.
 * - "No payment due today" showed when the user was *not* eligible for the intro,
 *   that is, when the full price is due today.
 * - The timeline promised a reminder that nothing scheduled. It is scheduled below.
 */
export default definePaywall({
  name: "In-App — Hard (code)",
  platforms: ["ios"],

  /*
   * The in-app offer (2026-10-26): the app-wide annual, with a weekly in
   * place of the monthly. The onboarding paywalls still sell monthly_499.
   *
   *   primary    annual_39.99   $39.99/yr after a 30-day $0.99 intro
   *   secondary  weekly_499     $4.99/wk, no intro
   */
  products: {
    primary: "annual_39.99",
    secondary: "weekly_499",
  },

  presentation: { style: "fullscreen" },

  /*
   * The original was `gated` and didn't scroll. Gating stays as it was.
   * Scrolling is on: with no close button, a CTA pushed below the fold on a
   * short phone, or at a large text size, would leave the user with no way out.
   */
  featureGating: "gated",
  scrollEnabled: true,
  onDeviceCacheEnabled: true,

  background: { light: "#ffffff", dark: "#141414" },

  notifications: {
    trialReminder: {
      enabled: true,
      title: "notifications.reminderTitle",
      body: "notifications.reminderBody",
      beforeTrialEndDays: 2,
    },
  },
});
