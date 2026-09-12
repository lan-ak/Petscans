import { definePaywall } from "superwall/config";

/**
 * The onboarding paywall — a rebuild of the "Design Your Trial | Custom"
 * dashboard paywall (245894) that campaign 64348 presents on
 * `onboarding_complete` to anyone who scored a food during onboarding
 * (`user.searched_food == true`).
 */
export default definePaywall({
  name: "Onboarding — Design Your Trial",

  /**
   * Two plans only. `primary` carries a paid intro offer — 30 days for $0.99,
   * then $39.99/year — so `offerKind(primary)` is "paid" and the trial layout
   * renders. `secondary` is the full-price monthly the savings maths anchors
   * against: $4.99 x 12 = $59.88, so the annual saves 33%.
   *
   * Slot names match the dashboard paywall's reference names, so audience
   * rules and analytics keyed on primary/secondary keep working.
   */
  products: {
    primary: "annual_39.99",
    secondary: "monthly_499",
  },

  presentation: { style: "fullscreen" },
  featureGating: "nonGated",
  onDeviceCacheEnabled: true,

  /** Painted behind the paywall while it loads, so the open is seamless. */
  background: { light: "#f0f9f4", dark: "#1a1f1c" },

  notifications: {
    trialReminder: {
      enabled: true,
      title: "Your PetScans trial is ending soon",
      body: "Keep every scan, safety score and allergen alert for your pet. Cancel anytime before you're charged.",
      beforeTrialEndDays: 2,
    },
  },
});
