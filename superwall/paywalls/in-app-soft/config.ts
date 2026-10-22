import { definePaywall } from "superwall/config";

/**
 * The soft in-app paywall: a rebuild of "Onboarding 1 [Design your trial]"
 * (166440), which campaign 65702 presents on `analysis_complete` for scans 1
 * and 2. The dashboard name is left over from its onboarding days; the
 * onboarding role now belongs to 276012.
 *
 * It has the same fixes as `in-app-hard` (see its config): the trial price
 * now agrees with the CTA, the no-intro rows no longer sell `monthly_3.99`, the
 * "due today" line is correct, and the promised reminder is scheduled. The
 * monthly row's redundant "then $8.99 per month" caption is gone.
 */
export default definePaywall({
  name: "In-App — Soft (code)",
  platforms: ["ios"],

  /*
   * The app-wide offer, identical on every PetScans paywall (2026-10-17):
   *
   *   primary    annual_39.99   $39.99/yr after a 30-day $0.99 intro
   *   secondary  monthly_499    $4.99/mo, no intro
   */
  products: {
    primary: "annual_39.99",
    secondary: "monthly_499",
  },

  presentation: { style: "fullscreen" },

  featureGating: "nonGated",
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
