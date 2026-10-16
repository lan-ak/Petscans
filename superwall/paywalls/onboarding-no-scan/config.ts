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
export default definePaywall({
  name: "Onboarding — First Scan",

  /**
   * The same three slots as `onboarding-scan`, under the same reference names.
   * Both halves of the campaign now sell one offer, so a user who scans later
   * never meets a different price than the one they were just quoted.
   *
   *   primary    yearly_5999_trial   $59.99/yr, 3-day free trial
   *   secondary  monthly_899         $8.99/mo,  no trial
   *
   * The monthly deliberately carries no introductory offer — `monthly_899`,
   * not `monthly_899_intro`. That is what makes the no-trial branch a real
   * path: tapping monthly swaps the header, drops the timeline (there is
   * nothing to count down) and shows the reviews instead.
   *
   * `tertiary` is the **intro offer, and it is only ever the exit offer** —
   * annual_39.99 is $39.99/yr behind a 30-day $0.99 intro. It is never one of
   * the two rows; it exists so the drawer has something genuinely better to
   * put in front of someone on their way out.
   */
  products: {
    primary: "yearly_5999_trial",
    secondary: "monthly_899",
    tertiary: "annual_39.99",
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
