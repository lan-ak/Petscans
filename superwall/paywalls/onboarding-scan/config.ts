import { definePaywall } from "superwall/config";

/**
 * The post-scan onboarding paywall — a rebuild of the "Design Your Trial |
 * Custom" dashboard paywall (245894) that campaign 64348 presents on
 * `onboarding_complete` to anyone who scored a food during onboarding.
 *
 * Paired with `onboarding-no-scan`, which takes the other half of that
 * campaign. The directory name is the paywall identifier, so this one is
 * `onboarding-scan` rather than plain `onboarding`: the original identifier
 * belongs to an archived record (263121) that the API cannot restore, and the
 * CLI refuses to push into it.
 */
export default definePaywall({
  name: "Onboarding — After a Scan",

  /**
   * Three slots, matching 245894's reference names exactly so audience rules
   * and analytics keyed on primary/secondary/tertiary keep working.
   *
   * The two plans the user chooses between:
   *
   *   primary    yearly_5999_trial   $59.99/yr, 3-day free trial
   *   secondary  monthly_899         $8.99/mo,  no trial
   *
   * The monthly deliberately carries no introductory offer — `monthly_899`,
   * not `monthly_899_intro`. That is what makes the no-trial branch a real
   * path rather than dead code: tapping monthly swaps the header, drops the
   * timeline (there is nothing to count down) and shows the reviews instead.
   *
   * `tertiary` is the **intro offer, and it is only ever the exit offer** —
   * annual_39.99 is $39.99/yr behind a 30-day $0.99 intro. It is never one of
   * the two rows on the page; it exists so the drawer has something genuinely
   * better to put in front of someone on their way out. Selling it as a plan
   * would undercut the primary row it is supposed to rescue.
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
