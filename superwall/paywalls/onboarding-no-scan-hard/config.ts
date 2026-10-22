import { definePaywall } from "superwall/config";

/**
 * The no-scan onboarding paywall — a rebuild of "Onboarding 1 [Design your
 * trial]" (166440), which campaign 64348 presents on `onboarding_complete` to
 * everyone the "Got Aha Moment" audience doesn't catch: the 272 users who
 * finished onboarding without ever scoring a food.
 *
 * The difference that drives the whole design: there is no result to echo.
 * The aha paywall opens on the user's own scan; this one has to manufacture
 * that moment by showing what a scan returns, with their pet in the frame.
 *
 * Shipped as a replacement rather than a variant. The dashboard paywall's
 * reputation as "the only one that converts" rests on one real Australian
 * purchase and one simulator run, and at 0.35 real opens a day a split test
 * would need ~2.7 years to notice even a tripling.
 */
/*
 * The hard variant of `onboarding-no-scan`: the same pages, copy, products and styles
 * (everything under app/ and messages/ re-exports it), but no close
 * button on the plans step, and gated, so the app's feature block only runs
 * after a purchase or a restore. Change the soft directory and both ship.
 */
export default definePaywall({
  name: "Onboarding — First Scan (Hard)",

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

  presentation: { style: "fullscreen" },

  /**
   * The paywall does not scroll — both pages are sized to fit the screen.
   *
   * This is the config flag, not `overflow: hidden` on html/body: the platform
   * stylesheet applies it, and faking it locally fights the framework's own
   * scroll container. The trade-off is that anything which overflows is simply
   * unreachable, so the short-phone media query in `theme.css` is load-bearing
   * rather than cosmetic, and the no-trial panel carries one review, not two.
   */
  scrollEnabled: false,
  featureGating: "gated",
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
