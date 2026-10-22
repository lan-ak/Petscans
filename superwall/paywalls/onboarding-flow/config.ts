import { definePaywall } from "superwall/config";

/**
 * The whole of onboarding, steps 0 through 5 — promise, food check, demo
 * result, pet profile, watch list, personalised verdict.
 *
 * The 1.4.8 native flow rebuilt as a surface, so step 1 and everything after
 * it can change without a submission. 1.4.6 made that step a mandatory
 * search and completion fell from 71% to 35%; 1.4.7 offered scan, search or
 * an example and lost installs on non-US barcodes and half-typed queries;
 * 1.4.8 is a one-tap pick from `DemoFoods`. Each of those took a release.
 *
 * The native flow stays in the binary as the fallback. `OnboardingView`
 * registers `onboarding_flow` and drops to SwiftUI on skip or error — no
 * campaign, no audience match, no config, or a webview that fails to load.
 *
 * Ends on the paywall. The plans step is `onboarding-scan`'s (276012) plans
 * page and exit offer, so onboarding and the offer are one presentation
 * rather than a surface that closes and a paywall that opens behind it.
 *
 * Served by campaign "Onboarding V2" (111017) to app version 1.4.8 and
 * later. The app still registers `onboarding_complete` when this closes, but
 * campaign "Onboarding" (64348) only answers versions below 1.4.8, so nobody
 * gets a second paywall; 1.4.7 and earlier keep the native flow and the
 * 276019 / 276012 paywalls.
 *
 * Having products also means this surface's `paywallOpen` now counts as
 * "seen" for `PaywallGate`, which is correct: the paywall is in the flow.
 */
export default definePaywall({
  name: "Onboarding — Full Flow",

  /**
   * The app-wide offer, identical on every PetScans paywall (2026-10-17):
   *
   *   primary    annual_39.99   $39.99/yr after a 30-day $0.99 intro
   *   secondary  monthly_499    $4.99/mo, no intro
   *
   * The monthly has no intro offer, so tapping it is the no-offer branch:
   * the header changes, the timeline goes and the reviews show instead.
   * There is no exit offer any more. The only cheaper thing to offer
   * was this same annual.
   */
  products: {
    primary: "annual_39.99",
    secondary: "monthly_499",
  },

  notifications: {
    trialReminder: {
      enabled: true,
      title: "Your PetScans trial is ending soon",
      body: "Keep every scan, safety score and allergen alert for your pet. Cancel anytime before you're charged.",
      beforeTrialEndDays: 2,
    },
  },

  /** Matches the native onboarding chrome it replaces: full screen, no dimming. */
  presentation: { style: "fullscreen" },

  /**
   * `shift` is the funnel transition: the new page fades in as it drifts the
   * last 44px into place and the page it replaces is simply gone. One layer
   * moves at a time, so six steps never read as a stack of cards the user is
   * burrowing into — which is exactly what `push` would make this feel like.
   */
  transition: "shift",

  /**
   * Non-gated, and it matters here more than on a paywall. The native
   * `register` runs its feature block even when the SDK is unavailable (see
   * `SuperwallSafe.register`), so a surface that fails to load advances
   * onboarding instead of stranding a brand new user on a blank step.
   */
  featureGating: "nonGated",
  onDeviceCacheEnabled: true,

  /**
   * The webview itself never scrolls or bounces: each page is a fixed frame
   * and its content scrolls inside `.scroller` (see `.page` in theme.css).
   */
  scrollEnabled: false,

  /** `ColorTokens.backgroundPrimary`, so the hand-off from native doesn't flash. */
  background: { light: "#f0f9f4", dark: "#1a1f1c" },
});
