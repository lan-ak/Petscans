/**
 * Every user-facing string on the hard in-app paywall.
 *
 * No prices: they arrive from the store already localised and are
 * interpolated at the call site, guarded on the value existing.
 */
export default {
  chrome: {
    close: "Close",
  },

  /*
   * The user has already scanned twice, so this says "Keep using", not "Try".
   * It is the same in both eligibility states.
   */
  headlineOffer: "Keep using PetScans your way",
  headlineNoOffer: "Keep using PetScans your way",

  timelineTodayTitle: "Today",
  timelineTodayDetail: "Unlock every scan, safety score and allergen alert for your pet.",
  timelineReminderTitle: "In {days} Days - Reminder",
  timelineReminderFree: "We'll send you a reminder that your trial is ending soon.",
  timelineReminderPaid: "We'll send you a reminder before your intro price ends.",
  timelineChargeTitleFree: "In {days} Days - Billing Starts",
  timelineChargeTitlePaid: "In {days} Days - Full Price Starts",
  timelineChargeTitleBare: "Billing Starts",
  timelineChargeDated: "You'll be charged {price} on {date} unless you cancel anytime before.",
  timelineChargeDatedBare: "You'll be charged on {date} unless you cancel anytime before.",
  timelineChargeBare: "You'll be charged unless you cancel anytime before.",

  accoladeSources: "5\nverified\nsources",
  accoladeIngredients: "3,000\nIngredients",
  reviewTitle: "Lifesaver for my pet",
  reviewDate: "Mar 15",
  reviewAuthor: "Sarah Hayes",
  reviewBody: "Knowing what is in my pet's food helps me keep my fur baby safe and allergy free.",

  planTrialPaid: "{days}-Day Trial For {trialPrice}",
  planTrialFree: "{days}-Day Free Trial",
  planThen: "then {price} per {period}",
  planPrice: "{price} Per {period}",
  planBilled: "Billed {price} / {period}",
  planWeekly: "{price}/week",
  planPopular: "Most popular",

  magicNone: "No commitment, cancel anytime",
  magicPaid: "Just {price} due today, cancel anytime",
  magicFree: "No payment due now, cancel anytime",

  ctaPaid: "Redeem {days} days for {price}",
  ctaFree: "Start my {days}-day free trial",
  ctaNone: "Continue",

  pricingPaid: "{days} days for {trialPrice}, then {price} per {period}. Renews automatically. Cancel anytime.",
  pricingFree: "{days} days free, then {price} per {period}. Renews automatically. Cancel anytime.",
  pricingNone: "{price} per {period}. Renews automatically. Cancel anytime.",

  privacy: "Privacy",
  restore: "Restore",
  terms: "Terms",
  restoreFailed: "Nothing to restore, or the App Store couldn't be reached. Try again later.",

  notifications: {
    reminderTitle: "Your PetScans trial ends soon",
    reminderBody: "Keep every scan, safety score and allergen alert for your pet. Cancel anytime before you're charged.",
  },
} as const;
