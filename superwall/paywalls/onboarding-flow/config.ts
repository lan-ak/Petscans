import { definePaywall } from "superwall/config";

/**
 * The whole of onboarding, steps 0 through 5 — promise, food check, demo
 * result, pet profile, watch list, personalised verdict.
 *
 * Why this is a surface and not a SwiftUI page: 1.4.6 turned that step into a
 * mandatory search gate, and the measured cost was onboarding completion
 * falling from 71% to 35% with no way to revert short of another release. Of
 * the 15 users who quit at the step in the 30 days to 2026-10-04, *zero* had
 * ever completed a search — they were leaving before any result existed. The
 * fix is a branch (scan / search / example) plus a way out, and all three need
 * to be tunable without a submission.
 *
 * Sells nothing. The paywall still happens where it always did, at
 * `onboarding_complete`, off campaign 64348.
 */
export default definePaywall({
  name: "Onboarding — Full Flow",

  /**
   * No product slots. This surface never calls `purchase()`; it hands the
   * finished profile back to the app, which persists the pet and fires
   * `onboarding_complete`.
   */
  products: {},

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

  /** `ColorTokens.backgroundPrimary`, so the hand-off from native doesn't flash. */
  background: { light: "#f0f9f4", dark: "#1a1f1c" },
});
