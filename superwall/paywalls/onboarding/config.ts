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
   * Slot names match the dashboard paywall's reference names, so audience
   * rules and analytics keyed on primary/secondary/tertiary keep working.
   */
  products: {
    primary: "yearly_5999_trial",
    secondary: "monthly_899_intro",
    tertiary: "annual_39.99",
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
